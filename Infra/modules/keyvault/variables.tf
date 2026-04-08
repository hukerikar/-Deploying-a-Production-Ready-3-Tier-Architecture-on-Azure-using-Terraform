variable "environment" {
    type = string
    default = "prod"
  
}
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "prod-rg"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}


variable "tags" {
  description = "Tags to apply to resources"
  type        = string
}

variable "tenant_id" {
  description = "The Azure AD tenant ID"
  type        = string
}

variable "object_id" {
  description = "The object ID of the current user/service principal"
  type        = string
}

variable "frontend_identity_principal_id" {
  type    = string
  default = module.frontend_vmss.principal_id
}

variable "backend_identity_principal_id" {
  type    = string
  default = module.backend_vmss.principal_id

}