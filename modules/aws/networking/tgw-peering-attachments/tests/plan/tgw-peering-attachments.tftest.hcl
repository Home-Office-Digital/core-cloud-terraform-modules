# Plan-level tests for the tgw-peering-attachments module.
# Uses a mock AWS provider so no real credentials or network calls are made.

mock_provider "aws" {}

# Two accounts -> two peering attachments; verify count, passthrough and the
# output projection keys/values.
run "two_accounts_creates_two_attachments" {
  command = plan

  variables {
    central_hub_tgw_id = "tgw-0centralhub00000000"
    region             = "eu-west-2"
    accounts = {
      prod = {
        account_id = "111111111111"
        hub_tgw_id = "tgw-0prodhub0000000000"
        tags       = { Environment = "prod" }
      }
      notprod = {
        account_id = "222222222222"
        hub_tgw_id = "tgw-0notprodhub000000"
        tags       = { Environment = "notprod" }
      }
    }
  }

  assert {
    condition     = length(aws_ec2_transit_gateway_peering_attachment.tgw_peering) == 2
    error_message = "Expected one peering attachment per account (2)."
  }

  assert {
    condition     = aws_ec2_transit_gateway_peering_attachment.tgw_peering["prod"].transit_gateway_id == "tgw-0centralhub00000000"
    error_message = "Each attachment should use the central hub TGW id as transit_gateway_id."
  }

  assert {
    condition     = aws_ec2_transit_gateway_peering_attachment.tgw_peering["prod"].peer_transit_gateway_id == "tgw-0prodhub0000000000"
    error_message = "peer_transit_gateway_id should come from each account's hub_tgw_id."
  }

  assert {
    condition     = aws_ec2_transit_gateway_peering_attachment.tgw_peering["notprod"].peer_account_id == "222222222222"
    error_message = "peer_account_id should come from each account's account_id."
  }

  assert {
    condition     = aws_ec2_transit_gateway_peering_attachment.tgw_peering["prod"].peer_region == "eu-west-2"
    error_message = "peer_region should equal the region variable."
  }

  assert {
    condition     = length(keys(output.tgw_peering_attachment_ids)) == 2
    error_message = "Output map should have one entry per account."
  }

  assert {
    condition     = contains(keys(output.tgw_peering_attachment_ids), "prod") && contains(keys(output.tgw_peering_attachment_ids), "notprod")
    error_message = "Output map keys should mirror the account map keys."
  }
}

# Region default is applied when omitted.
run "region_default_applied" {
  command = plan

  variables {
    central_hub_tgw_id = "tgw-0centralhub00000000"
    accounts = {
      central = {
        account_id = "333333333333"
        hub_tgw_id = "tgw-0centralaccount00"
        tags       = {}
      }
    }
  }

  assert {
    condition     = aws_ec2_transit_gateway_peering_attachment.tgw_peering["central"].peer_region == "eu-west-2"
    error_message = "region should default to eu-west-2 when not supplied."
  }
}

# Empty accounts map -> zero attachments, empty output.
run "empty_accounts_creates_nothing" {
  command = plan

  variables {
    central_hub_tgw_id = "tgw-0centralhub00000000"
    accounts           = {}
  }

  assert {
    condition     = length(aws_ec2_transit_gateway_peering_attachment.tgw_peering) == 0
    error_message = "No attachments should be created for an empty accounts map."
  }

  assert {
    condition     = length(keys(output.tgw_peering_attachment_ids)) == 0
    error_message = "Output map should be empty for an empty accounts map."
  }
}
