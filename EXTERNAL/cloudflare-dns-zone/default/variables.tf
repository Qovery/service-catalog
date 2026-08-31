variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API token with Zone edit permission (and account-level zone create permission)"

  validation {
    condition     = length(var.cloudflare_api_token) > 0
    error_message = "cloudflare_api_token must not be empty."
  }
}

variable "account_id" {
  type        = string
  description = "Cloudflare account ID that will own the zone"

  validation {
    condition     = length(var.account_id) > 0
    error_message = "account_id must not be empty."
  }
}

variable "zone_name" {
  type        = string
  description = "Domain to manage in Cloudflare (e.g. example.com). The domain must already be registered; this manages its DNS zone, it does not register it."

  validation {
    condition     = can(regex("^[a-z0-9.-]+\\.[a-z]{2,}$", lower(var.zone_name)))
    error_message = "zone_name must be a valid domain name (e.g. example.com)."
  }
}

variable "zone_type" {
  type        = string
  default     = "full"
  description = "Zone setup type: full (Cloudflare hosts the DNS) or partial (CNAME/partner setup)"

  validation {
    condition     = contains(["full", "partial"], var.zone_type)
    error_message = "zone_type must be one of: full, partial."
  }
}

# Optional single DNS record
variable "record_name" {
  type        = string
  default     = ""
  description = "Optional DNS record name (e.g. www, @, or a full host). Empty = create no record."
}

variable "record_type" {
  type        = string
  default     = "A"
  description = "DNS record type"

  validation {
    condition     = contains(["A", "AAAA", "CNAME", "TXT", "MX", "NS"], var.record_type)
    error_message = "record_type must be one of: A, AAAA, CNAME, TXT, MX, NS."
  }
}

variable "record_content" {
  type        = string
  default     = ""
  description = "DNS record value (IP, hostname, or text). Required when record_name is set."

  validation {
    condition     = var.record_name == "" || var.record_content != ""
    error_message = "record_content is required when record_name is set."
  }
}

variable "record_ttl" {
  type        = number
  default     = 1
  description = "DNS record TTL in seconds (1 = automatic). Must be 1 when record_proxied is true."
}

variable "record_proxied" {
  type        = bool
  default     = false
  description = "Whether the record is proxied through Cloudflare (orange cloud). Only valid for A/AAAA/CNAME."
}

variable "qovery_cluster_name" {
  type        = string
  description = "Qovery cluster name, injected by the engine on every Terraform blueprint"
}

variable "region" {
  type        = string
  description = "Qovery cluster region, injected by the engine on every Terraform blueprint"
}
