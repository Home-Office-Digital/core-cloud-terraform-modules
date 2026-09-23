# Plan-level tests for the enable-inspectorv2 module.
# The module enumerates ACTIVE org member accounts (excluding the org master
# and the current caller) and creates one member association per account via
# for_each. We mock the organization data source with a mix of accounts to
# exercise that filtering logic and assert the resulting association count.

mock_provider "aws" {}

run "filters_active_members_excluding_master_and_self" {
  command = plan

  variables {
    region = "eu-west-2"
  }

  # Current caller is the "self" account, which must be excluded.
  override_data {
    target = data.aws_caller_identity.current
    values = {
      account_id = "999999999999"
    }
  }

  # 5 accounts: master + self are excluded; one is SUSPENDED (excluded);
  # leaving exactly 2 ACTIVE members eligible for association.
  override_data {
    target = data.aws_organizations_organization.this
    values = {
      master_account_id = "111111111111"
      accounts = [
        { id = "111111111111", status = "ACTIVE" },   # master -> excluded
        { id = "999999999999", status = "ACTIVE" },   # self   -> excluded
        { id = "222222222222", status = "ACTIVE" },   # eligible
        { id = "333333333333", status = "ACTIVE" },   # eligible
        { id = "444444444444", status = "SUSPENDED" } # inactive -> excluded
      ]
    }
  }

  assert {
    condition     = length(aws_inspector2_member_association.associate_members) == 2
    error_message = "Only the two ACTIVE, non-master, non-self accounts should be associated"
  }

  assert {
    condition     = contains(keys(aws_inspector2_member_association.associate_members), "222222222222")
    error_message = "Eligible account 222222222222 should have a member association"
  }

  assert {
    condition     = !contains(keys(aws_inspector2_member_association.associate_members), "111111111111")
    error_message = "The org master account must not be associated"
  }

  # The org-wide auto-enable configuration covers all four scan types.
  assert {
    condition = (
      aws_inspector2_organization_configuration.this.auto_enable[0].ec2 == true &&
      aws_inspector2_organization_configuration.this.auto_enable[0].ecr == true &&
      aws_inspector2_organization_configuration.this.auto_enable[0].lambda == true &&
      aws_inspector2_organization_configuration.this.auto_enable[0].lambda_code == true
    )
    error_message = "Org configuration should auto-enable ec2, ecr, lambda and lambda_code"
  }
}

# Edge case: no eligible members (org holds only master + self) -> zero associations.
run "no_eligible_members_creates_no_associations" {
  command = plan

  variables {
    region = "eu-west-2"
  }

  override_data {
    target = data.aws_caller_identity.current
    values = {
      account_id = "999999999999"
    }
  }

  override_data {
    target = data.aws_organizations_organization.this
    values = {
      master_account_id = "111111111111"
      accounts = [
        { id = "111111111111", status = "ACTIVE" }, # master
        { id = "999999999999", status = "ACTIVE" }  # self
      ]
    }
  }

  assert {
    condition     = length(aws_inspector2_member_association.associate_members) == 0
    error_message = "With only master and self accounts, no member associations should be created"
  }
}
