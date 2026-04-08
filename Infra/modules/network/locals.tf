locals {
  
  nsg_rules = {
    
    public = [
      {
        name      = "AllowHTTPInbound"
        priority  = 100
        direction = "Inbound"
        protocol  = "Tcp"
        port      = "80"
        source    = "Internet"
      },
      {
        name      = "AllowHTTPSInbound"
        priority  = 110
        direction = "Inbound"
        protocol  = "Tcp"
        port      = "443"
        source    = "Internet"
      },
      {
        name      = "AllowSSHFromBastion"
        priority  = 115
        direction = "Inbound"
        protocol  = "Tcp"
        port      = "22"
        source    = var.bastion_subnet_prefix
      }
    ]

    private = [
      {
        name      = "AllowBackendAppPort"
        priority  = 110
        direction = "Inbound"
        protocol  = "Tcp"
        port      = "8080"
        source    = var.vnet_address_space
      }
    ]

    database = [
      {
        name      = "AllowPostgreSQLInbound"
        priority  = 100
        direction = "Inbound"
        protocol  = "Tcp"
        port      = "5432"
        source    = var.vnet_address_space
      }
    ]

    bastion = [
      {
        name      = "AllowHttpsInbound"
        priority  = 100
        direction = "Inbound"
        protocol  = "Tcp"
        port      = "443"
        source    = "Internet"
      },
      {
        name      = "AllowGatewayManagerInbound"
        priority  = 110
        direction = "Inbound"
        protocol  = "Tcp"
        port      = "443"
        source    = "GatewayManager"
      },
      {
        name      = "AllowAzureLoadBalancerInbound"
        priority  = 120
        direction = "Inbound"
        protocol  = "Tcp"
        port      = "443"
        source    = "AzureLoadBalancer"
      },
      {
        name      = "AllowBastionHostComm"
        priority  = 130
        direction = "Inbound"
        protocol  = "Tcp"
        ports     = ["8080", "5701"]
        source    = "VirtualNetwork"
      }
    ]

  }
}