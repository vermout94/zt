// Input variables for subscription, tenant, and region
variable "subscription_id" {
  description = "Azure Subscription ID for all resources"
  type        = string
}

variable "tenant_id" {
  description = "Azure Tenant ID (Directory ID) for management group hierarchy"
  type        = string
}

variable "default_location" {
  description = "Azure region to deploy resources (e.g., northeurope)"
  type        = string
  default     = "northeurope"
}
