# Plan-level tests for the groups module.
# No AWS credentials required — the aws provider is mocked.

mock_provider "aws" {}

# A single group is created and projected into the output map.
run "single_group_creates_and_outputs" {
  command = plan

  variables {
    identity_store_id = "d-1234567890"
    groups = {
      "platform-admins" = { group_description = "Platform administrators" }
    }
  }

  assert {
    condition     = length(aws_identitystore_group.identity_store_groups) == 1
    error_message = "Expected exactly one group to be planned."
  }

  assert {
    condition     = aws_identitystore_group.identity_store_groups["platform-admins"].display_name == "platform-admins"
    error_message = "Group display_name should equal the map key."
  }

  assert {
    condition     = aws_identitystore_group.identity_store_groups["platform-admins"].description == "Platform administrators"
    error_message = "Group description should come from group_description."
  }

  assert {
    condition     = aws_identitystore_group.identity_store_groups["platform-admins"].identity_store_id == "d-1234567890"
    error_message = "identity_store_id should be passed through to every group."
  }
}

# for_each fans out over every entry in the groups map.
run "multiple_groups_fan_out" {
  command = plan

  variables {
    identity_store_id = "d-abcde12345"
    groups = {
      "team-a" = { group_description = "Team A" }
      "team-b" = { group_description = "Team B" }
      "team-c" = { group_description = "Team C" }
    }
  }

  assert {
    condition     = length(aws_identitystore_group.identity_store_groups) == 3
    error_message = "Expected one planned group per map entry."
  }
}

# Empty input plans cleanly and creates nothing.
run "empty_groups_creates_nothing" {
  command = plan

  variables {
    identity_store_id = "d-0000000000"
    groups            = {}
  }

  assert {
    condition     = length(aws_identitystore_group.identity_store_groups) == 0
    error_message = "An empty groups map should plan zero resources."
  }
}
