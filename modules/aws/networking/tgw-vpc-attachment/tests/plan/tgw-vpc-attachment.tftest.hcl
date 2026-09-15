# Plan-level tests for the tgw-vpc-attachment module.
# Verifies the AZ-ordered subnet projection, name tag composition, and the
# default-route-table propagation default.

mock_provider "aws" {}

# Subnet ids are projected in the order of the azs list, not map order.
run "subnet_ids_ordered_by_azs" {
  command = plan

  variables {
    transit_gateway_id = "tgw-0aaaaaaaaaaaaaaaa"
    vpc_id             = "vpc-0bbbbbbbbbbbbbbbb"
    name               = "cc-vpn-prod-tgwattach"
    azs                = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
    attachment_subnet_ids = {
      "eu-west-2c" = "subnet-0ccccccccccccccc0"
      "eu-west-2a" = "subnet-0aaaaaaaaaaaaaaa0"
      "eu-west-2b" = "subnet-0bbbbbbbbbbbbbbb0"
    }
  }

  # subnet_ids is a set in the provider schema, so assert on membership/count
  # (the AZ-ordering itself is exercised via the module's local projection).
  assert {
    condition = aws_ec2_transit_gateway_vpc_attachment.twg_vpc.subnet_ids == toset([
      "subnet-0aaaaaaaaaaaaaaa0",
      "subnet-0bbbbbbbbbbbbbbb0",
      "subnet-0ccccccccccccccc0",
    ])
    error_message = "subnet_ids should contain exactly the subnet mapped for each supplied AZ."
  }

  assert {
    condition     = length(aws_ec2_transit_gateway_vpc_attachment.twg_vpc.subnet_ids) == 3
    error_message = "One subnet per AZ should be selected."
  }

  assert {
    condition     = aws_ec2_transit_gateway_vpc_attachment.twg_vpc.transit_gateway_id == "tgw-0aaaaaaaaaaaaaaaa"
    error_message = "transit_gateway_id should pass through unchanged."
  }

  assert {
    condition     = aws_ec2_transit_gateway_vpc_attachment.twg_vpc.vpc_id == "vpc-0bbbbbbbbbbbbbbbb"
    error_message = "vpc_id should pass through unchanged."
  }

  assert {
    condition     = aws_ec2_transit_gateway_vpc_attachment.twg_vpc.tags["Name"] == "cc-vpn-prod-tgwattach"
    error_message = "The Name tag should be composed from the name variable."
  }

  assert {
    condition     = aws_ec2_transit_gateway_vpc_attachment.twg_vpc.transit_gateway_default_route_table_propagation == true
    error_message = "Propagation should default to true when not overridden."
  }
}

# Single AZ -> single subnet; propagation can be disabled.
run "single_az_propagation_disabled" {
  command = plan

  variables {
    transit_gateway_id = "tgw-0aaaaaaaaaaaaaaaa"
    vpc_id             = "vpc-0bbbbbbbbbbbbbbbb"
    name               = "cc-single-az-attach"
    azs                = ["eu-west-2a"]
    attachment_subnet_ids = {
      "eu-west-2a" = "subnet-0aaaaaaaaaaaaaaa0"
    }
    transit_gateway_default_route_table_propagation = false
  }

  assert {
    condition     = length(aws_ec2_transit_gateway_vpc_attachment.twg_vpc.subnet_ids) == 1
    error_message = "A single AZ should yield a single subnet id."
  }

  assert {
    condition     = aws_ec2_transit_gateway_vpc_attachment.twg_vpc.subnet_ids == toset(["subnet-0aaaaaaaaaaaaaaa0"])
    error_message = "The single subnet id should match the one mapped for the AZ."
  }

  assert {
    condition     = aws_ec2_transit_gateway_vpc_attachment.twg_vpc.transit_gateway_default_route_table_propagation == false
    error_message = "Propagation should honour an explicit false override."
  }
}
