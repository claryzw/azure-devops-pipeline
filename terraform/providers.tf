# providers.tf
# Declares which providers Terraform needs and how to configure them.

terraform {
  # Minimum Terraform version - prevents old versions from running this code
  required_version = ">= 1.5.0"

  # Required providers block - lists every provider this project uses
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Configure the Azure Resource Manager provider
# The "features" block is mandatory - even if empty - for the azurerm provider
provider "azurerm" {
  features {
    resource_group {
      # Allow Terraform to delete resource groups that contain Azure-managed
      # "ghost" resources (like Application Insights Smart Detection action groups).
      # These are auto-created by Azure and not tracked by Terraform.
      prevent_deletion_if_contains_resources = false
    }
  }

  # Subscription ID is pulled from terraform.tfvars (not hardcoded here)
  # This keeps secrets out of version control
  subscription_id = var.subscription_id
}