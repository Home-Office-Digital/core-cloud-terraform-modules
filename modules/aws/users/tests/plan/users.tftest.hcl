# Plan-level tests for the users module.
# No AWS credentials required — the aws provider is mocked.

mock_provider "aws" {}

# A single user is created with a composed display name and nested name/email blocks.
run "single_user_composed_display_name" {
  command = plan

  variables {
    identity_store_id = "d-1234567890"
    users = {
      "jdoe" = {
        given_name  = "Jane"
        family_name = "Doe"
        email       = "jane.doe@example.gov.uk"
      }
    }
  }

  assert {
    condition     = length(aws_identitystore_user.identity_center_users) == 1
    error_message = "Expected exactly one user to be planned."
  }

  assert {
    condition     = aws_identitystore_user.identity_center_users["jdoe"].display_name == "Jane Doe"
    error_message = "display_name should be '<given_name> <family_name>'."
  }

  assert {
    condition     = aws_identitystore_user.identity_center_users["jdoe"].user_name == "jdoe"
    error_message = "user_name should equal the map key."
  }
}

# for_each fans out over every entry in the users map.
run "multiple_users_fan_out" {
  command = plan

  variables {
    identity_store_id = "d-abcde12345"
    users = {
      "asmith" = { given_name = "Alice", family_name = "Smith", email = "alice@example.gov.uk" }
      "bjones" = { given_name = "Bob", family_name = "Jones", email = "bob@example.gov.uk" }
    }
  }

  assert {
    condition     = length(aws_identitystore_user.identity_center_users) == 2
    error_message = "Expected one planned user per map entry."
  }

  assert {
    condition     = aws_identitystore_user.identity_center_users["bjones"].display_name == "Bob Jones"
    error_message = "Each user's display_name should be composed from its own names."
  }
}

# Empty input plans cleanly and creates nothing.
run "empty_users_creates_nothing" {
  command = plan

  variables {
    identity_store_id = "d-0000000000"
    users             = {}
  }

  assert {
    condition     = length(aws_identitystore_user.identity_center_users) == 0
    error_message = "An empty users map should plan zero resources."
  }
}
