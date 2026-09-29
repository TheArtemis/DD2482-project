# Infrastructure security changes

## Why these changes were made

The [Security scans CI job](https://github.com/TheArtemis/DD2482-project/actions/runs/36586665696/job/109468720813) ran Trivy's infrastructure configuration scan successfully, then failed because it found four HIGH or CRITICAL Terraform misconfigurations. The project's [architecture](docs/architecture.md) calls for Trivy Config (or Checkov) to check Terraform and for configured security findings to fail CI.

| Trivy finding | Cause | Change |
| --- | --- | --- |
| `AZU-0012` | Terraform state storage had no network rules, so its public endpoint allowed access from any source with valid credentials. | Added storage network rules with `default_action = "Deny"` and an allow rule for the Terraform operator's public IP. |
| `AZU-0041` | The AKS API server had no authorized IP ranges. | Added `api_server_access_profile` with required authorized CIDR ranges. |
| `AZU-0042` | Kubernetes RBAC was not explicitly enabled in the AKS configuration. | Set `role_based_access_control_enabled = true`. |
| `AZU-0013` | Key Vault had no network ACL denying unmatched traffic. | Added an ACL with `default_action = "Deny"` that allows the Terraform operator's public IP and the AKS subnet. |

The AKS subnet now has a `Microsoft.KeyVault` service endpoint so workloads in that subnet can reach Key Vault through its subnet rule. The storage account and Key Vault still allow trusted Azure services to bypass their network rules; callers must also have the required identity permissions.

## Values required before applying Terraform

Both Terraform modules now require `operator_public_ip`, a single public IPv4 address **without** a `/32` suffix. Set it to the public address of the machine that runs Terraform. The bootstrap module uses it for state storage access; the main module uses it for Key Vault access. The main module also requires `aks_api_authorized_ip_ranges`, a nonempty list of IPv4 CIDR ranges that includes the administrator's address and the cluster's egress address. `0.0.0.0/0` is rejected.

See `infrastructure/bootstrap-state/terraform.tfvars.example` and `infrastructure/terraform/terraform.tfvars.example` for the variable names and example syntax. Replace the example addresses with real values. If the operator's public IP changes, update the allow rules before relying on access from the new address. Review the Terraform plan and confirm that state storage, Key Vault, and AKS API access will remain available before applying it to the existing deployment.

## Verification and deployment status

Both Terraform modules passed `terraform validate`, and the files passed `terraform fmt -check`. A local Trivy 0.70.0 configuration scan of `infrastructure` reported zero HIGH or CRITICAL findings with `--exit-code 1`. Trivy warned that the new required variables had no local values, so the scan confirms the policy declarations while the actual allowed addresses must be supplied before an apply.

No Terraform apply or Azure resource change was performed. No application tests were run. GitHub Actions will run the updated scan again when these changes are pushed.
