mock_provider "aws" {}

run "creates_vpc_domain_eip_with_tags" {
  command = plan

  variables {
    tags = {
      Name        = "cc-eip"
      Environment = "prod"
    }
  }

  assert {
    condition     = aws_eip.this.domain == "vpc"
    error_message = "EIP domain must be vpc"
  }

  assert {
    condition     = aws_eip.this.tags["Name"] == "cc-eip"
    error_message = "Name tag should pass through var.tags"
  }

  assert {
    condition     = length(aws_eip.this.tags) == 2
    error_message = "All provided tags should be applied to the EIP"
  }
}

# Edge case: default (empty) tags map.
run "defaults_to_empty_tags" {
  command = plan

  variables {}

  assert {
    condition     = length(aws_eip.this.tags) == 0
    error_message = "tags should default to an empty map"
  }

  assert {
    condition     = aws_eip.this.domain == "vpc"
    error_message = "EIP domain must be vpc even with default tags"
  }
}
