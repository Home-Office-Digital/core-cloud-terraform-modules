# Plan-level tests for the group_account_assignments module.
# No AWS credentials required — the aws provider is mocked.
#
# The permission-set lookup and group lookup feed provider-validated resource
# arguments (permission_set_arn must be an ARN; principal_id must be a UUID),
# so their data sources are mocked with valid-format defaults.

mock_provider "aws" {
  mock_data "aws_ssoadmin_permission_set" {
    defaults = {
      arn = "arn:aws:sso:::permissionSet/ssoins-0123456789abcdef/ps-0123456789abcdef"
    }
  }

  mock_data "aws_identitystore_group" {
    defaults = {
      id = "01234567-89ab-cdef-0123-456789abcdef"
    }
  }
}

# A single account with a single permission set fans out to one assignment.
run "single_account_single_permission_set" {
  command = plan

  variables {
    identity_store = {
      id  = "d-1234567890"
      arn = "arn:aws:sso:::instance/ssoins-0123456789abcdef"
    }
    group_name = "platform-admins"
    accounts = {
      "111111111111" = ["ReadOnlyAccess"]
    }
  }

  assert {
    condition     = length(aws_ssoadmin_account_assignment.user_account_assignments) == 1
    error_message = "One account/permission-set pair should plan exactly one assignment."
  }

  assert {
    condition     = aws_ssoadmin_account_assignment.user_account_assignments["111111111111.ReadOnlyAccess"].target_id == "111111111111"
    error_message = "target_id should be the account id from the flattened key."
  }

  assert {
    condition     = aws_ssoadmin_account_assignment.user_account_assignments["111111111111.ReadOnlyAccess"].target_type == "AWS_ACCOUNT"
    error_message = "target_type should always be AWS_ACCOUNT."
  }

  assert {
    condition     = aws_ssoadmin_account_assignment.user_account_assignments["111111111111.ReadOnlyAccess"].principal_type == "GROUP"
    error_message = "principal_type should always be GROUP."
  }

  assert {
    condition     = aws_ssoadmin_account_assignment.user_account_assignments["111111111111.ReadOnlyAccess"].instance_arn == "arn:aws:sso:::instance/ssoins-0123456789abcdef"
    error_message = "instance_arn should be passed through from identity_store.arn."
  }
}

# The flatten() over accounts -> permission_sets produces one assignment per pair.
run "multiple_accounts_and_permission_sets_fan_out" {
  command = plan

  variables {
    identity_store = {
      id  = "d-abcde12345"
      arn = "arn:aws:sso:::instance/ssoins-abcdef0123456789"
    }
    group_name = "team-admins"
    accounts = {
      "111111111111" = ["ReadOnlyAccess", "PowerUserAccess"]
      "222222222222" = ["ReadOnlyAccess"]
    }
  }

  # 2 permission sets on the first account + 1 on the second = 3 flattened pairs.
  assert {
    condition     = length(aws_ssoadmin_account_assignment.user_account_assignments) == 3
    error_message = "Expected one assignment per (account, permission_set) pair from the flatten()."
  }

  assert {
    condition     = length(data.aws_ssoadmin_permission_set.identity_center_permission_set) == 3
    error_message = "Expected one permission-set lookup per flattened pair."
  }

  assert {
    condition     = aws_ssoadmin_account_assignment.user_account_assignments["222222222222.ReadOnlyAccess"].target_id == "222222222222"
    error_message = "Each assignment's target_id should match its own account id."
  }
}

# Empty accounts map plans cleanly and creates no assignments.
run "empty_accounts_creates_nothing" {
  command = plan

  variables {
    identity_store = {
      id  = "d-0000000000"
      arn = "arn:aws:sso:::instance/ssoins-0000000000000000"
    }
    group_name = "empty-group"
    accounts   = {}
  }

  assert {
    condition     = length(aws_ssoadmin_account_assignment.user_account_assignments) == 0
    error_message = "An empty accounts map should plan zero assignments."
  }
}
