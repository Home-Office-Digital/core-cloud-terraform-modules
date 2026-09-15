# Plan-level tests for the products/static-site module.
# Uses mock_provider so no AWS credentials or network calls are needed.
#
# The module declares a second aws provider aliased "us-east-1" (in
# variables.tf) which the WAF resource uses. We mock both the default and the
# aliased provider. data.aws_caller_identity.current is given a deterministic
# account_id for ARN composition in the KMS key policy.
#
# aws_iam_policy_document data sources render a computed .json; under
# mock_provider that string is not resolved to a stable value at plan time, so
# we assert on the plan-knowable string composition (bucket/role/WAF names,
# CloudFront/KMS/WAF settings, output projections) rather than policy JSON.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

mock_provider "aws" {
  alias = "us-east-1"
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

# Full, representative tenant configuration.
run "full_config" {
  command = plan

  variables {
    aws_region = "eu-west-2"
    tenant_vars = {
      COST_CENTRE                     = "CC-1234"
      product                         = "portal"
      component                       = "web"
      cloudfront_aliases              = ["portal.example.gov.uk"]
      cloudfront_function_rewrite_arn = "arn:aws:cloudfront::123456789012:function/rewrite"
      cloudfront_cert                 = "arn:aws:acm:us-east-1:123456789012:certificate/abc"
      repository                      = "Home-Office-Digital/portal-web"
      github_environment_name         = "production"
    }
    cloud_front_default_vars = {
      cloudfront_price_class = "PriceClass_100"
    }
  }

  # S3 bucket name composes product + component.
  assert {
    condition     = aws_s3_bucket.static_site.bucket == "cc-static-site-portal-web"
    error_message = "S3 bucket name should be cc-static-site-<product>-<component>"
  }

  # Public access fully blocked.
  assert {
    condition     = aws_s3_bucket_public_access_block.static_site_acl.block_public_acls == true
    error_message = "S3 public access block should block public ACLs"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.static_site_acl.restrict_public_buckets == true
    error_message = "S3 public access block should restrict public buckets"
  }

  # Versioning enabled.
  assert {
    condition     = aws_s3_bucket_versioning.static_site_versioning.versioning_configuration[0].status == "Enabled"
    error_message = "S3 versioning should be Enabled"
  }

  # KMS key rotation enabled.
  assert {
    condition     = aws_kms_key.static_site_kms.enable_key_rotation == true
    error_message = "KMS key rotation should be enabled"
  }

  # CloudFront settings.
  assert {
    condition     = aws_cloudfront_distribution.static_site_distribution.enabled == true
    error_message = "CloudFront distribution should be enabled"
  }

  assert {
    condition     = aws_cloudfront_distribution.static_site_distribution.default_root_object == "index.html"
    error_message = "CloudFront default root object should be index.html"
  }

  assert {
    condition     = aws_cloudfront_distribution.static_site_distribution.aliases == toset(["portal.example.gov.uk"])
    error_message = "CloudFront aliases should pass through from tenant_vars"
  }

  assert {
    condition     = aws_cloudfront_distribution.static_site_distribution.viewer_certificate[0].acm_certificate_arn == "arn:aws:acm:us-east-1:123456789012:certificate/abc"
    error_message = "CloudFront viewer certificate should use the supplied ACM ARN"
  }

  assert {
    condition     = aws_cloudfront_distribution.static_site_distribution.price_class == "PriceClass_100"
    error_message = "CloudFront price class should come from cloud_front_default_vars"
  }

  assert {
    condition     = aws_cloudfront_distribution.static_site_distribution.default_cache_behavior[0].viewer_protocol_policy == "redirect-to-https"
    error_message = "CloudFront should redirect viewers to HTTPS"
  }

  # Origin Access Control.
  assert {
    condition     = aws_cloudfront_origin_access_control.static_site_identity.name == "cc-static-site-portal-web"
    error_message = "OAC name should be cc-static-site-<product>-<component>"
  }

  assert {
    condition     = aws_cloudfront_origin_access_control.static_site_identity.signing_behavior == "always"
    error_message = "OAC signing behavior should be always"
  }

  # WAF web ACL (CLOUDFRONT scope, us-east-1 aliased provider).
  assert {
    condition     = aws_wafv2_web_acl.default.name == "cc-static-site-portal-web"
    error_message = "WAF web ACL name should be cc-static-site-<product>-<component>"
  }

  assert {
    condition     = aws_wafv2_web_acl.default.scope == "CLOUDFRONT"
    error_message = "WAF web ACL scope should be CLOUDFRONT"
  }

  # IAM GitHub Actions push role name.
  assert {
    condition     = aws_iam_role.static_site_actions_push.name == "cc-static-site-portal-web"
    error_message = "GitHub Actions push role name should be cc-static-site-<product>-<component>"
  }

  # Assume-role policy embeds the mocked account id and the repo/environment sub claim.
  assert {
    condition     = strcontains(aws_iam_role.static_site_actions_push.assume_role_policy, "repo:Home-Office-Digital/portal-web:environment:production")
    error_message = "Push-role trust policy should scope the OIDC sub to the repo and environment"
  }

  assert {
    condition     = strcontains(aws_iam_role.static_site_actions_push.assume_role_policy, "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com")
    error_message = "Push-role trust policy should reference the GitHub OIDC provider for the mocked account"
  }

  # Common tags projected onto tagged resources.
  assert {
    condition     = aws_s3_bucket.static_site.tags["PRODUCT"] == "portal"
    error_message = "common_tags PRODUCT should project from tenant_vars.product"
  }

  assert {
    condition     = aws_s3_bucket.static_site.tags["COST_CENTRE"] == "CC-1234"
    error_message = "common_tags COST_CENTRE should project from tenant_vars.COST_CENTRE"
  }

  # Static named IAM policy.
  assert {
    condition     = aws_iam_policy.static_site_policy.name == "static-site-iam-policy"
    error_message = "Deploy IAM policy should have its fixed name"
  }
}

# Different tenant values flow through into composed names and aliases.
run "alternate_tenant" {
  command = plan

  variables {
    aws_region = "eu-west-2"
    tenant_vars = {
      COST_CENTRE                     = "CC-9999"
      product                         = "docs"
      component                       = "site"
      cloudfront_aliases              = ["docs.example.gov.uk", "www.docs.example.gov.uk"]
      cloudfront_function_rewrite_arn = "arn:aws:cloudfront::123456789012:function/rewrite2"
      cloudfront_cert                 = "arn:aws:acm:us-east-1:123456789012:certificate/def"
      repository                      = "Home-Office-Digital/docs"
      github_environment_name         = "staging"
    }
    cloud_front_default_vars = {
      cloudfront_price_class = "PriceClass_All"
    }
  }

  assert {
    condition     = aws_s3_bucket.static_site.bucket == "cc-static-site-docs-site"
    error_message = "Bucket name should recompose for a different product/component"
  }

  assert {
    condition     = aws_wafv2_web_acl.default.name == "cc-static-site-docs-site"
    error_message = "WAF ACL name should recompose for a different product/component"
  }

  # Multiple CloudFront aliases pass through.
  assert {
    condition     = aws_cloudfront_distribution.static_site_distribution.aliases == toset(["docs.example.gov.uk", "www.docs.example.gov.uk"])
    error_message = "Multiple CloudFront aliases should pass through as a set"
  }

  assert {
    condition     = aws_cloudfront_distribution.static_site_distribution.price_class == "PriceClass_All"
    error_message = "Overridden price class should pass through"
  }
}

# Edge case: empty CloudFront aliases list still plans cleanly.
run "empty_aliases" {
  command = plan

  variables {
    aws_region = "eu-west-2"
    tenant_vars = {
      COST_CENTRE                     = "CC-0000"
      product                         = "min"
      component                       = "app"
      cloudfront_aliases              = []
      cloudfront_function_rewrite_arn = "arn:aws:cloudfront::123456789012:function/rewrite3"
      cloudfront_cert                 = "arn:aws:acm:us-east-1:123456789012:certificate/ghi"
      repository                      = "Home-Office-Digital/min"
      github_environment_name         = "production"
    }
    cloud_front_default_vars = {
      cloudfront_price_class = "PriceClass_100"
    }
  }

  assert {
    condition     = length(aws_cloudfront_distribution.static_site_distribution.aliases) == 0
    error_message = "Empty aliases list should produce a distribution with no aliases"
  }

  assert {
    condition     = aws_s3_bucket.static_site.bucket == "cc-static-site-min-app"
    error_message = "Bucket name should compose even with minimal tenant config"
  }
}
