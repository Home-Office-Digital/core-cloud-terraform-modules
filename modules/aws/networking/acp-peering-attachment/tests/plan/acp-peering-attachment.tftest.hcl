mock_provider "aws" {}

run "peering_attachment_variable_passthrough" {
  command = plan

  variables {
    acp_account_id = "222222222222"
    acp_region     = "eu-west-1"
    acp_tgw_id     = "tgw-0aaaaaaaaaaaaaaaa"
    cc_hub_tgw_id  = "tgw-0bbbbbbbbbbbbbbbb"
  }

  assert {
    condition     = aws_ec2_transit_gateway_peering_attachment.peering.peer_account_id == "222222222222"
    error_message = "peer_account_id should pass through var.acp_account_id"
  }

  assert {
    condition     = aws_ec2_transit_gateway_peering_attachment.peering.peer_region == "eu-west-1"
    error_message = "peer_region should pass through var.acp_region"
  }

  assert {
    condition     = aws_ec2_transit_gateway_peering_attachment.peering.peer_transit_gateway_id == "tgw-0aaaaaaaaaaaaaaaa"
    error_message = "peer_transit_gateway_id should pass through var.acp_tgw_id"
  }

  assert {
    condition     = aws_ec2_transit_gateway_peering_attachment.peering.transit_gateway_id == "tgw-0bbbbbbbbbbbbbbbb"
    error_message = "transit_gateway_id should pass through var.cc_hub_tgw_id"
  }
}

# acp_region omitted -> exercises its eu-west-2 default (account/tgw ids must be
# supplied since the module's empty-string defaults fail provider ID validation).
run "peering_attachment_region_default" {
  command = plan

  variables {
    acp_account_id = "222222222222"
    acp_tgw_id     = "tgw-0aaaaaaaaaaaaaaaa"
    cc_hub_tgw_id  = "tgw-0bbbbbbbbbbbbbbbb"
  }

  assert {
    condition     = aws_ec2_transit_gateway_peering_attachment.peering.peer_region == "eu-west-2"
    error_message = "peer_region should default to eu-west-2 when not set"
  }
}
