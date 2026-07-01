terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version =  ">= 5.0.0, < 6.53.1"
    }
  }
}

locals {
  flattened_accounts = flatten([
    for account, permission_sets in var.accounts: [
      for key, permission_set in permission_sets: {
        account_id = account
        permission_set = permission_set
      }
    ]
  ])
}

data "aws_ssoadmin_permission_set" "identity_center_permission_set" {
  for_each = { for value in local.flattened_accounts : "${value.account_id}.${value.permission_set}" => value }

  name = each.value.permission_set
  instance_arn = var.identity_store.arn
}

data "aws_identitystore_group" "identity_store_groups" {
  identity_store_id = var.identity_store.id
  
  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = var.group_name
    }
  }
}

resource "aws_ssoadmin_account_assignment" "user_account_assignments" {
  for_each = { for value in local.flattened_accounts : "${value.account_id}.${value.permission_set}" => value }

  instance_arn       = var.identity_store.arn
  permission_set_arn = data.aws_ssoadmin_permission_set.identity_center_permission_set[each.key].arn
  
  principal_id   = data.aws_identitystore_group.identity_store_groups.id
  principal_type = "GROUP"

  target_id   = each.value.account_id
  target_type = "AWS_ACCOUNT"
}
