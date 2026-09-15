# Plan-level tests for the ssoadmin_instance module.
# No AWS credentials required — the aws provider is mocked.
#
# This module is a pure lookup: it reads the aws_ssoadmin_instances data source
# and projects the first identity store id/arn into an output. It takes no input
# variables and defines no managed resources. The data source is mocked with a
# non-empty single-instance result so the tolist(...)[0] projections resolve, and
# plan success is the assertion that the lookup and output projection are
# well-formed.

mock_provider "aws" {
  mock_data "aws_ssoadmin_instances" {
    defaults = {
      identity_store_ids = ["d-1234567890"]
      arns               = ["arn:aws:sso:::instance/ssoins-0123456789abcdef"]
    }
  }
}

run "plans_cleanly_with_no_inputs" {
  command = plan

  assert {
    condition     = output.instance.id == "d-1234567890"
    error_message = "output.instance.id should be the first identity store id."
  }

  assert {
    condition     = output.instance.arn == "arn:aws:sso:::instance/ssoins-0123456789abcdef"
    error_message = "output.instance.arn should be the first instance arn."
  }
}
