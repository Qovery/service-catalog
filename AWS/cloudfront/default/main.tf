locals {
  aliases       = var.aliases == "" ? [] : [for a in split(",", var.aliases) : trimspace(a)]
  geo_locations = var.geo_restriction_type == "none" ? [] : [for c in split(",", var.geo_restriction_locations) : trimspace(c)]
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = var.enabled
  is_ipv6_enabled     = var.is_ipv6_enabled
  comment             = var.comment
  price_class         = var.price_class
  aliases             = local.aliases
  default_root_object = var.default_root_object == "" ? null : var.default_root_object

  origin {
    domain_name = var.origin_domain_name
    origin_id   = var.origin_domain_name

    custom_origin_config {
      http_port              = var.origin_http_port
      https_port             = var.origin_https_port
      origin_protocol_policy = var.origin_protocol_policy
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = var.origin_domain_name
    viewer_protocol_policy = var.viewer_protocol_policy
    compress               = true

    # forwarded_values is the self-contained caching config (no dependency on a managed
    # cache policy id). Pinned provider ~> 5.0 still supports it.
    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }

    min_ttl     = var.min_ttl
    default_ttl = var.default_ttl
    max_ttl     = var.max_ttl
  }

  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = local.geo_locations
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == "" ? true : null
    acm_certificate_arn            = var.acm_certificate_arn == "" ? null : var.acm_certificate_arn
    ssl_support_method             = var.acm_certificate_arn == "" ? null : "sni-only"
    minimum_protocol_version       = var.acm_certificate_arn == "" ? "TLSv1" : "TLSv1.2_2021"
  }

  tags = {
    Name        = var.origin_domain_name
    ManagedBy   = "qovery-blueprint"
    Blueprint   = "aws-cloudfront"
    ClusterName = var.qovery_cluster_name
  }
}
