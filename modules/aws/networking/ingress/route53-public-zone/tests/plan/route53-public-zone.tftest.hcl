# Plan-level tests for the ingress/route53-public-zone module.
# No AWS credentials required — the aws provider is mocked.

mock_provider "aws" {}

# No zone_id supplied -> module creates its own zone and the effective
# zone id resolves to the created zone (unknown at plan, but the zone
# resource must be planned).
run "creates_zone_when_no_id" {
  command = plan

  variables {
    tags        = {}
    environment = "non-prod"
    tenant      = "acme"
    domain_name = "example.gov.uk"
    zone_id     = ""
    acm_records = []
  }

  # count = zone_id == "" ? 1 : 0 -> one zone created.
  assert {
    condition     = length(aws_route53_zone.aws_r53_zone) == 1
    error_message = "A zone should be created when zone_id is empty."
  }

  assert {
    condition     = aws_route53_zone.aws_r53_zone[0].name == "example.gov.uk"
    error_message = "Created zone name should equal domain_name."
  }

  # count = zone_id == "" -> the 30s wait is also created.
  assert {
    condition     = length(time_sleep.wait_30_seconds) == 1
    error_message = "The zone-creation wait should be planned when creating a zone."
  }

  # alb_dns_ready defaults false -> no alias record.
  assert {
    condition     = length(aws_route53_record.external_alb) == 0
    error_message = "ALB alias record should not be created when alb_dns_ready is false."
  }

  # No acm_records -> no validation records.
  assert {
    condition     = length(aws_route53_record.acm_validation) == 0
    error_message = "No ACM validation records should be planned for an empty list."
  }
}

# zone_id supplied -> no zone/wait created, alias record enabled.
run "uses_existing_zone_and_alias" {
  command = plan

  variables {
    tags               = {}
    environment        = "prod"
    tenant             = "beta"
    domain_name        = "beta.example.gov.uk"
    zone_id            = "Z0123456789ABCDEFGHIJ"
    alb_dns_ready      = true
    external_alb_dns   = "beta-external.eu-west-2.elb.amazonaws.com"
    alb_hosted_zone_id = "ZHURV8PSTC4K8"
    acm_records = [
      { name = "_a1.beta.example.gov.uk", type = "CNAME", value = "_v1.acm-validations.aws." },
      { name = "_a2.beta.example.gov.uk", type = "CNAME", value = "_v2.acm-validations.aws." },
    ]
  }

  assert {
    condition     = length(aws_route53_zone.aws_r53_zone) == 0
    error_message = "No zone should be created when zone_id is supplied."
  }

  assert {
    condition     = length(time_sleep.wait_30_seconds) == 0
    error_message = "No zone-creation wait when an existing zone is used."
  }

  # alb_dns_ready true -> one alias record with wildcard name.
  assert {
    condition     = length(aws_route53_record.external_alb) == 1
    error_message = "One ALB alias record should be planned when alb_dns_ready is true."
  }

  assert {
    condition     = aws_route53_record.external_alb[0].name == "*.beta.example.gov.uk"
    error_message = "ALB alias record should target the wildcard of domain_name."
  }

  # for_each over acm_records keyed by name -> two records.
  assert {
    condition     = length(aws_route53_record.acm_validation) == 2
    error_message = "One ACM validation record should be planned per acm_records entry."
  }
}
