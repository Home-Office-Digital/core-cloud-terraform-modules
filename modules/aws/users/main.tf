terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0, < 6.44.1"
    }
  }
}

resource "aws_identitystore_user" "identity_center_users" {
  for_each          = var.users
  identity_store_id = var.identity_store_id

  display_name = "${each.value.given_name} ${each.value.family_name}"
  user_name    = each.key

  name {
    given_name  = each.value.given_name
    family_name = each.value.family_name
  }

  emails {
    primary = true
    value   = each.value.email
  }
}
