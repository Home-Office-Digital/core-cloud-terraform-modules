# Plan-level tests for the tgw-static-routes module.
# The module reads an existing TGW route table via a data source, so a
# mock_provider with mock_data supplies a deterministic route-table id, and the
# routes themselves come from an inline YAML string decoded by the module.

mock_provider "aws" {
  mock_data "aws_ec2_transit_gateway_route_table" {
    defaults = {
      id = "tgw-rtb-0mockroutetable00"
    }
  }
}

# Three routes in the YAML -> three route resources keyed by cidr_block.
run "three_routes_creates_three" {
  command = plan

  variables {
    tgw_route_table_id   = "tgw-rtb-0mockroutetable00"
    tgw_route_table_name = "cc-core-tgw-rt"
    static_routes_file   = <<-YAML
      routes:
        - cidr_block: "10.0.0.0/16"
          transit_gateway_attachment_id: "tgw-attach-0aaaaaaaaaaaaaaaa"
        - cidr_block: "10.1.0.0/16"
          transit_gateway_attachment_id: "tgw-attach-0bbbbbbbbbbbbbbbb"
        - cidr_block: "172.16.0.0/12"
          transit_gateway_attachment_id: "tgw-attach-0cccccccccccccccc"
    YAML
  }

  assert {
    condition     = length(aws_ec2_transit_gateway_route.tgw_routes) == 3
    error_message = "Expected one route resource per YAML route entry (3)."
  }

  assert {
    condition     = aws_ec2_transit_gateway_route.tgw_routes["10.0.0.0/16"].destination_cidr_block == "10.0.0.0/16"
    error_message = "Route should be keyed by and carry its cidr_block."
  }

  assert {
    condition     = aws_ec2_transit_gateway_route.tgw_routes["10.1.0.0/16"].transit_gateway_attachment_id == "tgw-attach-0bbbbbbbbbbbbbbbb"
    error_message = "Route attachment id should come from the YAML entry."
  }

  assert {
    condition     = aws_ec2_transit_gateway_route.tgw_routes["10.0.0.0/16"].transit_gateway_route_table_id == "tgw-rtb-0mockroutetable00"
    error_message = "All routes should target the resolved route-table id from the data source."
  }
}

# Single-route file -> single resource.
run "single_route" {
  command = plan

  variables {
    tgw_route_table_id   = "tgw-rtb-0mockroutetable00"
    tgw_route_table_name = "cc-core-tgw-rt"
    static_routes_file   = <<-YAML
      routes:
        - cidr_block: "192.168.0.0/24"
          transit_gateway_attachment_id: "tgw-attach-0dddddddddddddddd"
    YAML
  }

  assert {
    condition     = length(aws_ec2_transit_gateway_route.tgw_routes) == 1
    error_message = "Expected exactly one route resource."
  }

  assert {
    condition     = contains(keys(aws_ec2_transit_gateway_route.tgw_routes), "192.168.0.0/24")
    error_message = "The route should be keyed by its cidr_block."
  }
}

# Empty routes list -> no route resources.
run "empty_routes_creates_nothing" {
  command = plan

  variables {
    tgw_route_table_id   = "tgw-rtb-0mockroutetable00"
    tgw_route_table_name = "cc-core-tgw-rt"
    static_routes_file   = <<-YAML
      routes: []
    YAML
  }

  assert {
    condition     = length(aws_ec2_transit_gateway_route.tgw_routes) == 0
    error_message = "No routes should be created for an empty routes list."
  }
}
