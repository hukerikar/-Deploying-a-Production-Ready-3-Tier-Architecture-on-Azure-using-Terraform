# Get current Azure client config for tenant_id and object_id
data "azurerm_client_config" "current" {}
# Resource Group
resource "azurerm_resource_group" "name" {
  name     = "${var.environment}-rg"
  location = var.location
}

# network Module
module "network" {
  source = "./modules/network"
  depends_on = [azurerm_resource_group.name]  
  resource_group_name      = var.resource_group_name
  location                 = var.location
  environment = var.environment
  vnet_address_space       = var.vnet_address_space
  public_subnet_prefixes   = var.public_subnet_prefixes
  private_subnet_prefixes  = var.private_subnet_prefixes
  database_subnet_prefixes = var.database_subnet_prefixes
  bastion_subnet_prefix    = var.bastion_subnet_prefix
  appgw_subnet_prefix      = var.appgw_subnet_prefix
  tags                     = var.environment
}

module "keyvault" {
  source = "./modules/keyvault"

  environment         = var.environment
  location            = var.location
  resource_group_name = azurerm_resource_group.name.name
  tenant_id           = data.azurerm_client_config.current.tenant_id

  object_id = data.azurerm_client_config.current.object_id

  tags = var.environment
}


# After Key Vault is created, store database credentials as secrets
resource "azurerm_key_vault_secret" "db_host" {
  name         = "db-host"
  value        = module.database.server_fqdn
  key_vault_id = module.keyvault.key_vault_id

  depends_on = [module.keyvault, module.database]
}

resource "azurerm_key_vault_secret" "db_username" {
  name         = "db-username"
  value        = module.database.administrator_login
  key_vault_id = module.keyvault.key_vault_id

  depends_on = [module.keyvault, module.database]
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = module.database.administrator_password
  key_vault_id = module.keyvault.key_vault_id

  depends_on = [module.keyvault, module.database]
}

resource "azurerm_key_vault_secret" "db_name" {
  name         = "db-name"
  value        = var.postgres_db_name
  key_vault_id = module.keyvault.key_vault_id

  depends_on = [module.keyvault]
}

# Add DB port and SSL mode to Key Vault
resource "azurerm_key_vault_secret" "db_port" {
  name         = "db-port"
  value        = tostring(var.postgres_db_port)
  key_vault_id = module.keyvault.key_vault_id

  depends_on = [module.keyvault]
}

resource "azurerm_key_vault_secret" "db_sslmode" {
  name         = "db-sslmode"
  value        = var.postgres_db_sslmode
  key_vault_id = module.keyvault.key_vault_id

  depends_on = [module.keyvault]
}

# Store Docker Hub credentials in Key Vault
resource "azurerm_key_vault_secret" "dockerhub_username" {
  name         = "dockerhub-username"
  value        = var.dockerhub_username
  key_vault_id = module.keyvault.key_vault_id

  depends_on = [module.keyvault]
}

resource "azurerm_key_vault_secret" "dockerhub_pat" {
  name         = "dockerhub-pat"
  value        = var.dockerhub_password
  key_vault_id = module.keyvault.key_vault_id

  depends_on = [module.keyvault]
}

# Database
module "database" {
  source = "./modules/database"
  depends_on = [azurerm_resource_group.name , module.dns]  
  resource_group_name  = var.resource_group_name
  location             = var.location
  database_subnet_ids  = module.network.database_subnet_ids
  private_dns_zone_id  = module.dns.private_dns_zone_id
  postgres_sku_name    = var.postgres_sku_name
  postgres_version     = var.postgres_version
  postgres_storage_mb  = var.postgres_storage_mb
  postgres_db_name     = var.postgres_db_name
  

  }

# DNS for Private Endpoints
module "dns" {
  source = "./modules/DNS"
  depends_on = [azurerm_resource_group.name]  
  resource_group_name = var.resource_group_name
  vnet_id             = module.network.vnet_id
  tags                = var.environment
}

