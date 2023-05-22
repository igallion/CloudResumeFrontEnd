terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.21.0"
    }
  }

  backend "s3" {
    bucket = "ilg-tf-test-config"
    key    = "frontend/terraform.tfstate"
    region = "us-east-1"
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

//Dir module sets Content-Type value for each web file uploaded to S3
module "dir" {
  source   = "hashicorp/dir/template"
  version  = "1.0.2"
  base_dir = "build"
}

resource "aws_acm_certificate" "cert" {
  domain_name = "www.ilgallion.com"
  //subject_alternative_names = ["www.ilgallion.com"]
  validation_method = "DNS"
  //key_algorithm             = "RSA-2048"
}

resource "aws_acm_certificate" "cert2" {
  domain_name = "www.ilgallion.com"
  //subject_alternative_names = ["www.ilgallion.com"]
  validation_method = "DNS"
  //key_algorithm             = "RSA-2048"
}

resource "aws_acm_certificate_validation" "validationTF" {
  certificate_arn         = aws_acm_certificate.cert2.arn
  validation_record_fqdns = [for record in aws_route53_record.NSRecordsTerraform : record.fqdn]
}

resource "aws_route53_zone" "hostedZoneTerraform" {
  name    = "ilgallion.com"
  comment = "Hosted zone now managed by Terraform"
}

resource "aws_route53_record" "NSRecordsTerraform" {
  for_each = {
    for dvo in aws_acm_certificate.cert2.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.hostedZoneTerraform.zone_id
}
/*
resource "aws_route53_record" "A" {
  zone_id = aws_route53_zone.hostedZoneTerraform.zone_id
  name    = "ilgallion.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.TestDistribution.domain_name
    zone_id                = aws_cloudfront_distribution.TestDistribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.hostedZoneTerraform.zone_id
  name    = "www.ilgallion.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.TestDistribution.domain_name
    zone_id                = aws_cloudfront_distribution.TestDistribution.hosted_zone_id
    evaluate_target_health = false
  }
}
*/
//S3 bucket
resource "aws_s3_bucket" "TestBucket" {
  bucket = "ilg-tf-test-bucket"
  acl    = "private"

  website {
    index_document = "index.html"
  }
}

//Upload web files to S3 (uses Dir module to set Content-Type for each web file)
resource "aws_s3_bucket_object" "Testbuild" {
  for_each     = module.dir.files
  bucket       = aws_s3_bucket.TestBucket.id
  key          = each.key
  content_type = each.value.content_type
  source       = each.value.source_path
  etag         = each.value.digests.md5
}

//S3 bucket policy
resource "aws_s3_bucket_policy" "TestPolicy" {
  bucket = aws_s3_bucket.TestBucket.id
  policy = data.aws_iam_policy_document.TestBucketPolicy.json
}

//S3 block public access
resource "aws_s3_bucket_public_access_block" "TestBlock" {
  bucket = aws_s3_bucket.TestBucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

//S3 bucket policy document
data "aws_iam_policy_document" "TestBucketPolicy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.TestBucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.TerraformTest.iam_arn]
    }
  }
}

//Cloudfront Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "TerraformTest" {
  comment = "TerraformTest"
}


//Cloudfront Distribution
resource "aws_cloudfront_distribution" "TestDistribution" {
  origin {
    domain_name = aws_s3_bucket.TestBucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.TestBucket.bucket
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.TerraformTest.cloudfront_access_identity_path
    }
  }

  enabled             = true
  comment             = "Test create from Terraform"
  default_root_object = "index.html"
  aliases             = "www.ilgallion.com"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.TestBucket.bucket

    forwarded_values {
      query_string = true

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US"]
    }
  }
  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cert2.arn
    ssl_support_method  = "sni-only"
  }
}

output "cloudfront_distribution_domain_name" {
  description = "The domain name corresponding to the distribution."
  value       = try(aws_cloudfront_distribution.TestDistribution.domain_name, "")
}
