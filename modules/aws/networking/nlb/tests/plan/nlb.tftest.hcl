mock_provider "aws" {}

run "creates_nlb_with_tls_listener_and_target_group" {
  command = plan

  variables {
    name                             = "core-cloud-nlb"
    prefix                           = "cc-nlb"
    vpc_id                           = "vpc-0123456789abcdef0"
    subnets                          = ["subnet-aaa", "subnet-bbb"]
    certificate_arn                  = "arn:aws:acm:eu-west-2:111111111111:certificate/abc"
    target_type                      = "instance"
    tg_port                          = "80"
    tg_protocol                      = "TCP"
    access_logs_bucket               = "cc-nlb-logs"
    access_logs_enabled              = "true"
    load_balancer_type               = "network"
    load_balancer_internal           = "true"
    enable_deletion_protection       = "false"
    enable_cross_zone_load_balancing = "true"
    enable_http2                     = "false"
    instance_targets = {
      "i-0123456789abcdef0" = "eu-west-2a"
      "i-0123456789abcdef1" = "eu-west-2b"
    }
    ingress_rules = [
      {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "tcp in"
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
    condition     = aws_lb.lb.name == "core-cloud-nlb"
    error_message = "LB name should equal var.name"
  }

  assert {
    condition     = aws_lb.lb.load_balancer_type == "network"
    error_message = "load_balancer_type should be network"
  }

  assert {
    condition     = aws_lb_target_group.lb_target_group.name == "cc-nlb-tg"
    error_message = "target group name should be composed as <prefix>-tg"
  }

  assert {
    condition     = aws_lb_listener.https.protocol == "TLS"
    error_message = "NLB listener protocol must be TLS"
  }

  assert {
    condition     = aws_lb_listener.https.port == 443
    error_message = "NLB listener must be on port 443"
  }
}

# target_type == "instance" -> attachment for_each over instance_targets.
run "instance_targets_create_attachments" {
  command = plan

  variables {
    name                             = "cc-nlb"
    prefix                           = "cc-nlb"
    vpc_id                           = "vpc-0123456789abcdef0"
    subnets                          = ["subnet-aaa"]
    certificate_arn                  = "arn:aws:acm:eu-west-2:111111111111:certificate/abc"
    target_type                      = "instance"
    tg_port                          = "80"
    tg_protocol                      = "TCP"
    access_logs_bucket               = "cc-nlb-logs"
    access_logs_enabled              = "true"
    load_balancer_type               = "network"
    load_balancer_internal           = "false"
    enable_deletion_protection       = "false"
    enable_cross_zone_load_balancing = "false"
    enable_http2                     = "false"
    instance_targets = {
      "i-0123456789abcdef0" = "eu-west-2a"
      "i-0123456789abcdef1" = "eu-west-2b"
      "i-0123456789abcdef2" = "eu-west-2c"
    }
    ingress_rules = []
    egress_rules  = []
  }

  assert {
    condition     = length(aws_lb_target_group_attachment.instance_target_group_attachment) == 3
    error_message = "Should create one attachment per instance_targets entry when target_type is instance"
  }
}

# target_type != "instance" -> attachment for_each resolves to {} (0 attachments).
run "ip_target_type_creates_no_instance_attachments" {
  command = plan

  variables {
    name                             = "cc-nlb"
    prefix                           = "cc-nlb"
    vpc_id                           = "vpc-0123456789abcdef0"
    subnets                          = ["subnet-aaa"]
    certificate_arn                  = "arn:aws:acm:eu-west-2:111111111111:certificate/abc"
    target_type                      = "ip"
    tg_port                          = "80"
    tg_protocol                      = "TCP"
    access_logs_bucket               = "cc-nlb-logs"
    access_logs_enabled              = "true"
    load_balancer_type               = "network"
    load_balancer_internal           = "false"
    enable_deletion_protection       = "false"
    enable_cross_zone_load_balancing = "false"
    enable_http2                     = "false"
    instance_targets = {
      "i-0123456789abcdef0" = "eu-west-2a"
    }
    ingress_rules = []
    egress_rules  = []
  }

  assert {
    condition     = length(aws_lb_target_group_attachment.instance_target_group_attachment) == 0
    error_message = "No instance attachments should be created when target_type is not instance"
  }
}

# SG dynamic block wiring.
run "security_group_rule_wiring" {
  command = plan

  variables {
    name                             = "cc-nlb"
    prefix                           = "cc-nlb"
    vpc_id                           = "vpc-0123456789abcdef0"
    subnets                          = ["subnet-aaa"]
    certificate_arn                  = "arn:aws:acm:eu-west-2:111111111111:certificate/abc"
    target_type                      = "instance"
    tg_port                          = "80"
    tg_protocol                      = "TCP"
    access_logs_bucket               = "cc-nlb-logs"
    access_logs_enabled              = "true"
    load_balancer_type               = "network"
    load_balancer_internal           = "true"
    enable_deletion_protection       = "false"
    enable_cross_zone_load_balancing = "true"
    enable_http2                     = "false"
    instance_targets                 = {}
    ingress_rules = [
      {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "tcp in"
      },
      {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "tls in"
      },
      {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/16"]
        description = "ssh in"
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
    condition     = aws_security_group.sg.name == "cc-nlb-sg"
    error_message = "SG name should be composed as <name>-sg"
  }

  assert {
    condition     = length(aws_security_group.sg.ingress) == 3
    error_message = "SG should have one ingress block per ingress_rules entry"
  }

  assert {
    condition     = length(aws_security_group.sg.egress) == 1
    error_message = "SG should have one egress block per egress_rules entry"
  }
}
