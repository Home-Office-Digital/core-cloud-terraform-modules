# Plan-level tests for the backup_vault module.
# Uses a mocked AWS provider so no credentials or real API calls are needed.
# The aws_iam_policy_document data source is mocked to return a valid JSON string.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111122223333"
      arn        = "arn:aws:iam::111122223333:root"
      user_id    = "AIDAEXAMPLE"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

# Baseline plan with the KMS defaults and no vault policy.
run "defaults_no_policy" {
  command = plan

  variables {
    name              = "core-backup"
    tags              = { Environment = "test" }
    org_id            = "o-abc123def4"
    backup_account_id = "444455556666"
  }

  # No policy JSON supplied -> the count-gated policy resource is not created.
  assert {
    condition     = length(aws_backup_vault_policy.this) == 0
    error_message = "backup_vault_policy should not be created when backup_vault_policy_json is empty"
  }

  # Vault name passes straight through.
  assert {
    condition     = aws_backup_vault.this.name == "core-backup"
    error_message = "Backup vault name did not match the input variable"
  }

  # Default alias derives from the vault name: alias/<name>-key.
  assert {
    condition     = aws_kms_alias.cmek_alias.name == "alias/core-backup-key"
    error_message = "Default KMS alias should be alias/<name>-key"
  }

  # KMS rotation / deletion window defaults.
  assert {
    condition     = aws_kms_key.cmek.enable_key_rotation == true
    error_message = "Key rotation should default to true"
  }

  assert {
    condition     = aws_kms_key.cmek.deletion_window_in_days == 7
    error_message = "Deletion window should default to 7 days"
  }

  # Vault ARN uses account/region interpolation from the mocked provider,
  # so tags passthrough is a stable plan-known assertion instead.
  assert {
    condition     = aws_backup_vault.this.tags["Environment"] == "test"
    error_message = "Tags should pass through to the backup vault"
  }
}

# Supplying a vault policy JSON should create the count-gated policy resource.
run "with_vault_policy" {
  command = plan

  variables {
    name                     = "policy-vault"
    tags                     = { Environment = "test" }
    org_id                   = "o-abc123def4"
    backup_account_id        = "444455556666"
    backup_vault_policy_json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
  }

  assert {
    condition     = length(aws_backup_vault_policy.this) == 1
    error_message = "backup_vault_policy should be created when a policy JSON is supplied"
  }
}

# A custom KMS alias overrides the name-derived default.
run "custom_kms_alias" {
  command = plan

  variables {
    name                         = "aliased-vault"
    tags                         = { Environment = "test" }
    org_id                       = "o-abc123def4"
    backup_account_id            = "444455556666"
    kms_key_alias                = "my-custom"
    kms_key_enable_rotation      = false
    kms_key_deletion_window_days = 30
  }

  assert {
    condition     = aws_kms_alias.cmek_alias.name == "alias/my-custom-key"
    error_message = "Custom alias should compose to alias/<kms_key_alias>-key"
  }

  assert {
    condition     = aws_kms_key.cmek.enable_key_rotation == false
    error_message = "Key rotation should honour the supplied value"
  }

  assert {
    condition     = aws_kms_key.cmek.deletion_window_in_days == 30
    error_message = "Deletion window should honour the supplied value"
  }
}
