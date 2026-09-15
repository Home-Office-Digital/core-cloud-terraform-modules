# Plan-level tests for the ingress/private-subnets module.
# No AWS credentials required — the aws provider is mocked. The VPC lookups
# are given deterministic defaults so cidrsubnet() can resolve at plan time.

mock_provider "aws" {
  mock_data "aws_vpcs" {
    defaults = {
      ids = ["vpc-0123456789abcdef0"]
    }
  }

  mock_data "aws_vpc" {
    defaults = {
      id         = "vpc-0123456789abcdef0"
      cidr_block = "10.20.0.0/24"
    }
  }
}

run "three_az_subnets" {
  command = plan

  variables {
    vpc_name = "cc-ingress-notprod"
    tags     = { Team = "core-cloud-access-and-identity" }
  }

  # Each subnet pinned to its AZ.
  assert {
    condition     = aws_subnet.subnet_a.availability_zone == "eu-west-2a"
    error_message = "Subnet A should be in eu-west-2a."
  }

  assert {
    condition     = aws_subnet.subnet_b.availability_zone == "eu-west-2b"
    error_message = "Subnet B should be in eu-west-2b."
  }

  assert {
    condition     = aws_subnet.subnet_c.availability_zone == "eu-west-2c"
    error_message = "Subnet C should be in eu-west-2c."
  }

  # cidrsubnet(10.20.0.0/24, 3, n) -> /27 blocks at offsets 5,6,7.
  assert {
    condition     = aws_subnet.subnet_a.cidr_block == "10.20.0.160/27"
    error_message = "Subnet A CIDR should be the 6th /27 in the VPC block."
  }

  assert {
    condition     = aws_subnet.subnet_b.cidr_block == "10.20.0.192/27"
    error_message = "Subnet B CIDR should be the 7th /27 in the VPC block."
  }

  assert {
    condition     = aws_subnet.subnet_c.cidr_block == "10.20.0.224/27"
    error_message = "Subnet C CIDR should be the 8th /27 in the VPC block."
  }

  # Name tag composition + caller tag merge.
  assert {
    condition     = aws_subnet.subnet_a.tags["Name"] == "cc-ingress-notprod-private-main-subnet-a"
    error_message = "Subnet A Name tag should be composed from vpc_name."
  }

  assert {
    condition     = aws_subnet.subnet_c.tags["Team"] == "core-cloud-access-and-identity"
    error_message = "Caller-supplied tags should be merged onto subnets."
  }
}
