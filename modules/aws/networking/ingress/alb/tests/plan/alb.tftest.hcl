# Plan-level tests for the ingress/alb module.
# No AWS credentials required — the aws provider is mocked. Computed data
# sources are given deterministic defaults so plan can resolve references.

mock_provider "aws" {
  # VPC lookup by Name tag.
  mock_data "aws_vpcs" {
    defaults = {
      ids = ["vpc-0123456789abcdef0"]
    }
  }

  # Subnet lookup filtered by Name tag + vpc-id.
  mock_data "aws_subnets" {
    defaults = {
      ids = ["subnet-aaa111", "subnet-bbb222", "subnet-ccc333"]
    }
  }

  # Regional ALB hosted zone id.
  mock_data "aws_lb_hosted_zone_id" {
    defaults = {
      id = "ZHURV8PSTC4K8"
    }
  }
}

run "alb_naming_and_wiring" {
  command = plan

  variables {
    workload_external_nlb_ips = "[\"1.2.3.4\", \"5.6.7.8\"]"
    tags                      = { Team = "core-cloud-access-and-identity" }
    domain_name               = "example.gov.uk"
    environment               = "non-prod"
    tenant                    = "acme"
    account_id                = "111122223333"
    public_subnet_filter      = "cc-ingress-notprod-public*"
    vpc_name                  = "cc-ingress-notprod"
    acm_certificate_arn       = "arn:aws:acm:eu-west-2:111122223333:certificate/abc-123"
  }

  # ALB name is composed from tenant + account_id.
  assert {
    condition     = aws_lb.tenant_alb.name == "acme-external-111122223333"
    error_message = "ALB name should be <tenant>-external-<account_id>."
  }

  # Internet-facing.
  assert {
    condition     = aws_lb.tenant_alb.internal == false
    error_message = "ALB should be internet-facing."
  }

  assert {
    condition     = aws_lb.tenant_alb.load_balancer_type == "application"
    error_message = "Load balancer type should be application."
  }

  assert {
    condition     = aws_lb.tenant_alb.drop_invalid_header_fields == true
    error_message = "ALB should drop invalid header fields."
  }

  # Target group naming + protocol.
  assert {
    condition     = aws_lb_target_group.tenant_target_group.name == "acme-external-111122223333-tg"
    error_message = "Target group name should carry the -tg suffix."
  }

  assert {
    condition     = aws_lb_target_group.tenant_target_group.target_type == "ip"
    error_message = "Target group should use ip target type."
  }

  # SG name_prefix composition.
  assert {
    condition     = aws_security_group.alb_sg.name_prefix == "acme-external-111122223333-"
    error_message = "SG name_prefix should be <tenant>-external-<account_id>-."
  }

  # HTTPS listener wires the passed ACM cert + TLS13 policy.
  assert {
    condition     = aws_lb_listener.https_listener.certificate_arn == "arn:aws:acm:eu-west-2:111122223333:certificate/abc-123"
    error_message = "Listener should use the supplied ACM certificate ARN."
  }

  assert {
    condition     = aws_lb_listener.https_listener.ssl_policy == "ELBSecurityPolicy-TLS13-1-2-2021-06"
    error_message = "Listener should use the TLS 1.3 security policy."
  }
}

# for_each over the decoded NLB IP list -> one attachment per IP.
run "target_group_attachments_per_ip" {
  command = plan

  variables {
    # module jsondecode()s this string.
    workload_external_nlb_ips = "[\"10.0.0.1\", \"10.0.0.2\", \"10.0.0.3\"]"
    tags                      = {}
    domain_name               = "example.gov.uk"
    environment               = "prod"
    tenant                    = "beta"
    account_id                = "444455556666"
    vpc_name                  = "cc-ingress-prod"
    acm_certificate_arn       = "arn:aws:acm:eu-west-2:444455556666:certificate/def-456"
  }

  assert {
    condition     = length(aws_lb_target_group_attachment.tg_attachment) == 3
    error_message = "One target group attachment should be planned per decoded NLB IP."
  }
}
