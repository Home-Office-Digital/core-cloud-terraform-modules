# Plan-level tests for the cw-logs-destination module.
# Uses mock_provider so no AWS credentials or network calls are needed.
#
# Note: aws_cloudwatch_log_destination_policy.access_policy embeds the
# destination ARN (a computed attribute), so the rendered policy string is
# unknown at plan time and cannot be asserted on directly. We assert instead
# on values that are known during plan: variable pass-through, fixed naming,
# and the assume-role policy (which only depends on var.aws_region).

mock_provider "aws" {}

# Account-based path (organization_id defaulted to null).
run "account_based_defaults" {
  command = plan

  variables {
    destination_name  = "central-logs-destination"
    source_account_id = ["111111111111", "222222222222"]
    firehose_arn      = "arn:aws:firehose:eu-west-2:333333333333:deliverystream/central"
    tags              = { Environment = "prod" }
  }

  assert {
    condition     = aws_cloudwatch_log_destination.cw_logs_destination.name == "central-logs-destination"
    error_message = "Destination name should pass through from var.destination_name"
  }

  assert {
    condition     = aws_cloudwatch_log_destination.cw_logs_destination.target_arn == "arn:aws:firehose:eu-west-2:333333333333:deliverystream/central"
    error_message = "target_arn should pass through from var.firehose_arn"
  }

  assert {
    condition     = aws_cloudwatch_log_destination.cw_logs_destination.tags["Environment"] == "prod"
    error_message = "Tags should pass through onto the destination"
  }

  assert {
    condition     = aws_iam_role.logs_destination_role.name == "CloudWatchLogsDestinationRole"
    error_message = "IAM role name should be the fixed CloudWatchLogsDestinationRole"
  }

  # assume_role_policy only depends on var.aws_region (default eu-west-2),
  # so it is fully known at plan time.
  assert {
    condition     = strcontains(aws_iam_role.logs_destination_role.assume_role_policy, "logs.eu-west-2.amazonaws.com")
    error_message = "Assume-role policy should scope to the regional CloudWatch Logs service principal"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.logs_destination_policy.policy, "firehose:PutRecord")
    error_message = "Inline role policy should grant firehose:PutRecord*"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.logs_destination_policy.policy, "arn:aws:firehose:eu-west-2:333333333333:deliverystream/central")
    error_message = "Inline role policy Resource should be the supplied firehose ARN"
  }
}

# aws_region override flows into the assume-role service principal.
run "region_override" {
  command = plan

  variables {
    destination_name  = "org-logs-destination"
    source_account_id = ["111111111111"]
    firehose_arn      = "arn:aws:firehose:eu-west-1:333333333333:deliverystream/central"
    organization_id   = "o-abc123def4"
    aws_region        = "eu-west-1"
  }

  assert {
    condition     = strcontains(aws_iam_role.logs_destination_role.assume_role_policy, "logs.eu-west-1.amazonaws.com")
    error_message = "aws_region override should be reflected in the service principal"
  }
}

# Edge case: empty tags map and empty source-account list still plan cleanly.
run "empty_inputs" {
  command = plan

  variables {
    destination_name  = "d"
    source_account_id = []
    firehose_arn      = "arn:aws:firehose:eu-west-2:333333333333:deliverystream/x"
    tags              = {}
  }

  assert {
    condition     = length(aws_cloudwatch_log_destination.cw_logs_destination.tags) == 0
    error_message = "Empty tags map should produce a destination with no tags"
  }

  assert {
    condition     = aws_cloudwatch_log_destination.cw_logs_destination.name == "d"
    error_message = "Destination name should pass through even for minimal input"
  }
}
