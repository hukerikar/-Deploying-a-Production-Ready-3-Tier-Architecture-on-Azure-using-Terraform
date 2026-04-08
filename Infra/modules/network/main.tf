resource "azurerm_virtual_network" name {
    name = "${var.environment}-vnet"
    location =var.location
    resource_group_name = var.resource_group_name
    address_space = [var.vnet_address_space]
   

}
resource "azurerm_subnet" "public" {
  count = length(var.public_subnet_prefixes)
  name                 = "${var.environment}-public-subnet-${count.index + 1}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.name.name
  address_prefixes     = [var.public_subnet_prefixes[count.index]]
  service_endpoints    = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.ContainerRegistry"]
}
resource "azurerm_subnet" "private" {
  count                = length(var.private_subnet_prefixes)
  name                 = "${var.environment}-private-subnet-${count.index + 1}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.name.name
  address_prefixes     = [var.private_subnet_prefixes[count.index]]
  service_endpoints    = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.ContainerRegistry"]
}

resource "azurerm_subnet" "database" {
  count                = length(var.database_subnet_prefixes)
  name                 = "${var.environment}-db-subnet-${count.index + 1}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.name.name
  address_prefixes     = [var.database_subnet_prefixes[count.index]]
  service_endpoints    = ["Microsoft.Storage", "Microsoft.SQL"]

delegation {
    name = "flexi-servers"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.name.name
  address_prefixes     = [var.bastion_subnet_prefix]
}

resource "azurerm_subnet" "appgw" {
  name                 = "${var.environment}-appgw-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.name.name
  address_prefixes     = [var.appgw_subnet_prefix]
}
resource "azurerm_public_ip" "bastion" {
  name                = "${var.environment}-bastion-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

}
resource "azurerm_bastion_host" "name" {
  name                = "${var.environment}-bastion"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}
resource "azurerm_network_security_group" "nsg" {

  for_each = local.nsg_rules

  name                = "${var.environment}-${each.key}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  
  dynamic "security_rule" {
    for_each = each.value
    content {

    name                       = security_rule.value.name
    priority                   = security_rule.value.priority
    direction                  = security_rule.value.direction
    access                     = "Allow"
    protocol                   = security_rule.value.protocol
    source_port_range          = "*"
    destination_port_range     = lookup(security_rule.value, "port", null)
    destination_port_ranges    = lookup(security_rule.value, "ports", null)
    source_address_prefix      = security_rule.value.source
    destination_address_prefix = "VirtualNetwork"
      
    }
  
  }

}
# Associate NSGs with subnets
resource "azurerm_subnet_network_security_group_association" "public" {
  count                     = length(azurerm_subnet.public)
  subnet_id                 = azurerm_subnet.public[count.index].id
  network_security_group_id = azurerm_network_security_group.nsg["public"].id
}

resource "azurerm_subnet_network_security_group_association" "private" {
  count                     = length(azurerm_subnet.private)
  subnet_id                 = azurerm_subnet.private[count.index].id
  network_security_group_id = azurerm_network_security_group.nsg["private"].id
}

resource "azurerm_subnet_network_security_group_association" "database" {
  count                     = length(azurerm_subnet.database)
  subnet_id                 = azurerm_subnet.database[count.index].id
  network_security_group_id = azurerm_network_security_group.nsg["database"].id
}

# resource "azurerm_subnet_network_security_group_association" "bastion" {
#   subnet_id                 = azurerm_subnet.bastion.id
#   network_security_group_id = azurerm_network_security_group.nsg["bastion"].id
# }

resource "azurerm_nat_gateway" "natgw" {
  name                    = "${var.environment}-natgw"
  location                = var.location
  resource_group_name     = var.resource_group_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  
}


resource "azurerm_public_ip" "natgw-ip" {
  name                = "${var.environment}-natgw-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

}

resource "azurerm_nat_gateway_public_ip_association" "name" {
  nat_gateway_id       = azurerm_nat_gateway.natgw.id
  public_ip_address_id = azurerm_public_ip.natgw-ip.id
}


resource "azurerm_subnet_nat_gateway_association" "private" {
  count          = length(azurerm_subnet.private)
  subnet_id      = azurerm_subnet.private[count.index].id
  nat_gateway_id = azurerm_nat_gateway.natgw.id
}
































































































