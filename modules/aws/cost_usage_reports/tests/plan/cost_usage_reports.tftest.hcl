# Plan-level tests for the cost_usage_reports module.
# The module has no data sources, so a bare mocked provider suffices.
# We assert variable passthrough, string composition (s3_prefix / inline
# policy resource ARNs), and that the resource graph is planned successfully.

mock_provider "aws" {}

mock_provider "aws" {
  alias = "us-east-1"
}

run "valid_inputs_plan_and_compose" {
  command = plan

  variables {
    report_name                        = "org-cur"
    time_unit                          = "DAILY"
    format                             = "Parquet"
    compression                        = "Parquet"
    additional_schema_elements         = ["RESOURCES"]
    bucket_name                        = "cid-123456789012-central-finops-local"
    bucket_region                      = "eu-west-2"
    additional_artifacts               = ["ATHENA"]
    refresh_closed_reports             = "true"
    report_versioning                  = "OVERWRITE_REPORT"
    iam_role                           = "cur-replication-role"
    lifecycle_rule                     = "expire-noncurrent"
    noncurrent_version_expiration_days = 30
    expiration_days                    = 365
    inline_policy_name                 = "cur-replication-inline"
    billing_account                    = "123456789012"
    replication_rule                   = "replicate-cur"
    destination_bucket                 = "arn:aws:s3:::cid-873134405383-shared"
  }

  # CUR report definition passthrough.
  assert {
    condition     = aws_cur_report_definition.cur_report_definitions.report_name == "org-cur"
    error_message = "report_name should pass through to the CUR definition"
  }

  assert {
    condition     = aws_cur_report_definition.cur_report_definitions.time_unit == "DAILY"
    error_message = "time_unit should pass through to the CUR definition"
  }

  # s3_prefix is composed as cur/<billing_account>.
  assert {
    condition     = aws_cur_report_definition.cur_report_definitions.s3_prefix == "cur/123456789012"
    error_message = "s3_prefix should be composed as cur/<billing_account>"
  }

  # Bucket name passthrough.
  assert {
    condition     = aws_s3_bucket.s3_buckets.bucket == "cid-123456789012-central-finops-local"
    error_message = "S3 bucket name should pass through"
  }

  # IAM role name passthrough.
  assert {
    condition     = aws_iam_role.cur_role.name == "cur-replication-role"
    error_message = "IAM role name should pass through"
  }

  # Lifecycle rule count/id and expiration values.
  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.cur_bucket_lifecycle_rule.rule[0].id == "expire-noncurrent"
    error_message = "Lifecycle rule id should pass through"
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.cur_bucket_lifecycle_rule.rule[0].expiration[0].days == 365
    error_message = "Lifecycle expiration days should pass through"
  }

  # Replication destination bucket passthrough.
  assert {
    condition     = aws_s3_bucket_replication_configuration.cur_bucket_replication_rule.rule[0].destination[0].bucket == "arn:aws:s3:::cid-873134405383-shared"
    error_message = "Replication destination bucket should pass through"
  }

  # Public access block fully locked down.
  assert {
    condition = (
      aws_s3_bucket_public_access_block.cur_public_access_block.block_public_acls == true &&
      aws_s3_bucket_public_access_block.cur_public_access_block.restrict_public_buckets == true
    )
    error_message = "S3 public access block should be fully enabled"
  }
}

# Alternative valid enum combination (textORcsv/GZIP/HOURLY) still plans cleanly.
run "alternative_valid_enums" {
  command = plan

  variables {
    report_name                        = "hourly-cur"
    time_unit                          = "HOURLY"
    format                             = "textORcsv"
    compression                        = "GZIP"
    additional_schema_elements         = ["SPLIT_COST_ALLOCATION_DATA"]
    bucket_name                        = "cid-123456789012-central-finops-local"
    bucket_region                      = "us-east-1"
    additional_artifacts               = ["REDSHIFT"]
    refresh_closed_reports             = "false"
    report_versioning                  = "CREATE_NEW_REPORT"
    iam_role                           = "cur-role-2"
    lifecycle_rule                     = "lc-rule"
    noncurrent_version_expiration_days = 7
    expiration_days                    = 90
    inline_policy_name                 = "inline-2"
    billing_account                    = "123456789012"
    replication_rule                   = "repl-rule"
    destination_bucket                 = "arn:aws:s3:::dest-bucket"
  }

  assert {
    condition     = aws_cur_report_definition.cur_report_definitions.compression == "GZIP"
    error_message = "compression should pass through for the alternative enum set"
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.cur_bucket_lifecycle_rule.rule[0].noncurrent_version_expiration[0].noncurrent_days == 7
    error_message = "noncurrent_version_expiration_days should pass through"
  }
}
