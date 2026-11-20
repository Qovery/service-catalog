# AWS CloudFront

Creates an AWS CloudFront distribution in front of a single HTTP/S origin (an ALB, application host, or S3 website endpoint) with configurable caching, price class, optional custom domains, and geo restrictions.

By default the distribution serves over the CloudFront-managed `*.cloudfront.net` certificate; set `aliases` + `acm_certificate_arn` (certificate must be in **us-east-1**) to serve custom domains.

## Credentials

Uses the Qovery cluster's AWS credentials (`credentials.default: cluster`). The credentials must allow the CloudFront and (when using ACM) certificate actions listed under [Required IAM permissions](#required-aws-iam-permissions). When `role_arn` is set, the listed permissions are needed by that role instead, and the deploy credentials only need `sts:AssumeRole` on it (see [Assuming an IAM role](#assuming-an-iam-role)).

## Variables

### Required

| Name                 | Type   | Description                                                                                          |
| -------------------- | ------ | ---------------------------------------------------------------------------------------------------- |
| `origin_domain_name` | string | Origin hostname CloudFront pulls from (e.g. an ALB, app host, or S3 website endpoint). Bare hostname, no scheme or path. |

### Distribution

| Name                  | Type   | Default                     | Description                                             |
| --------------------- | ------ | --------------------------- | ------------------------------------------------------- |
| `comment`             | string | `Managed by Qovery blueprint` | Distribution comment shown in the AWS console         |
| `enabled`             | bool   | `true`                      | Whether the distribution accepts end-user requests      |
| `is_ipv6_enabled`     | bool   | `true`                      | Enable IPv6                                             |
| `default_root_object` | string |                             | Object returned for the root URL (e.g. `index.html`)    |
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
| `aliases`                   | string |         | Comma-separated custom domains (CNAMEs). Requires `acm_certificate_arn`.           |
| `acm_certificate_arn`       | string |         | ACM cert ARN for the custom domains (**must be in us-east-1**).                    |
| `geo_restriction_type`      | string | `none`  | `none`, `whitelist`, or `blacklist`                                               |
| `geo_restriction_locations` | string |         | Comma-separated ISO country codes (e.g. `US,FR`). Required when type is not `none`. |

### IAM role

| Name       | Type   | Default | Description                                                                                                                                         |
| ---------- | ------ | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `role_arn` | string | —       | Unset = use the cluster credentials directly. Set an IAM role ARN of the cluster's AWS account to assume it; cross-account roles are not supported. |

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

## Assuming an IAM role

Optional. Set the `role_arn` variable to make the blueprint assume an IAM role instead of using the configured credentials directly; leave it unset to use them as is.

- Format: `arn:aws:iam::<account-id>:role/<name>`, with an optional path (`role/<path>/<name>`). The `aws-cn`, `aws-us-gov` and `aws-iso*` partitions are accepted too.
- The role must be in the **same AWS account** as the credentials; cross-account roles are not supported.
- The deploy credentials need `sts:AssumeRole` on that role, **and** the role's trust policy must allow the deploy credentials' IAM principal to assume it. Without both, the deployment fails with `AccessDenied`.
- The role itself must carry the permissions listed in [Required AWS IAM permissions](#required-aws-iam-permissions).

## Required AWS IAM permissions

> When `role_arn` is set, Terraform makes these AWS calls as the assumed role, so the permissions below belong to that role; the deploy credentials then only need `sts:AssumeRole` on it for those calls (see [Assuming an IAM role](#assuming-an-iam-role)). Access to a user-provided Terraform backend, if you use one, is not covered by `role_arn`: it keeps using the deploy credentials.

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
