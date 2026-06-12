# AWS RDS MySQL 8

Creates an AWS RDS MySQL 8.4 instance with configurable instance class, storage, and Multi-AZ deployment. Storage is encrypted by default with automated backups retained for 7 days.

The RDS identifier is derived from `db_name` by lowercasing and replacing underscores with hyphens (AWS requirement). The actual MySQL database name is kept as provided.

## Variables

| Name                | Type   | Required | Sensitive | Default       | Description                                                                                                              |
| ------------------- | ------ | -------- | --------- | ------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `db_name`           | string | yes      |           | —             | MySQL database name. Letters, digits, underscores only; must start with a letter; max 64 chars. Hyphens are not allowed. |
| `db_username`       | string | yes      |           | —             | Master username. Letters, digits, underscores; must start with a letter; max 32 chars (MySQL limit).                     |
| `db_password`       | string | yes      | yes       | —             | Master password. 8–128 chars. Must not contain `/`, `@`, `"`, or spaces.                                                 |
| `instance_class`    | string | no       |           | `db.t3.micro` | RDS instance class (e.g. `db.t3.micro`, `db.m5.large`)                                                                   |
| `allocated_storage` | number | no       |           | `20`          | Allocated storage in GiB. Min 20, max 65536 (gp3).                                                                       |
| `multi_az`          | bool   | no       |           | `false`       | Enable Multi-AZ deployment for high availability                                                                         |

## Outputs

| Name          | Description                       |
| ------------- | --------------------------------- |
| `db_endpoint` | RDS instance endpoint (host:port) |
| `db_address`  | RDS instance hostname             |
| `db_port`     | RDS instance port                 |
| `db_name`     | Database name                     |

## Required AWS IAM permissions

The credentials used to deploy this blueprint must allow the actions below. The RDS actions target instances in any region you deploy to; EC2 read actions are needed so Terraform can look up the default VPC, subnets, and security groups when none are explicitly configured.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "rds:CreateDBInstance",
        "rds:DeleteDBInstance",
        "rds:ModifyDBInstance",
        "rds:DescribeDBInstances",
        "rds:DescribeDBParameters",
        "rds:DescribeDBSubnetGroups",
        "rds:DescribeDBSecurityGroups",
        "rds:AddTagsToResource",
        "rds:RemoveTagsFromResource",
        "rds:ListTagsForResource"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeAvailabilityZones"
      ],
      "Resource": "*"
    }
  ]
}
```
