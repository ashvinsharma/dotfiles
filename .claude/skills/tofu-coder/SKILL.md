---
name: tofu-coder
description: OpenTofu coding patterns, module structure, variable conventions, and TDD approach for infrastructure code
---

## HARD RULE: Never delete Tofu-managed resources directly

**Never** delete a resource that was created by OpenTofu (or Terraform) directly via AWS CLI,
console, or any out-of-band mechanism. Always destroy through `tofu destroy` or the application
API that wraps it.

**Why:** OpenTofu tracks resource state in a state file (local or remote S3/GCS). Deleting a
resource directly leaves the state file believing the resource still exists. The next `tofu plan`
will be confused, the next `tofu destroy` will error, and the state is now corrupted. Recovery
requires manual `tofu state rm` or state surgery — both are risky and time-consuming.

**The only safe path:**
1. Run `tofu destroy` (or the application's DELETE API endpoint that calls it)
2. Tofu deprovisions the resource in the cloud provider
3. Tofu removes the resource from state
4. State and reality are in sync

If a resource is orphaned (exists in AWS but has no state / no DB record), treat it as a data
integrity incident. Investigate how it was orphaned before touching anything. Do not delete it
out-of-band without explicit human approval and a plan to also clean up the state.

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
