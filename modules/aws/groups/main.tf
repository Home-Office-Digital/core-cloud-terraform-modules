terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0, < 6.56.1"
    }
  }
}

resource "aws_identitystore_group" "identity_store_groups" {
  for_each          = var.groups

  display_name      = each.key
  description       = each.value.group_description
  identity_store_id = var.identity_store_id
}
