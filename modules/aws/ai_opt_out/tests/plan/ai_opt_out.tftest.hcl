# Plan-level tests for the ai_opt_out module.
# No AWS credentials required — the aws provider is mocked.

mock_provider "aws" {}

# Defaults: policy is created, no attachments when the target list is empty.
run "policy_defaults_no_targets" {
  command = plan

  variables {
    apply_to_ous_or_accounts = []
  }

  assert {
    condition     = aws_organizations_policy.ai_services_opt_out.name == "AIServicesOptOutPolicy"
    error_message = "policy_name should default to AIServicesOptOutPolicy."
  }

  assert {
    condition     = aws_organizations_policy.ai_services_opt_out.description == "Policy to opt out of AI services"
    error_message = "policy_description should use its default value."
  }

  assert {
    condition     = aws_organizations_policy.ai_services_opt_out.type == "AISERVICES_OPT_OUT_POLICY"
    error_message = "Policy type should be AISERVICES_OPT_OUT_POLICY."
  }

  # for_each over an empty target list → no attachments planned.
  assert {
    condition     = length(aws_organizations_policy_attachment.ai_opt_out) == 0
    error_message = "No attachments should be planned when apply_to_ous_or_accounts is empty."
  }
}

# Custom name/description are passed through to the policy resource.
run "custom_name_and_description" {
  command = plan

  variables {
    policy_name              = "CustomAIOptOut"
    policy_description       = "Custom description"
    apply_to_ous_or_accounts = []
  }

  assert {
    condition     = aws_organizations_policy.ai_services_opt_out.name == "CustomAIOptOut"
    error_message = "policy_name should be passed through."
  }

  assert {
    condition     = aws_organizations_policy.ai_services_opt_out.description == "Custom description"
    error_message = "policy_description should be passed through."
  }
}

# for_each fans out over every OU/account in the target list.
run "attachments_fan_out_over_targets" {
  command = plan

  variables {
    apply_to_ous_or_accounts = ["ou-abcd-11111111", "ou-abcd-22222222", "123456789012"]
  }

  assert {
    condition     = length(aws_organizations_policy_attachment.ai_opt_out) == 3
    error_message = "One attachment should be planned per target in apply_to_ous_or_accounts."
  }

  assert {
    condition     = aws_organizations_policy_attachment.ai_opt_out["123456789012"].target_id == "123456789012"
    error_message = "Each attachment's target_id should match its own set member."
  }
}
