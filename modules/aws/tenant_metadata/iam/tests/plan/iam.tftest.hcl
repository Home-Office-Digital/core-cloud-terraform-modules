# Plan-level tests for the tenant_metadata/iam module.
# Uses mock_provider so no AWS credentials or network calls are needed.
# The module reads data.aws_caller_identity.current, so we give the mock a
# deterministic account_id for the DynamoDB ARN string composition.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

run "role_and_policies" {
  command = plan

  variables {
    aws_region          = "eu-west-2"
    dynamodb_table_name = "cc-networking-jira-webhook-payloads"
  }

  assert {
    condition     = aws_iam_role.api_gateway_role.name == "api-gateway-dynamodb-role"
    error_message = "IAM role name should be the fixed api-gateway-dynamodb-role"
  }

  # assume_role_policy is static (no computed refs), known at plan time.
  assert {
    condition     = strcontains(aws_iam_role.api_gateway_role.assume_role_policy, "apigateway.amazonaws.com")
    error_message = "Assume-role policy should trust the API Gateway service principal"
  }

  assert {
    condition     = aws_iam_policy.api_gateway_dynamodb_policy.name == "api-gateway-dynamodb-policy"
    error_message = "DynamoDB policy should have its fixed name"
  }

  # The DynamoDB policy composes region + mocked account_id + table name into
  # the resource ARN. All three parts are known at plan time.
  assert {
    condition     = strcontains(aws_iam_policy.api_gateway_dynamodb_policy.policy, "arn:aws:dynamodb:eu-west-2:123456789012:table/cc-networking-jira-webhook-payloads")
    error_message = "DynamoDB policy Resource should embed region, account and table name"
  }

  assert {
    condition     = strcontains(aws_iam_policy.api_gateway_dynamodb_policy.policy, "dynamodb:PutItem")
    error_message = "DynamoDB policy should grant PutItem"
  }

  assert {
    condition     = aws_iam_policy.api_gateway_cloudwatch_policy.name == "api-gateway-cloudwatch-policy"
    error_message = "CloudWatch policy should have its fixed name"
  }

  assert {
    condition     = strcontains(aws_iam_policy.api_gateway_cloudwatch_policy.policy, "logs:CreateLogGroup")
    error_message = "CloudWatch policy should grant logs:CreateLogGroup"
  }
}

# Region + table name pass-through into the composed ARN.
run "region_and_table_passthrough" {
  command = plan

  variables {
    aws_region          = "us-east-1"
    dynamodb_table_name = "my-tenant-table"
  }

  assert {
    condition     = strcontains(aws_iam_policy.api_gateway_dynamodb_policy.policy, "arn:aws:dynamodb:us-east-1:123456789012:table/my-tenant-table")
    error_message = "Overridden region and table name should flow into the DynamoDB policy ARN"
  }

  # The wildcard sub-resource ARN (table/.../*) should also be present.
  assert {
    condition     = strcontains(aws_iam_policy.api_gateway_dynamodb_policy.policy, "table/my-tenant-table/*")
    error_message = "DynamoDB policy should include the table index/stream wildcard ARN"
  }
}
