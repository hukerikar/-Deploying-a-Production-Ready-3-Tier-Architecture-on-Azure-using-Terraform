environment         = "prod"
location            = "centralus"
# Network (keep same)
vnet_address_space       = "10.0.0.0/16"
public_subnet_prefixes   = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_prefixes  = ["10.0.3.0/24", "10.0.4.0/24"]
database_subnet_prefixes = ["10.0.5.0/24", "10.0.6.0/24"]
bastion_subnet_prefix    = "10.0.7.0/24"
appgw_subnet_prefix      = "10.0.8.0/24"

# Compute (cheapest possible)
frontend_vm_size   = "Standard_DC1s_v3"
backend_vm_size    = "Standard_DC1s_v3"
frontend_instances = 1
backend_instances  = 1
admin_username     = "adminuser"

# Database (cheapest)

postgres_sku_name   = "GP_Standard_D2s_v3"
postgres_version    = "14"
postgres_storage_mb = 32768
postgres_db_name    = "goalsdb"
postgres_db_port    = 5432
postgres_db_sslmode = "require"

# Docker
dockerhub_username = ""
dockerhub_password = ""   

frontend_image = "srujandaddy/siem-dashboard"
backend_image  = "srujandaddy/siem-backend"
agent_image = "srujandaddy/siem-agent"
