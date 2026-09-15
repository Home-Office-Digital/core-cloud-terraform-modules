# Plan-level tests for the kms module.
# No AWS credentials required — the aws provider is mocked.

mock_provider "aws" {}

# Key is planned with the supplied description and rotation flag.
run "key_with_rotation_enabled" {
  command = plan

  variables {
    description      = "Encryption key for tenant data"
    rotation_enabled = true
  }

  assert {
    condition     = aws_kms_key.default.description == "Encryption key for tenant data"
    error_message = "Key description should be passed through."
  }

  assert {
    condition     = aws_kms_key.default.enable_key_rotation == true
    error_message = "enable_key_rotation should reflect rotation_enabled."
  }
}

# Rotation disabled is honoured.
run "key_with_rotation_disabled" {
  command = plan

  variables {
    description      = "Key without rotation"
    rotation_enabled = false
  }

  assert {
    condition     = aws_kms_key.default.enable_key_rotation == false
    error_message = "enable_key_rotation should be false when rotation_enabled is false."
  }
}
