# Plan-level tests for the event_bridge/event_bridge_rule module.
# Exercises the two count-gated toggles (create_event_bus, source_account_id),
# the event_pattern jsonencode composition, and output projections.
# aws_iam_policy_document is mocked to a valid JSON string.

mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

# Base case: no custom bus, no cross-account source -> both count-gated
# resources are absent, but the rule/target/role are always created.
run "minimal_no_bus_no_source" {
  command = plan

  variables {
    create_event_bus       = false
    event_rule_name        = "my-rule"
    event_rule_description = "test rule"
    event_bus_name         = "default"
    event_sources          = ["aws.ec2"]
    target_arn             = "arn:aws:lambda:eu-west-2:111122223333:function:handler"
    role_name              = "eventbridge-role"
    role_actions           = ["lambda:InvokeFunction"]
  }

  assert {
    condition     = length(aws_cloudwatch_event_bus.custom_event_bus) == 0
    error_message = "No custom event bus should be created when create_event_bus is false"
  }

  assert {
    condition     = length(aws_cloudwatch_event_bus_policy.this) == 0
    error_message = "No bus policy when source_account_id is empty (the default)"
  }

  assert {
    condition     = length(data.aws_iam_policy_document.this) == 0
    error_message = "No policy document when source_account_id is empty"
  }

  # The event pattern is a JSON object with a source list matching the input.
  assert {
    condition     = jsondecode(aws_cloudwatch_event_rule.event_rule.event_pattern).source[0] == "aws.ec2"
    error_message = "Event pattern source should be built from event_sources"
  }

  # Rule name/description passthrough.
  assert {
    condition     = aws_cloudwatch_event_rule.event_rule.name == "my-rule"
    error_message = "Event rule name should pass through"
  }

  assert {
    condition     = aws_iam_role.eventbridge_role.name == "eventbridge-role"
    error_message = "IAM role name should pass through"
  }
}

# Cross-account case: creating the bus and supplying a source account id
# should turn on the bus policy and its policy document.
run "custom_bus_with_cross_account_source" {
  command = plan

  variables {
    create_event_bus       = true
    event_rule_name        = "xacct-rule"
    event_rule_description = "cross account rule"
    event_bus_name         = "custom-bus"
    event_sources          = ["aws.s3", "aws.ec2"]
    target_arn             = "arn:aws:lambda:eu-west-2:111122223333:function:handler"
    role_name              = "eventbridge-role"
    role_actions           = ["lambda:InvokeFunction"]
    source_account_id      = "444455556666"
  }

  assert {
    condition     = length(aws_cloudwatch_event_bus.custom_event_bus) == 1
    error_message = "Custom event bus should be created when create_event_bus is true"
  }

  assert {
    condition     = length(aws_cloudwatch_event_bus_policy.this) == 1
    error_message = "Bus policy should be created when a source_account_id is supplied"
  }

  assert {
    condition     = length(data.aws_iam_policy_document.this) == 1
    error_message = "Policy document should be created when a source_account_id is supplied"
  }

  assert {
    condition     = aws_cloudwatch_event_bus.custom_event_bus[0].name == "custom-bus"
    error_message = "Custom event bus name should pass through"
  }

  # Multiple event sources are preserved in the pattern.
  assert {
    condition     = length(jsondecode(aws_cloudwatch_event_rule.event_rule.event_pattern).source) == 2
    error_message = "Event pattern should carry all supplied event sources"
  }

  # The event_bus_arn output selects custom_event_bus[0].arn when the bus
  # exists; the arn itself is computed (unknown at plan), so assert the
  # plan-known condition that drives the output projection instead.
  assert {
    condition     = length(aws_cloudwatch_event_bus.custom_event_bus) > 0
    error_message = "Custom bus must exist for event_bus_arn output to be projected non-null"
  }
}
