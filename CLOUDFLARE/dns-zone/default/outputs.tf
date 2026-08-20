output "zone_id" {
  description = "Cloudflare zone ID"
  value       = cloudflare_zone.this.id
}

output "zone_name" {
  description = "Managed domain name"
  value       = cloudflare_zone.this.name
}

output "name_servers" {
  description = "Cloudflare-assigned name servers to set at your registrar (full zones only)"
  value       = cloudflare_zone.this.name_servers
}

output "status" {
  description = "Zone activation status"
  value       = cloudflare_zone.this.status
}

output "verification_key" {
  description = "TXT verification value for partial (CNAME) setups"
  value       = cloudflare_zone.this.verification_key
}

output "record_id" {
  description = "Created DNS record ID (empty when no record is configured)"
  value       = length(cloudflare_dns_record.this) > 0 ? cloudflare_dns_record.this[0].id : ""
}
