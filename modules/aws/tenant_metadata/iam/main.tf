
resource "aws_iam_role" "api_gateway_role" {
  name = "api-gateway-dynamodb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "api_gateway_dynamodb_policy" {
  name        = "api-gateway-dynamodb-policy"
  description = "Allows API Gateway to write to DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:Query", "dynamodb:PutItem"]
      Resource = [
        "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_table_name}",
        "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_table_name}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_api_gateway_policy" {
  policy_arn = aws_iam_policy.api_gateway_dynamodb_policy.arn
  role       = aws_iam_role.api_gateway_role.name
}

data "aws_caller_identity" "current" {}



resource "aws_iam_policy" "api_gateway_cloudwatch_policy" {
  name        = "api-gateway-cloudwatch-policy"
  description = "Allows API Gateway to write logs to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_api_gateway_cloudwatch_policy" {
  policy_arn = aws_iam_policy.api_gateway_cloudwatch_policy.arn
  role       = aws_iam_role.api_gateway_role.name
}

# TO BE DONE MANUALLY - ONCE - AS THIS WONT WORK

# resource "null_resource" "set_apigateway_account" {
#   provisioner "local-exec" {
#     command = <<EOT
#       aws apigateway update-account \
#       --patch-operations op="replace",path="/cloudwatchRoleArn",value="${aws_iam_role.api_gateway_role.arn}"
#     EOT
#   }

#   depends_on = [aws_iam_role_policy_attachment.attach_api_gateway_cloudwatch_policy]
# }

