# Plan-level tests for the group_user_memberships module.
# No AWS credentials required — the aws provider is mocked.

mock_provider "aws" {}

# A single member is added to the group.
run "single_member" {
  command = plan

  variables {
    identity_store_id = "d-1234567890"
    group             = "g-0123456789abcdef"
    members = {
      "jdoe" = "u-1111111111111111"
    }
  }

  assert {
    condition     = length(aws_identitystore_group_membership.group_membership) == 1
    error_message = "One member should plan exactly one membership."
  }

  assert {
    condition     = aws_identitystore_group_membership.group_membership["jdoe"].member_id == "u-1111111111111111"
    error_message = "member_id should be the value from the members map."
  }

  assert {
    condition     = aws_identitystore_group_membership.group_membership["jdoe"].group_id == "g-0123456789abcdef"
    error_message = "group_id should be passed through from var.group."
  }

  assert {
    condition     = aws_identitystore_group_membership.group_membership["jdoe"].identity_store_id == "d-1234567890"
    error_message = "identity_store_id should be passed through to every membership."
  }
}

# for_each fans out over every entry in the members map.
run "multiple_members_fan_out" {
  command = plan

  variables {
    identity_store_id = "d-abcde12345"
    group             = "g-abcdef0123456789"
    members = {
      "asmith" = "u-2222222222222222"
      "bjones" = "u-3333333333333333"
      "cwong"  = "u-4444444444444444"
    }
  }

  assert {
    condition     = length(aws_identitystore_group_membership.group_membership) == 3
    error_message = "Expected one membership per map entry."
  }

  assert {
    condition     = aws_identitystore_group_membership.group_membership["bjones"].member_id == "u-3333333333333333"
    error_message = "Each membership's member_id should match its own map value."
  }
}

# Empty members map plans cleanly and creates nothing.
run "empty_members_creates_nothing" {
  command = plan

  variables {
    identity_store_id = "d-0000000000"
    group             = "g-0000000000000000"
    members           = {}
  }

  assert {
    condition     = length(aws_identitystore_group_membership.group_membership) == 0
    error_message = "An empty members map should plan zero memberships."
  }
}
