variable "vnet_id" {
  description = "ID of the Virtual Network"
  type        = string
}
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "prod-rg"
}
variable "tags" {
  description = "Tags to apply to resources"
  type        = string
}
variable "enviornment" {
  type        = string
  default = "prod"
}