mock_provider "aws" {}

# Base variables reused across runs (overridden inline per run as needed).
run "creates_alb_with_https_listener_and_target_group" {
  command = plan

  variables {
    name                             = "core-cloud-alb"
    prefix                           = "cc-alb"
    vpc_id                           = "vpc-0123456789abcdef0"
    subnets                          = ["subnet-aaa", "subnet-bbb"]
    certificate_arn                  = "arn:aws:acm:eu-west-2:111111111111:certificate/abc"
    target_type                      = "ip"
    tg_port                          = "443"
    tg_protocol                      = "HTTPS"
    access_logs_bucket               = "cc-alb-logs"
    access_logs_bucket_prefix        = "alb"
    access_logs_enabled              = "true"
    load_balancer_type               = "application"
    load_balancer_internal           = "true"
    enable_deletion_protection       = "false"
    enable_cross_zone_load_balancing = "true"
    enable_http2                     = "true"
    nlb_ips = {
      "10.0.1.10" = "eu-west-2a"
      "10.0.2.10" = "eu-west-2b"
    }
    ingress_rules = [
      {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "https in"
      }
    ]
    egress_rules = [
      {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        description = "all out"
      }
    ]
  }

  assert {
    condition     = aws_lb.lb.name == "core-cloud-alb"
    error_message = "LB name should equal var.name"
  }

  assert {
    condition     = aws_lb.lb.load_balancer_type == "application"
    error_message = "load_balancer_type should be application"
  }

  assert {
    condition     = aws_lb_target_group.lb_target_group.name == "cc-alb-tg"
    error_message = "target group name should be composed as <prefix>-tg"
  }

  assert {
    condition     = aws_lb_listener.https.port == 443
    error_message = "HTTPS listener must be on port 443"
  }

  assert {
    condition     = aws_lb_listener.https.protocol == "HTTPS"
    error_message = "ALB listener protocol must be HTTPS"
  }

  assert {
    condition     = aws_lb.lb.tags["Name"] == "core-cloud-alb"
    error_message = "Name tag should equal var.name"
  }
}

# target_type == "ip" -> attachment for_each over nlb_ips (2 entries).
run "ip_targets_create_two_attachments" {
  command = plan

  variables {
    name                             = "cc-alb"
    prefix                           = "cc-alb"
    vpc_id                           = "vpc-0123456789abcdef0"
    subnets                          = ["subnet-aaa"]
    certificate_arn                  = "arn:aws:acm:eu-west-2:111111111111:certificate/abc"
    target_type                      = "ip"
    tg_port                          = "443"
    tg_protocol                      = "HTTPS"
    access_logs_bucket               = "cc-alb-logs"
    access_logs_enabled              = "true"
    load_balancer_type               = "application"
    load_balancer_internal           = "false"
    enable_deletion_protection       = "false"
    enable_cross_zone_load_balancing = "false"
    enable_http2                     = "true"
    nlb_ips = {
      "10.0.1.10" = "eu-west-2a"
      "10.0.2.10" = "eu-west-2b"
      "10.0.3.10" = "eu-west-2c"
    }
    ingress_rules = []
    egress_rules  = []
  }

  assert {
    condition     = length(aws_lb_target_group_attachment.lb_target_group_attachment) == 3
    error_message = "Should create one attachment per nlb_ips entry when target_type is ip"
  }
}

# target_type != "ip" -> attachment for_each resolves to {} (0 attachments).
run "instance_target_type_creates_no_ip_attachments" {
  command = plan

  variables {
    name                             = "cc-alb"
    prefix                           = "cc-alb"
    vpc_id                           = "vpc-0123456789abcdef0"
    subnets                          = ["subnet-aaa"]
    certificate_arn                  = "arn:aws:acm:eu-west-2:111111111111:certificate/abc"
    target_type                      = "instance"
    tg_port                          = "443"
    tg_protocol                      = "HTTPS"
    access_logs_bucket               = "cc-alb-logs"
    access_logs_enabled              = "true"
    load_balancer_type               = "application"
    load_balancer_internal           = "false"
    enable_deletion_protection       = "false"
    enable_cross_zone_load_balancing = "false"
    enable_http2                     = "true"
    nlb_ips = {
      "10.0.1.10" = "eu-west-2a"
    }
    ingress_rules = []
    egress_rules  = []
  }

  assert {
    condition     = length(aws_lb_target_group_attachment.lb_target_group_attachment) == 0
    error_message = "No IP attachments should be created when target_type is not ip"
  }
}

# SG dynamic block wiring: rule counts and passthrough.
run "security_group_rule_wiring" {
  command = plan

  variables {
    name                             = "cc-alb"
    prefix                           = "cc-alb"
    vpc_id                           = "vpc-0123456789abcdef0"
    subnets                          = ["subnet-aaa"]
    certificate_arn                  = "arn:aws:acm:eu-west-2:111111111111:certificate/abc"
    target_type                      = "ip"
    tg_port                          = "443"
    tg_protocol                      = "HTTPS"
    access_logs_bucket               = "cc-alb-logs"
    access_logs_enabled              = "true"
    load_balancer_type               = "application"
    load_balancer_internal           = "true"
    enable_deletion_protection       = "false"
    enable_cross_zone_load_balancing = "true"
    enable_http2                     = "true"
    nlb_ips                          = {}
    ingress_rules = [
      {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "https in"
      },
      {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "http in"
      }
    ]
    egress_rules = [
      {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        description = "all out"
      }
    ]
  }

  assert {
    condition     = aws_security_group.sg.name == "cc-alb-sg"
    error_message = "SG name should be composed as <name>-sg"
  }

  assert {
    condition     = length(aws_security_group.sg.ingress) == 2
    error_message = "SG should have one ingress block per ingress_rules entry"
  }

  assert {
    condition     = length(aws_security_group.sg.egress) == 1
    error_message = "SG should have one egress block per egress_rules entry"
  }

  assert {
    condition     = aws_security_group.sg.vpc_id == "vpc-0123456789abcdef0"
    error_message = "SG vpc_id should pass through var.vpc_id"
  }
}
