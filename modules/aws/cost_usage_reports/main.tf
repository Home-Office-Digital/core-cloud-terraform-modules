terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

provider "aws" {
  region = "us-east-1"
  alias  = "us-east-1"
}

#COST AND USAGE REPORT
resource "aws_cur_report_definition" "cur_report_definitions" {
  depends_on                 = [aws_iam_role.cur_role, aws_s3_bucket_policy.cur_S3_bucket_policy]
  provider                   = aws.us-east-1
  report_name                = var.report_name
  time_unit                  = var.time_unit
  format                     = var.format
  compression                = var.compression
  additional_schema_elements = var.additional_schema_elements
  s3_bucket                  = aws_s3_bucket.s3_buckets.id
  s3_region                  = var.bucket_region
  additional_artifacts       = var.additional_artifacts
  s3_prefix                  = "cur/${var.billing_account}"
  refresh_closed_reports     = var.refresh_closed_reports
  report_versioning          = var.report_versioning
}

#S3 BUCKET
resource "aws_s3_bucket" "s3_buckets" {
  bucket = var.bucket_name
}

#S3 SETTINGS
resource "aws_s3_bucket_ownership_controls" "bucket_ownership_controls" {
  bucket = aws_s3_bucket.s3_buckets.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "versioning_rules" {
  bucket = aws_s3_bucket.s3_buckets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption_rules" {
  bucket = aws_s3_bucket.s3_buckets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cur_public_access_block" {
  bucket = aws_s3_bucket.s3_buckets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#IAM ROLE
resource "aws_iam_role" "cur_role" {
  name = var.iam_role
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "s3.amazonaws.com"
        },
        "Effect" : "Allow",
        "Sid" : ""
      }
    ]
  })

  inline_policy {
    name = var.inline_policy_name

    policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : [
            "s3:GetReplicationConfiguration",
            "s3:ListBucket"
          ],
          "Resource" : "arn:aws:s3:::cid-${var.billing_account}-central-finops-local",
          "Effect" : "Allow"
        },
        {
          "Action" : [
            "s3:GetObjectVersionForReplication",
            "s3:GetObjectVersionAcl"
          ],
          "Resource" : "arn:aws:s3:::cid-${var.billing_account}-central-finops-local/*",
          "Effect" : "Allow"
        },
        {
          "Action" : [
            "s3:ReplicateObject",
            "s3:ReplicateDelete",
            "s3:ReplicateTags",
            "s3:GetObjectVersionTagging"
          ],
          "Resource" : "arn:aws:s3:::cid-873134405383-shared/cur/${var.billing_account}/*",
          "Effect" : "Allow"
        }
      ]
    })
  }
}

#S3 BUCKET POLICY
resource "aws_s3_bucket_policy" "cur_S3_bucket_policy" {
  bucket = aws_s3_bucket.s3_buckets.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "billingreports.amazonaws.com"
        },
        "Action" : [
          "s3:GetBucketAcl",
          "s3:GetBucketPolicy"
        ],
        "Resource" : aws_s3_bucket.s3_buckets.arn,
        "Condition" : {
          "StringEquals" : {
            "aws:SourceAccount" : var.billing_account,
            "aws:SourceArn" : "arn:aws:cur:us-east-1:${var.billing_account}:definition/*"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "billingreports.amazonaws.com"
        },
        "Action" : "s3:PutObject",
        "Resource" : "${aws_s3_bucket.s3_buckets.arn}/*",
        "Condition" : {
          "StringEquals" : {
            "aws:SourceAccount" : var.billing_account,
            "aws:SourceArn" : "arn:aws:cur:us-east-1:${var.billing_account}:definition/*"
          }
        }
      },
      {
        "Effect" : "Deny",
        "Principal" : "*",
        "Action" : "s3:*",
        "Resource" : [
          "arn:aws:s3:::cid-${var.billing_account}-central-finops-local",
          "arn:aws:s3:::cid-${var.billing_account}-central-finops-local/*",
        ],
        "Condition" : {
          "Bool" : {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}


#S3 LIFECYCLE RULE
resource "aws_s3_bucket_lifecycle_configuration" "cur_bucket_lifecycle_rule" {
  depends_on = [aws_s3_bucket_versioning.versioning_rules]
  bucket     = aws_s3_bucket.s3_buckets.id
  rule {
    id = var.lifecycle_rule

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    expiration {
      days = var.expiration_days
    }
    status = "Enabled"
  }
}

# REPLICATION RULE
resource "aws_s3_bucket_replication_configuration" "cur_bucket_replication_rule" {
  depends_on = [aws_s3_bucket_versioning.versioning_rules]
  bucket     = aws_s3_bucket.s3_buckets.id
  role       = aws_iam_role.cur_role.arn
  rule {
    id = var.replication_rule

    filter {}

    destination {
      bucket        = var.destination_bucket
      storage_class = "STANDARD"

      metrics {
        status = "Enabled"
      }
    }

    delete_marker_replication {
      status = "Enabled"
    }

    status = "Enabled"
  }
}
