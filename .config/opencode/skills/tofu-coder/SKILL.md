---
name: tofu-coder
description: OpenTofu coding patterns, module structure, variable conventions, and TDD approach for infrastructure code
---

## OpenTofu TDD Approach

- Write tests using Terratest (`github.com/gruntwork-io/terratest`) when integration tests are needed
- For unit-style validation, use `tofu validate` and `tofu plan` output checks
- Always run `tofu fmt` before committing — zero tolerance for formatting issues
- Use `tflint` for linting: `tflint --recursive`

## Module Structure

```
module/
  main.tf        # primary resources
  variables.tf   # input variables with descriptions and types
  outputs.tf     # output values
  versions.tf    # required_providers and opentofu version constraints
  README.md      # module documentation
```

- Keep modules small and single-purpose
- Prefer composition over large monolithic modules
- Pin provider versions in `versions.tf` with `~>` (patch-level flexibility)

## Variable Conventions

- Every variable must have a `description`
- Use `type` constraints — never use untyped variables
- Use `validation` blocks for non-obvious constraints
- Sensitive variables must be marked `sensitive = true`
- Use `default = null` for optional variables, not empty strings

## Resource Naming

- Use snake_case for resource names
- Resource names should be descriptive: `aws_s3_bucket.user_uploads` not `aws_s3_bucket.bucket`
- Avoid hardcoding environment names in resource names — use variables

## State and Safety

- Never hardcode credentials — use environment variables or provider-level auth
- Use `tofu plan` output to verify changes before applying
- Use `lifecycle { prevent_destroy = true }` for critical resources
- Remote state with locking (S3 + DynamoDB, GCS, etc.) is required for team use

## Commit Checklist

Before proposing a commit:
1. `tofu fmt -check -recursive` returns no output
2. `tofu validate` succeeds
3. `tflint --recursive` returns no errors
4. `tofu plan` shows only intended changes
5. No sensitive values in outputs without `sensitive = true`
