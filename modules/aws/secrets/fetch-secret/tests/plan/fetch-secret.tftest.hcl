# Plan-level tests for the fetch-secret module.
# No AWS credentials required — the aws provider is mocked.
#
# This module reads a Secrets Manager secret version and jsondecode()s its
# secret_string into sensitive outputs. The secret version is mocked with a
# valid JSON secret_string containing the expected keys so the jsondecode()
# resolves at plan time and the projected outputs can be asserted.

mock_provider "aws" {
  mock_data "aws_secretsmanager_secret_version" {
    defaults = {
      secret_string = "{\"splunk-hec-token\":\"hec-abc123\",\"webhook\":\"https://example.gov.uk/hook\"}"
    }
  }
}

run "decodes_secret_and_projects_outputs" {
  command = plan

  variables {
    secret_name = "core-cloud/observability/tokens"
  }

  assert {
    condition     = output.hec_token == "hec-abc123"
    error_message = "hec_token output should be the splunk-hec-token value from the decoded secret."
  }

  assert {
    condition     = output.security_hub_alert_webhook == "https://example.gov.uk/hook"
    error_message = "security_hub_alert_webhook output should be the webhook value from the decoded secret."
  }
}
