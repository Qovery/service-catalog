# AWS CloudFront

Creates an AWS CloudFront distribution in front of a single HTTP/S origin (an ALB, application host, or S3 website endpoint) with configurable caching, price class, optional custom domains, and geo restrictions.

By default the distribution serves over the CloudFront-managed `*.cloudfront.net` certificate; set `aliases` + `acm_certificate_arn` (certificate must be in **us-east-1**) to serve custom domains.

## Credentials

Uses the Qovery cluster's AWS credentials (`credentials.default: cluster`). The credentials must allow the CloudFront and (when using ACM) certificate actions listed under [Required IAM permissions](#required-aws-iam-permissions).

## Variables

### Required

| Name                 | Type   | Description                                                                                          |
| -------------------- | ------ | ---------------------------------------------------------------------------------------------------- |
| `origin_domain_name` | string | Origin hostname CloudFront pulls from (ALB, app host, or S3 website endpoint). Bare host, no scheme. |

### Distribution

| Name                  | Type   | Default                     | Description                                             |
| --------------------- | ------ | --------------------------- | ------------------------------------------------------- |
| `comment`             | string | `Managed by Qovery blueprint` | Distribution comment shown in the AWS console         |
| `enabled`             | bool   | `true`                      | Whether the distribution accepts end-user requests      |
| `is_ipv6_enabled`     | bool   | `true`                      | Enable IPv6                                             |
| `default_root_object` | string | `""`                        | Object returned for the root URL (e.g. `index.html`)    |
| `price_class`         | string | `PriceClass_100`            | `PriceClass_100`, `PriceClass_200`, or `PriceClass_All` |

### Origin

| Name                     | Type   | Default      | Description                                            |
| ------------------------ | ------ | ------------ | ------------------------------------------------------ |
| `origin_protocol_policy` | string | `https-only` | `http-only`, `https-only`, or `match-viewer`           |
| `origin_http_port`       | number | `80`         | Origin HTTP port                                       |
| `origin_https_port`      | number | `443`        | Origin HTTPS port                                      |

### Caching / viewer

| Name                     | Type   | Default             | Description                                             |
| ------------------------ | ------ | ------------------- | ------------------------------------------------------- |
| `viewer_protocol_policy` | string | `redirect-to-https` | `allow-all`, `https-only`, or `redirect-to-https`       |
| `min_ttl`                | number | `0`                 | Minimum cache TTL (seconds)                             |
| `default_ttl`            | number | `3600`              | Default cache TTL (seconds)                             |
| `max_ttl`                | number | `86400`             | Maximum cache TTL (seconds); must be `>= min_ttl`       |

### Custom domain & geo

| Name                        | Type   | Default | Description                                                                       |
| --------------------------- | ------ | ------- | --------------------------------------------------------------------------------- |
| `aliases`                   | string | `""`    | Comma-separated custom domains (CNAMEs). Requires `acm_certificate_arn`.           |
| `acm_certificate_arn`       | string | `""`    | ACM cert ARN for the custom domains (**must be in us-east-1**).                    |
| `geo_restriction_type`      | string | `none`  | `none`, `whitelist`, or `blacklist`                                               |
| `geo_restriction_locations` | string | `""`    | Comma-separated ISO country codes (e.g. `US,FR`). Required when type is not `none`. |

## Outputs

| Name               | Description                                                     |
| ------------------ | --------------------------------------------------------------- |
| `distribution_id`  | CloudFront distribution ID                                      |
| `distribution_arn` | CloudFront distribution ARN                                     |
| `domain_name`      | CloudFront domain name (`*.cloudfront.net`) to point traffic at |
| `url`              | Full HTTPS URL of the distribution (`https://<domain_name>`)    |
| `hosted_zone_id`   | CloudFront hosted zone ID (for a Route53 alias record)          |
| `status`           | Distribution deployment status                                  |
| `etag`             | Current version identifier (ETag)                               |

## Notes

- Caching uses the self-contained `forwarded_values` config (query string forwarded, cookies not), so the blueprint doesn't depend on a managed cache policy id. The AWS provider is pinned to `~> 5.0`.
- CloudFront is a global service; the provider `region` (from the cluster) only configures the AWS client.

## Required AWS IAM permissions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudfront:CreateDistribution",
        "cloudfront:GetDistribution",
        "cloudfront:UpdateDistribution",
        "cloudfront:DeleteDistribution",
        "cloudfront:TagResource",
        "cloudfront:UntagResource",
        "cloudfront:ListTagsForResource",
        "acm:DescribeCertificate",
        "acm:ListCertificates"
      ],
      "Resource": "*"
    }
  ]
}
```
