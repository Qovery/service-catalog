variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API token with Workers Scripts edit permission (and Workers Routes edit if using a route)"

  validation {
    condition     = length(var.cloudflare_api_token) > 0
    error_message = "cloudflare_api_token must not be empty."
  }
}

variable "account_id" {
  type        = string
  description = "Cloudflare account ID that owns the Worker"

  validation {
    condition     = length(var.account_id) > 0
    error_message = "account_id must not be empty."
  }
}

variable "script_name" {
  type        = string
  description = "Worker script name (lowercase letters, digits, hyphens, underscores)"

  validation {
    condition     = can(regex("^[a-z0-9_-]+$", var.script_name))
    error_message = "script_name must contain only lowercase letters, digits, hyphens, and underscores."
  }
}

variable "script_content" {
  type        = string
  default     = "addEventListener('fetch', (event) => { event.respondWith(new Response('Hello from a Qovery-managed Cloudflare Worker')); });"
  description = "Worker script source. Defaults to a hello-world service-worker script."
}

variable "main_module" {
  type        = string
  default     = ""
  description = "Entrypoint module name for ES-module Workers (e.g. worker.js). Empty = service-worker syntax (addEventListener)."
}

variable "compatibility_date" {
  type        = string
  default     = "2024-09-23"
  description = "Cloudflare Workers runtime compatibility date (YYYY-MM-DD)"

  validation {
    condition     = can(regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", var.compatibility_date))
    error_message = "compatibility_date must be in YYYY-MM-DD format."
  }
}

# Optional route: bind the Worker to a URL pattern on a zone.
variable "route_zone_id" {
  type        = string
  default     = ""
  description = "Zone ID to attach a route on. Empty = no route (Worker reachable only via workers.dev / other bindings)."
}

variable "route_pattern" {
  type        = string
  default     = ""
  description = "Route pattern that triggers the Worker (e.g. example.com/*). Required when route_zone_id is set."

  validation {
    condition     = var.route_zone_id == "" || var.route_pattern != ""
    error_message = "route_pattern is required when route_zone_id is set."
  }
}
