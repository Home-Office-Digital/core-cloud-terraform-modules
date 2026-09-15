# Plan-level tests for the permission_sets module.
# No AWS credentials required — the aws provider is mocked. The
# aws_iam_policy_document data source is mocked with a valid JSON default.

mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

# Minimal permission set: no inline policies, no managed policies.
run "minimal_permission_set" {
  command = plan

  variables {
    name               = "read-only"
    description        = "Read only access"
    identity_store_arn = "arn:aws:sso:::instance/ssoins-0123456789abcdef"
    inline_policies    = []
    managed_policies   = []
  }

  assert {
    condition     = aws_ssoadmin_permission_set.identity_store_permission_set.name == "read-only"
    error_message = "Permission set name should be passed through."
  }

  # count = length(inline_policies) → 0 when none supplied.
  assert {
    condition     = length(aws_ssoadmin_permission_set_inline_policy.permission_set_inline_policy) == 0
    error_message = "No inline policy resource should be planned when inline_policies is empty."
  }

  # for_each over managed_policies → none supplied.
  assert {
    condition     = length(aws_ssoadmin_managed_policy_attachment.permission_set_managed_policy) == 0
    error_message = "No managed policy attachments should be planned when managed_policies is empty."
  }
}

# Inline policy present → count-based inline policy resource is planned.
run "inline_policy_creates_resource" {
  command = plan

  variables {
    name               = "s3-reader"
    description        = "S3 read access"
    identity_store_arn = "arn:aws:sso:::instance/ssoins-0123456789abcdef"
    inline_policies = [
      {
        sid       = "AllowS3Read"
        actions   = ["s3:GetObject", "s3:ListBucket"]
        resources = ["*"]
      }
    ]
    managed_policies = []
  }

  assert {
    condition     = length(aws_ssoadmin_permission_set_inline_policy.permission_set_inline_policy) == 1
    error_message = "One inline policy resource should be planned when an inline policy is supplied."
  }
}

# Managed policies present → one attachment planned per policy via for_each.
run "managed_policies_fan_out" {
  command = plan

  variables {
    name               = "power-user"
    description        = "Power user access"
    identity_store_arn = "arn:aws:sso:::instance/ssoins-0123456789abcdef"
    inline_policies    = []
    managed_policies   = ["ReadOnlyAccess", "AmazonS3ReadOnlyAccess"]
  }

  assert {
    condition     = length(aws_ssoadmin_managed_policy_attachment.permission_set_managed_policy) == 2
    error_message = "One managed policy attachment should be planned per managed policy."
  }

  assert {
    condition     = aws_ssoadmin_managed_policy_attachment.permission_set_managed_policy["ReadOnlyAccess"].managed_policy_arn == "arn:aws:iam::aws:policy/ReadOnlyAccess"
    error_message = "Managed policy ARN should be composed from the policy name."
  }
}
