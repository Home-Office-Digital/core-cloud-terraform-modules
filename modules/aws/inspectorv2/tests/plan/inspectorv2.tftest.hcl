# Plan-level tests for the inspectorv2 module.
# The module picks the audit account based on whether the *current* caller
# account matches the dev-lza management id. We drive both branches by mocking
# aws_caller_identity to return each management id in turn.

mock_provider "aws" {}

mock_provider "aws" {
  alias = "management"
}

# When the current account IS the dev-lza management account, the module
# should register the DEV audit account as delegated admin.
run "dev_branch_selects_dev_audit" {
  command = plan

  # The default (unaliased) provider resolves aws_caller_identity; mock it here.
  override_data {
    target = data.aws_caller_identity.current
    values = {
      account_id = "100000000001" # == dev_lza_mgmt_id below
    }
  }

  variables {
    region                = "eu-west-2"
    dev_lza_mgmt_id       = "100000000001"
    prod_lza_mgmt_id      = "200000000002"
    dev_audit_account_id  = "300000000003"
    prod_audit_account_id = "400000000004"
  }

  assert {
    condition     = aws_inspector2_delegated_admin_account.this.account_id == "300000000003"
    error_message = "Dev management caller should select the dev audit account as delegated admin"
  }

  # The enabler targets the same audit account and enables all four resource types.
  assert {
    condition     = length(aws_inspector2_enabler.enable_in_audit_account.account_ids) == 1
    error_message = "Enabler should target exactly one (audit) account"
  }

  assert {
    condition     = length(aws_inspector2_enabler.enable_in_audit_account.resource_types) == 4
    error_message = "Enabler should enable EC2, ECR, LAMBDA and LAMBDA_CODE"
  }

  # A single org-prereqs bootstrap resource is planned.
  assert {
    condition     = null_resource.org_prereqs != null
    error_message = "org_prereqs bootstrap resource should be planned"
  }
}

# When the current account is NOT the dev-lza management account, the module
# should fall through to the PROD audit account.
run "prod_branch_selects_prod_audit" {
  command = plan

  override_data {
    target = data.aws_caller_identity.current
    values = {
      account_id = "200000000002" # != dev_lza_mgmt_id -> prod path
    }
  }

  variables {
    region                = "eu-west-2"
    dev_lza_mgmt_id       = "100000000001"
    prod_lza_mgmt_id      = "200000000002"
    dev_audit_account_id  = "300000000003"
    prod_audit_account_id = "400000000004"
  }

  assert {
    condition     = aws_inspector2_delegated_admin_account.this.account_id == "400000000004"
    error_message = "Non-dev caller should select the prod audit account as delegated admin"
  }

  assert {
    condition     = contains(aws_inspector2_enabler.enable_in_audit_account.resource_types, "LAMBDA_CODE")
    error_message = "Enabler resource types should include LAMBDA_CODE"
  }
}
