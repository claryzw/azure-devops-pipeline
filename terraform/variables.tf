# variables.tf
# Declares all input variables for the project.
# Values are provided in terraform.tfvars (not committed to Git).

variable "subscription_id" {
  description = "Azure subscription ID where resources will be deployed"
  type        = string
  # No default - this MUST be provided in terraform.tfvars
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "australiaeast"
}

variable "resource_group_name" {
  description = "Name of the resource group to create"
  type        = string
  default     = "devops-pipeline-rg"
}

variable "project_name" {
  description = "Short project name used as a prefix for resource names"
  type        = string
  default     = "devopspipeline"

  # Validation block - Terraform will reject invalid input before deployment
  validation {
    condition     = length(var.project_name) <= 20 && can(regex("^[a-z0-9]+$", var.project_name))
    error_message = "project_name must be lowercase alphanumeric and 20 characters or fewer."
  }
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "alert_email" {
  description = "Email address to receive monitoring alerts"
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project   = "AzureDevOpsPipeline"
    ManagedBy = "Terraform"
    Owner     = "Clarence"
  }
}