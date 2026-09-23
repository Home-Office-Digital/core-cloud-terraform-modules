# Plan-level tests for the ingress/dns-isolated/route53-public-zone module.
# No AWS credentials required — the aws provider is mocked.

mock_provider "aws" {}

# Single wildcard alias record pointing at the supplied NLB.
run "wildcard_alias_to_nlb" {
  command = plan

  variables {
    hosted_zone_id = "Z0123456789ABCDEFGHIJ"
    domain_name    = "isolated.example.gov.uk"
    nlb_name       = "acme-internal.eu-west-2.elb.amazonaws.com"
    nlb_zone       = "ZD4D7Y8KGAS4G"
  }

  assert {
    condition     = aws_route53_record.external_nlb.name == "*.isolated.example.gov.uk"
    error_message = "Record name should be the wildcard of domain_name."
  }

  assert {
    condition     = aws_route53_record.external_nlb.type == "A"
    error_message = "Record type should be A (alias)."
  }

  assert {
    condition     = aws_route53_record.external_nlb.zone_id == "Z0123456789ABCDEFGHIJ"
    error_message = "Record should be placed in the supplied hosted zone."
  }

  # Alias target passthrough.
  assert {
    condition     = one(aws_route53_record.external_nlb.alias).name == "acme-internal.eu-west-2.elb.amazonaws.com"
    error_message = "Alias should target the supplied NLB name."
  }

  assert {
    condition     = one(aws_route53_record.external_nlb.alias).zone_id == "ZD4D7Y8KGAS4G"
    error_message = "Alias should carry the supplied NLB zone id."
  }

  assert {
    condition     = one(aws_route53_record.external_nlb.alias).evaluate_target_health == true
    error_message = "Alias should evaluate target health."
  }
}
