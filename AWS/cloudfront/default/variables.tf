# Qovery-injected variables (auto-filled from cluster context)
variable "region" {
  type        = string
  description = "AWS region (used to configure the provider; CloudFront itself is global)"
}

variable "qovery_cluster_name" {
  type        = string
  default     = ""
  description = "Qovery cluster name, used for resource tagging"
}

# User-provided variables
variable "origin_domain_name" {
  type        = string
  description = "Origin hostname CloudFront pulls from (e.g. an ALB, app host, or S3 website endpoint). No scheme, no path."

  validation {
    condition     = length(var.origin_domain_name) > 0 && !can(regex("://", var.origin_domain_name))
    error_message = "origin_domain_name must be a bare hostname without a scheme (no http:// or https://)."
  }
}

variable "comment" {
  type        = string
  default     = "Managed by Qovery blueprint"
  description = "Distribution comment shown in the AWS console"
}

variable "enabled" {
  type        = bool
  default     = true
  description = "Whether the distribution accepts end-user requests"
}

variable "is_ipv6_enabled" {
  type        = bool
  default     = true
  description = "Enable IPv6 for the distribution"
}

variable "default_root_object" {
  type        = string
  default     = ""
  description = "Object returned for requests to the root URL (e.g. index.html). Empty = none."
}

variable "price_class" {
  type        = string
  default     = "PriceClass_100"
  description = "Edge location price class"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be one of: PriceClass_100, PriceClass_200, PriceClass_All."
  }
}

# Origin connection
variable "origin_protocol_policy" {
  type        = string
  default     = "https-only"
  description = "How CloudFront connects to the origin"

  validation {
    condition     = contains(["http-only", "https-only", "match-viewer"], var.origin_protocol_policy)
    error_message = "origin_protocol_policy must be one of: http-only, https-only, match-viewer."
  }
}

variable "origin_http_port" {
  type        = number
  default     = 80
  description = "Origin HTTP port"
}

variable "origin_https_port" {
  type        = number
  default     = 443
  description = "Origin HTTPS port"
}

# Viewer behavior
variable "viewer_protocol_policy" {
  type        = string
  default     = "redirect-to-https"
  description = "How viewers connect to CloudFront"

  validation {
    condition     = contains(["allow-all", "https-only", "redirect-to-https"], var.viewer_protocol_policy)
    error_message = "viewer_protocol_policy must be one of: allow-all, https-only, redirect-to-https."
  }
}

variable "min_ttl" {
  type        = number
  default     = 0
  description = "Minimum cache TTL in seconds"
}

variable "default_ttl" {
  type        = number
  default     = 3600
  description = "Default cache TTL in seconds"
}

variable "max_ttl" {
  type        = number
  default     = 86400
  description = "Maximum cache TTL in seconds"

  validation {
    condition     = var.max_ttl >= var.min_ttl
    error_message = "max_ttl must be greater than or equal to min_ttl."
  }
}

# Custom domain (optional)
variable "aliases" {
  type        = string
  default     = ""
  description = "Comma-separated custom domain names (CNAMEs). Requires acm_certificate_arn. Empty = use the default *.cloudfront.net domain."

  validation {
    # CloudFront rejects aliases without a matching ACM certificate.
    condition     = var.aliases == "" || var.acm_certificate_arn != ""
    error_message = "acm_certificate_arn is required when aliases are set."
  }
}

variable "acm_certificate_arn" {
  type        = string
  default     = ""
  description = "ACM certificate ARN for the custom domains. Must be in us-east-1. Empty = use the default CloudFront certificate."
}

# Geo restrictions
variable "geo_restriction_type" {
  type        = string
  default     = "none"
  description = "Geo restriction mode"

  validation {
    condition     = contains(["none", "whitelist", "blacklist"], var.geo_restriction_type)
    error_message = "geo_restriction_type must be one of: none, whitelist, blacklist."
  }
}

variable "geo_restriction_locations" {
  type        = string
  default     = ""
  description = "Comma-separated ISO 3166-1-alpha-2 country codes (e.g. US,FR). Required when geo_restriction_type is not none."

  validation {
    condition     = var.geo_restriction_type == "none" || var.geo_restriction_locations != ""
    error_message = "geo_restriction_locations is required when geo_restriction_type is whitelist or blacklist."
  }
}
