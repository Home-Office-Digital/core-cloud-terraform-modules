mock_provider "aws" {}

run "connect_attachment_and_peers_wiring" {
  command = plan

  variables {
    ctn_transit_gateway_attachment_id = "tgw-attach-0aaaaaaaaaaaaaaaa"
    cc_hub_tgw_id                     = "tgw-0bbbbbbbbbbbbbbbb"
    cc_transit_gateway_attachment_id  = "tgw-attach-0cccccccccccccccc"
    cc_destination_cidr_block         = "10.0.0.0/8"
    cc_transit_gateway_route_table_id = "tgw-rtb-0dddddddddddddddd"
    tgw_connect = {
      ctn_bgp_asn  = "65086"
      gateway_cidr = "10.238.159.0/24"
      gre_cidr     = "169.254.140.0/28"
      outside_ctn = [
        "10.238.0.34",
        "10.238.0.94"
      ]
    }
  }

  assert {
    condition     = aws_ec2_transit_gateway_connect.connect.transport_attachment_id == "tgw-attach-0aaaaaaaaaaaaaaaa"
    error_message = "transport_attachment_id should pass through var.ctn_transit_gateway_attachment_id"
  }

  assert {
    condition     = aws_ec2_transit_gateway_connect.connect.transit_gateway_default_route_table_association == true
    error_message = "default route table association should be enabled"
  }

  # for_each = { a:0, b:1 } always produces exactly two connect peers.
  assert {
    condition     = length(aws_ec2_transit_gateway_connect_peer.w2-tx01) == 2
    error_message = "Should create exactly two connect peers (a and b)"
  }

  assert {
    condition     = aws_ec2_transit_gateway_connect_peer.w2-tx01["a"].peer_address == "10.238.0.34"
    error_message = "peer a should map to the first outside_ctn address"
  }

  assert {
    condition     = aws_ec2_transit_gateway_connect_peer.w2-tx01["b"].peer_address == "10.238.0.94"
    error_message = "peer b should map to the second outside_ctn address"
  }

  # cidrhost(gateway_cidr, index+1): a -> .1, b -> .2
  assert {
    condition     = aws_ec2_transit_gateway_connect_peer.w2-tx01["a"].transit_gateway_address == "10.238.159.1"
    error_message = "peer a transit_gateway_address should be cidrhost(gateway_cidr, 1)"
  }

  assert {
    condition     = aws_ec2_transit_gateway_connect_peer.w2-tx01["b"].transit_gateway_address == "10.238.159.2"
    error_message = "peer b transit_gateway_address should be cidrhost(gateway_cidr, 2)"
  }

  assert {
    condition     = aws_ec2_transit_gateway_connect_peer.w2-tx01["a"].bgp_asn == "65086"
    error_message = "bgp_asn should pass through tgw_connect.ctn_bgp_asn"
  }

  assert {
    condition     = aws_ec2_transit_gateway_route.blackhole-route-table-entry.destination_cidr_block == "10.0.0.0/8"
    error_message = "route destination_cidr_block should pass through var.cc_destination_cidr_block"
  }

  assert {
    condition     = aws_ec2_transit_gateway_route.blackhole-route-table-entry.transit_gateway_route_table_id == "tgw-rtb-0dddddddddddddddd"
    error_message = "route table id should pass through var.cc_transit_gateway_route_table_id"
  }
}

# inside_cidr_blocks: cidrsubnet(gre_cidr /28, 1, index) -> /29 halves.
run "connect_peer_inside_cidr_blocks" {
  command = plan

  variables {
    ctn_transit_gateway_attachment_id = "tgw-attach-0aaaaaaaaaaaaaaaa"
    cc_hub_tgw_id                     = "tgw-0bbbbbbbbbbbbbbbb"
    cc_transit_gateway_attachment_id  = "tgw-attach-0cccccccccccccccc"
    cc_destination_cidr_block         = "10.1.0.0/16"
    cc_transit_gateway_route_table_id = "tgw-rtb-0dddddddddddddddd"
    tgw_connect = {
      ctn_bgp_asn  = "65099"
      gateway_cidr = "10.238.159.0/24"
      gre_cidr     = "169.254.140.0/28"
      outside_ctn  = ["10.238.0.34", "10.238.0.94"]
    }
  }

  assert {
    condition     = contains(aws_ec2_transit_gateway_connect_peer.w2-tx01["a"].inside_cidr_blocks, "169.254.140.0/29")
    error_message = "peer a inside_cidr_blocks should be the first /29 half of gre_cidr"
  }

  assert {
    condition     = contains(aws_ec2_transit_gateway_connect_peer.w2-tx01["b"].inside_cidr_blocks, "169.254.140.8/29")
    error_message = "peer b inside_cidr_blocks should be the second /29 half of gre_cidr"
  }

  assert {
    condition     = aws_ec2_transit_gateway_connect_peer.w2-tx01["a"].bgp_asn == "65099"
    error_message = "bgp_asn should reflect the overridden tgw_connect.ctn_bgp_asn"
  }
}
