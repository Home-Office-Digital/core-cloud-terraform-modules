# Plan-level tests for the tenant_metadata/api_gateway module.
# Uses mock_provider so no AWS credentials or network calls are needed.
# This module has no data sources; all asserted values are static or composed
# from input variables, so they are known at plan time.

mock_provider "aws" {}

run "api_and_methods" {
  command = plan

  variables {
    dynamodb_table_name  = "cc-networking-jira-webhook-payloads"
    attributes_map       = { tenant = "S" }
    api_gateway_role_arn = "arn:aws:iam::123456789012:role/api-gateway-dynamodb-role"
    aws_region           = "eu-west-2"
  }

  assert {
    condition     = aws_api_gateway_rest_api.api.name == "dynamodb-api"
    error_message = "REST API should have the fixed name dynamodb-api"
  }

  assert {
    condition     = aws_api_gateway_resource.proxy.path_part == "{proxy+}"
    error_message = "Proxy resource should use the greedy {proxy+} path part"
  }

  # Two methods defined: POST and GET.
  assert {
    condition     = aws_api_gateway_method.post.http_method == "POST"
    error_message = "POST method should be defined"
  }

  assert {
    condition     = aws_api_gateway_method.get.http_method == "GET"
    error_message = "GET method should be defined"
  }

  assert {
    condition     = aws_api_gateway_method.post.authorization == "NONE"
    error_message = "POST method authorization should be NONE"
  }

  # Integration URIs compose the region into the DynamoDB service action ARN.
  assert {
    condition     = aws_api_gateway_integration.post_dynamodb.uri == "arn:aws:apigateway:eu-west-2:dynamodb:action/PutItem"
    error_message = "POST integration URI should target DynamoDB PutItem in the given region"
  }

  assert {
    condition     = aws_api_gateway_integration.get_dynamodb.uri == "arn:aws:apigateway:eu-west-2:dynamodb:action/Query"
    error_message = "GET integration URI should target DynamoDB Query in the given region"
  }

  # role ARN passes through as integration credentials.
  assert {
    condition     = aws_api_gateway_integration.post_dynamodb.credentials == "arn:aws:iam::123456789012:role/api-gateway-dynamodb-role"
    error_message = "Integration credentials should be the supplied role ARN"
  }

  # GET request template embeds the DynamoDB table name.
  assert {
    condition     = strcontains(aws_api_gateway_integration.get_dynamodb.request_templates["application/json"], "cc-networking-jira-webhook-payloads")
    error_message = "GET request template should reference the supplied table name"
  }

  # Stage + log group wiring.
  assert {
    condition     = aws_api_gateway_stage.prod.stage_name == "prod"
    error_message = "Deployment stage should be named prod"
  }

  assert {
    condition     = aws_cloudwatch_log_group.api_gateway_logs.retention_in_days == 7
    error_message = "Access-log group retention should be 7 days"
  }
}

# Region override flows into both integration URIs.
run "region_override" {
  command = plan

  variables {
    dynamodb_table_name  = "other-table"
    attributes_map       = {}
    api_gateway_role_arn = "arn:aws:iam::123456789012:role/some-role"
    aws_region           = "us-east-1"
  }

  assert {
    condition     = aws_api_gateway_integration.post_dynamodb.uri == "arn:aws:apigateway:us-east-1:dynamodb:action/PutItem"
    error_message = "Region override should flow into the POST integration URI"
  }

  assert {
    condition     = strcontains(aws_api_gateway_integration.get_dynamodb.request_templates["application/json"], "other-table")
    error_message = "Overridden table name should flow into the GET request template"
  }
}
