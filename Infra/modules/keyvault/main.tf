# -----------------------------
# Key Vault
# -----------------------------
resource "azurerm_key_vault" "kv" {
  name                        = "${var.environment}-kv-srujan"
  location                    = var.location
  resource_group_name         = var.resource_group_name
  enabled_for_disk_encryption = true
  tenant_id                   = var.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  rbac_authorization_enabled  = true
  sku_name                    = "standard"
  depends_on = [ azurerm_key_vault.kv]
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }
}

# -----------------------------
# Admin Access (You)
# -----------------------------
resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.object_id
}

# -----------------------------
# Backend VMSS Access
# -----------------------------
resource "azurerm_role_assignment" "backend_secret_user" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.backend_identity_principal_id
}

# -----------------------------
# Frontend VMSS Access (IMPORTANT)
# -----------------------------
resource "azurerm_role_assignment" "frontend_secret_user" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.frontend_identity_principal_id
}
