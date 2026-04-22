---
name: tofu-security
description: OpenTofu/Terraform-specific security antipatterns for use by security-reviewer — IAM over-permission, missing encryption, public exposure, hardcoded secrets, audit logging gaps
---

# OpenTofu / Terraform Security

Security antipatterns specific to OpenTofu and Terraform HCL. Loaded by the `security-reviewer` agent. Use CRITICAL / HIGH / MEDIUM / LOW based on exploitability and impact.

---

## IAM Over-Permission

**CRITICAL — Wildcard action or resource**
IAM policies with `"Action": "*"` or `"Resource": "*"` without an explicit justification comment and a reference to the architectural decision that approved it. Apply principle of least privilege.

**CRITICAL — AdministratorAccess attached**
IAM roles or users with `AdministratorAccess` managed policy attached unless the resource is explicitly documented as a break-glass emergency account.

**CRITICAL — Open assume-role principal**
`assume_role_policy` with `"Principal": {"AWS": "*"}` — allows any AWS account to assume the role. Must be scoped to specific account IDs or ARNs.

**HIGH — Service-level wildcard action**
`"Action": "s3:*"` or similar service-namespace wildcards. May be intentional but must have a comment explaining why least-privilege scoping is not feasible.

---

## Hardcoded Sensitive Values

**CRITICAL — AWS access key pattern in source**
Any string matching `AKIA[A-Z0-9]{16}` in `.tf` or `.tofu` files — this is an AWS access key ID format and should never be in source.

**CRITICAL — Private key or certificate in source**
String literals containing `-----BEGIN` in any HCL file.

**CRITICAL — Sensitive variable default**
A `variable` block declared with `sensitive = true` that also has a non-empty `default` value containing a literal secret:
```hcl
# REJECT
variable "db_password" {
  sensitive = true
  default   = "mysecretpassword"
}
```

**HIGH — Sensitive output without `sensitive = true`**
An `output` block that exposes values like passwords, tokens, or private keys without `sensitive = true` — these values appear in plan/apply output in plaintext.

---

## Missing Encryption at Rest

**HIGH — S3 bucket without server-side encryption**
`aws_s3_bucket` without a corresponding `aws_s3_bucket_server_side_encryption_configuration` resource (or `server_side_encryption_configuration` block). AES-256 or aws:kms required.

**HIGH — RDS / Aurora without storage encryption**
`aws_db_instance` or `aws_rds_cluster` without `storage_encrypted = true`.

**HIGH — EBS volume without encryption**
`aws_ebs_volume` without `encrypted = true`.

**HIGH — SQS queue handling sensitive data without KMS**
`aws_sqs_queue` used in data pipelines or event-driven architectures without `kms_master_key_id` set.

**MEDIUM — ElastiCache without at-rest encryption**
`aws_elasticache_replication_group` without `at_rest_encryption_enabled = true`.

---

## Public Exposure

**CRITICAL — S3 public access blocks disabled**
`aws_s3_bucket_public_access_block` with any of the following set to `false`:
- `block_public_acls`
- `block_public_policy`
- `ignore_public_acls`
- `restrict_public_buckets`

Exception: static website hosting bucket with an explicit comment and `website` configuration block. Escalate for review.

**CRITICAL — Security group open ingress on sensitive ports**
`aws_security_group_rule` or inline `ingress` block with `cidr_blocks = ["0.0.0.0/0"]` (or `ipv6_cidr_blocks = ["::/0"]`) on any of these ports: `22` (SSH), `3306` (MySQL), `5432` (PostgreSQL), `6379` (Redis), `27017` (MongoDB), `9200` (Elasticsearch), `2379`/`2380` (etcd).

**HIGH — Load balancer unexpectedly public**
`aws_lb` or `aws_alb` with `internal = false` where the surrounding architecture suggests it should be internal-only (e.g., a service-to-service load balancer, a database proxy).

---

## State File Security

**HIGH — S3 backend without encryption**
`backend "s3"` block without `encrypt = true`:
```hcl
# REJECT
terraform {
  backend "s3" {
    bucket = "my-tfstate"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
    # missing: encrypt = true
  }
}
```

**HIGH — State bucket without versioning**
S3 state bucket without versioning enabled. Required for recovery from state corruption or accidental deletion.

**MEDIUM — State bucket without access logging**
S3 state bucket without `aws_s3_bucket_logging` or `aws_s3_bucket_server_access_logging` — no audit trail for who read or modified state.

---

## Audit Logging

**HIGH — No CloudTrail for account-level changes**
Changes that create or modify IAM resources, VPCs, accounts, or organization units without a corresponding `aws_cloudtrail` resource defined in the configuration or referenced as a data source (indicating it already exists).

**MEDIUM — VPC without flow logs**
`aws_vpc` resources without an `aws_flow_log` resource — no network-level audit trail for connection attempts.

**MEDIUM — S3 bucket storing sensitive data without access logging**
`aws_s3_bucket` that appears to store sensitive data (inferred from name: `logs`, `backup`, `data`, `archive`, `private`) without `aws_s3_bucket_logging`.

---

## Secrets in Variable Files

**CRITICAL — `.tfvars` with sensitive values committed**
Variable files (`.tfvars`, `.auto.tfvars`) containing literal passwords, tokens, or keys that are committed to git (detected via git history delta in the branch). These must be in `.gitignore` and sourced from a secrets manager or environment variables.

**HIGH — `locals` block deriving sensitive values from hardcoded strings**
```hcl
# REJECT
locals {
  db_url = "postgres://admin:hardcoded_password@${aws_db_instance.main.address}/mydb"
}

# REQUIRE
locals {
  db_url = "postgres://${var.db_user}:${var.db_password}@${aws_db_instance.main.address}/mydb"
}
```

---

## Authoritative References

- AWS Security Best Practices: https://docs.aws.amazon.com/security/
- CIS AWS Foundations Benchmark: https://www.cisecurity.org/benchmark/amazon_web_services
- OpenTofu sensitive variables: https://opentofu.org/docs/language/values/variables/#suppressing-values-in-cli-output
- AWS IAM least privilege: https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html
- Terraform security scanning (checkov): https://www.checkov.io/
