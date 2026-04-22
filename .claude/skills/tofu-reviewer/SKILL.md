---
name: tofu-reviewer
description: OpenTofu code review checklist covering security, state safety, module design, and idiomatic patterns
---

## Mandatory Checks for OpenTofu Code

Run these before reviewing:
```bash
tofu fmt -check -recursive    # must return no output
tofu validate                 # must succeed
tflint --recursive            # must return no errors
```

## Security

- REJECT if credentials, secrets, or API keys appear anywhere in .tf files
- REJECT if sensitive outputs are missing `sensitive = true`
- REJECT if IAM policies are overly permissive (`*` actions or resources without justification)
- REJECT if security group rules allow `0.0.0.0/0` ingress without explicit justification
- ESCALATE if auth/encryption/PII infrastructure — needs architectural review

## State Safety

- REJECT if `terraform_remote_state` is used without proper access controls
- REJECT if state is local-only for code that will be used by a team
- REJECT if critical resources lack `lifecycle { prevent_destroy = true }`
- REJECT if `count` is used where `for_each` would be safer (avoids index-based state churn)

## Module Design

- REJECT if a module does too many unrelated things (violates single responsibility)
- REJECT if variables lack `description` or `type`
- REJECT if provider versions are unpinned or too broadly pinned (`>= X`)
- REJECT if outputs are missing for values other modules would reasonably need
- ESCALATE if module boundaries or API design needs architectural input

## Idiomatic Patterns

- REJECT if hardcoded environment names appear in resource names (use variables)
- REJECT if `count` is used for conditional resource creation where `count = var.enabled ? 1 : 0` pattern is unclear — prefer explicit `for_each = toset(var.enabled ? ["enabled"] : [])`
- REJECT if data sources are used where they could cause implicit dependencies on unmanaged resources
- Flag `null_resource` usage — often a sign of workaround that needs cleaner design

## Documentation

- REJECT if a new module lacks a README.md
- REJECT if complex variable constraints have no `validation` block with a helpful error message

## Authoritative Sources to Cite

- OpenTofu docs: https://opentofu.org/docs/
- OpenTofu language reference: https://opentofu.org/docs/language/
- Gruntwork Terraform Best Practices: https://www.gruntwork.io/guides/foundations/terraform/
