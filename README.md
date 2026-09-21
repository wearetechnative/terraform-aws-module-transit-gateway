# terraform-aws-module-template

![](https://img.shields.io/github/actions/workflow/status/wearetechnative/terraform-aws-module-template/lint.yaml?branch=main&style=plastic)
![](https://img.shields.io/github/actions/workflow/status/wearetechnative/terraform-aws-module-template/security-scan.yaml?branch=main&style=plastic&label=security)

Starting point for a Terraform module in this organisation. Everything that
previously drifted between repositories — the workflows, the ignore rules, the
`terraform` block — is already correct here.

## After creating a repository from this template

- [ ] Replace `terraform-aws-module-template` in both badge URLs above with the
      new repository name. The URL contains the repository name, so the badges
      point at this template until you change them.
- [ ] Replace this README's title and description.
- [ ] Adjust `required_version` and `required_providers` in `versions.tf` to
      what the module actually needs.
- [ ] If the module declares `configuration_aliases`, add
      `skip-validate: true` to `.github/workflows/lint.yaml`. Such a module
      cannot be validated as a root module: there is no aliased provider
      configured, so `terraform validate` reports `missing provider` by design.
- [ ] Use `git::https://github.com/...` for any module source. Never
      `git@github.com:` — a runner has no SSH key, and a source that needs one
      only works on a developer's machine.

## What the CI does

| Check                   | Tool                 | Blocks on                        |
| ----------------------- | -------------------- | -------------------------------- |
| `lint / tflint`         | TFLint v0.64.0       | findings, when `strict: true`    |
| `lint / validate`       | `terraform validate` | any error                        |
| `security-scan / trivy` | Trivy config scan    | the severities in `block-on`     |

Both workflows are thin callers. The steps live in
[`reusable_workflow_terraform`](https://github.com/wearetechnative/reusable_workflow_terraform),
pinned at `@v1`, so tool versions and action pins are changed in one place
rather than in every module.

This template ships with `strict: true` and `block-on: HIGH,CRITICAL` because a
new module has nothing to clean up yet. Start blocking and stay there.

## Running the checks locally

```bash
nix run nixpkgs/nixos-unstable#tflint -- --recursive -f compact
nix run nixpkgs/nixos-unstable#trivy  -- config --severity HIGH,CRITICAL .
terraform init -backend=false && terraform validate
```

Use `tfswitch <version>` if your installed terraform is older than the module's
`required_version`.
