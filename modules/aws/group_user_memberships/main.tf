terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0, < 6.53.1"
    }
  }
}

resource "aws_identitystore_group_membership" "group_membership" {
  for_each = var.members

  identity_store_id = var.identity_store_id
  group_id          = var.group
  member_id         = each.value
}