# Compute - Frontend VMSS
module "frontend" {
  count  = var.deploy_compute ? 1 : 0
  source = "./modules/VM"
  environment = var.environment
  resource_group_name  = var.resource_group_name
  location             = var.location
  subnet_id            = module.network.public_subnet_ids[0]
  appgw_subnet_id      = module.network.appgw_subnet_id
  vm_size              = var.frontend_vm_size
  instance_count       = var.frontend_instances
  admin_username       = var.admin_username
  dockerhub_username   = var.dockerhub_username
  dockerhub_password   = var.dockerhub_password
  docker_image         = var.frontend_image
  is_frontend          = true
  application_port     = 3000
  health_probe_path    = "/"
  key_vault_id         = module.keyvault.key_vault_id
  # Pass the backend load balancer IP if the backend module has been created
  
  backend_load_balancer_ip = try(module.backend[0].load_balancer_private_ip, null)

  depends_on = [
    module.keyvault,
    # We can't use conditionals in depends_on, so we'll rely on the backend module's count to handle this dependency
    module.backend
  ]
}

# Compute - Backend VMSS
module "backend" {
  count  = var.deploy_compute ? 1 : 0
  source = "./modules/VM"
  environment = var.environment
  resource_group_name  = var.resource_group_name
  location             = var.location
  subnet_id            = module.network.private_subnet_ids[0]
  vm_size              = var.backend_vm_size
  instance_count       = var.backend_instances
  admin_username       = var.admin_username
  dockerhub_username   = var.dockerhub_username
  dockerhub_password   = var.dockerhub_password
  docker_image         = var.backend_image
  is_frontend          = false
  application_port     = 8080
  health_probe_path    = "/health"
  key_vault_id         = module.keyvault.key_vault_id


  database_connection = {
    host     = module.database.server_fqdn
    port     = var.postgres_db_port
    username = module.database.administrator_login
    password = module.database.administrator_password
    dbname   = var.postgres_db_name
    sslmode  = var.postgres_db_sslmode
  }

  depends_on = [
    module.keyvault,
    module.database
  ]
}


# Monitoring Module for VMSS
# module "monitoring" {
#   source = "./modules/monitoring"

#   resource_group_name         = var.resource_group_name
#   location                    = var.location
#   resource_name_prefix        = local.resource_name_prefix
#   frontend_vmss_id            = var.deploy_compute ? module.frontend[0].vmss_id : null
#   backend_vmss_id             = var.deploy_compute ? module.backend[0].vmss_id : null
#   create_frontend_diagnostics = var.deploy_compute
#   create_backend_diagnostics  = var.deploy_compute
#   log_analytics_sku           = var.log_analytics_sku
#   log_retention_days          = var.log_retention_days
#   alert_email                 = var.alert_email
#   tags                        = var.environment

#   depends_on = [module.frontend, module.backend]
# }

# Key Vault Access Policy for Frontend VMSS
# Commenting out as they reference the commented-out managed identities
# resource "azurerm_key_vault_access_policy" "frontend" {
#   count        = var.deploy_compute ? 1 : 0
#   key_vault_id = module.keyvault.key_vault_id
#   tenant_id    = data.azurerm_client_config.current.tenant_id
#   # Changed to use the frontend user-assigned identity directly
#   object_id = azurerm_user_assigned_identity.frontend[0].principal_id
#
#   secret_permissions = [
#     "Get",
#     "List"
#   ]
#
#   depends_on = [module.keyvault, module.frontend]
# }

# Key Vault Access Policy for Backend VMSS
# Commenting out as they reference the commented-out managed identities
# resource "azurerm_key_vault_access_policy" "backend" {
#   count        = var.deploy_compute ? 1 : 0
#   key_vault_id = module.keyvault.key_vault_id
#   tenant_id    = data.azurerm_client_config.current.tenant_id
#   # Changed to use the backend user-assigned identity directly
#   object_id = azurerm_user_assigned_identity.backend[0].principal_id
#
#   secret_permissions = [
#     "Get",
#     "List"
#   ]
#
#   depends_on = [module.keyvault, module.backend]
