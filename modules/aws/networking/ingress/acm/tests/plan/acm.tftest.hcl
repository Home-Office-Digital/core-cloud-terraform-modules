# Plan-level tests for the ingress/acm module.
# No AWS credentials required — the aws provider is mocked.

mock_provider "aws" {}

# Base run: non-workload account. No validation records or cert validation
# resource should be planned, and the wildcard cert domain is composed.
run "non_workload_cert_only" {
  command = plan

  variables {
    tags        = { Team = "core-cloud-access-and-identity" }
    domain_name = "example.gov.uk"
    environment = "non-prod"
    tenant      = "acme"
    workload    = false
  }

  assert {
    condition     = aws_acm_certificate.cert.domain_name == "*.example.gov.uk"
    error_message = "Certificate domain should be the wildcard of domain_name."
  }

  assert {
    condition     = aws_acm_certificate.cert.validation_method == "DNS"
    error_message = "Certificate should use DNS validation."
  }

  # for_each guarded by var.workload -> no validation records for non-workload.
  assert {
    condition     = length(aws_route53_record.cert_validation_records) == 0
    error_message = "Non-workload accounts should create no cert validation records."
  }

  # count guarded by workload && acm_validation_enabled -> zero.
  assert {
    condition     = length(aws_acm_certificate_validation.cert_validation) == 0
    error_message = "Cert validation resource should not be created for non-workload."
  }

  # Tags are merged with Environment + Tenant.
  assert {
    condition     = aws_acm_certificate.cert.tags["Environment"] == "non-prod"
    error_message = "Environment tag should be injected."
  }

  assert {
    condition     = aws_acm_certificate.cert.tags["Tenant"] == "acme"
    error_message = "Tenant tag should be injected."
  }

  assert {
    condition     = aws_acm_certificate.cert.tags["Team"] == "core-cloud-access-and-identity"
    error_message = "Caller-supplied tags should be preserved through merge."
  }
}

# Non-workload with a hosted_zone_id present but unused: validation resources
# stay at zero (the for_each over computed domain_validation_options is only
# active for workload accounts) and the wildcard composition still holds.
run "hosted_zone_id_ignored_for_non_workload" {
  command = plan

  variables {
    tags                   = {}
    domain_name            = "workload.example.gov.uk"
    environment            = "prod"
    tenant                 = "beta"
    workload               = false
    hosted_zone_id         = "Z0123456789ABCDEFGHIJ"
    acm_validation_enabled = false
  }

  assert {
    condition     = length(aws_route53_record.cert_validation_records) == 0
    error_message = "No validation records when workload is false."
  }

  # count = workload && acm_validation_enabled -> false here.
  assert {
    condition     = length(aws_acm_certificate_validation.cert_validation) == 0
    error_message = "Validation resource should not exist when acm_validation_enabled is false."
  }

  assert {
    condition     = aws_acm_certificate.cert.domain_name == "*.workload.example.gov.uk"
    error_message = "Wildcard composition should hold for workload domain."
  }
}
