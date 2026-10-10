# Snip — URL shortener

A URL-shortening application hosted on Microsoft Azure, built with FastAPI,
SQLAlchemy, Alembic, PostgreSQL, and a dependency-free browser frontend.

## Open the application online

Snip runs on Azure Kubernetes Service (AKS) and is accessible in a browser through
the public IP address of its Azure LoadBalancer Service. Open
`http://<external-ip>` to use the application, or `http://<external-ip>/docs` for
interactive API documentation.

Deployment operators can retrieve the public IP from the AKS cluster with:

```bash
kubectl get service url-shortener -n url-shortener
```

Use the address in the `EXTERNAL-IP` column in place of `<external-ip>`.

## API

| Method | Path | Description |
|---|---|---|
| `POST` | `/links` | Create a short link |
| `GET` | `/{code}` | Redirect and increment the counter |
| `GET` | `/links/{code}/stats` | Read link statistics |
| `DELETE` | `/links/{code}` | Disable a short link |
| `GET` | `/health/live` | Process liveness |
| `GET` | `/health/ready` | Database readiness |
| `GET` | `/version` | Deployed Git SHA/version |

Example:

```bash
curl -sS 'http://<external-ip>/links' \
  -H 'content-type: application/json' \
  -d '{"destination_url":"https://example.com/a/long/path"}'
```

Deleting a link disables its redirect while retaining its statistics. The API
emits structured request logs and returns an `x-request-id` response header.

## Azure infrastructure and deployment

Terraform provisions AKS, Azure Container Registry (ACR), networking, Azure
Database for PostgreSQL, and Azure Key Vault. The state-storage configuration is
in `infrastructure/bootstrap-state/`, and the application infrastructure is in
`infrastructure/terraform/`.

GitHub Actions builds and scans commit SHA-tagged container images, publishes
them to ACR, and updates the production deployment configuration in Git. Argo CD
reconciles that configuration with AKS, running database migrations before the
application rollout and a smoke test after the deployment becomes healthy.

The Kubernetes base and production overlay are in `k8s/`. To bootstrap Argo CD
in AKS and register the application for GitOps deployment, follow [the Kubernetes deployment guide](k8s/README.md).

### Set up your own Azure deployment

In case you would like to deploy the application into your Azure follow this list of rules.
You need an Azure subscription with available credits and permission to create
resources and assign roles, plus Azure CLI, Terraform (1.8+), kubectl, and Docker.
Run the following steps from the repository root:

1. Sign in with `az login`, select your subscription with
   `az account set --subscription <subscription-id>`, and export
   `ARM_SUBSCRIPTION_ID=<subscription-id>`. Create a resource group or use an
   existing one. Ensure the required Azure resource providers are registered;
   Terraform does not register them automatically.
2. Copy each module's `terraform.tfvars.example` to `terraform.tfvars`. Set your
   resource group, an allowed Azure region, and your public IPv4 address.
   Set `aks_api_authorized_ip_ranges` to administrator/cluster egress CIDRs or
   `[]` for unrestricted network access to the AKS management API. This setting
   is separate from public access to the URL shortener.
3. Run `terraform init` and `terraform apply` in
   `infrastructure/bootstrap-state` to create state storage. Your Terraform
   identity needs **Storage Blob Data Contributor** access to this storage
   (including during bootstrap). Save its `backend_config` output to a local
   file, then run `terraform init -backend-config=<absolute-path-to-file>` and
   `terraform apply` in `infrastructure/terraform`. Keep Terraform state private
   and back up the bootstrap module's local state.
4. Use the Terraform outputs to update the registry image references under
   `k8s/`, the Workload Identity client ID in `k8s/base/service-account.yaml`,
   and the client ID, tenant ID, and vault name in
   `k8s/base/secret-provider-class.yaml`. Build and publish the application image
   to your ACR, and set its tag and matching `GIT_SHA` in the production overlay.
5. Point `argocd/application.yaml` at your repository, commit the deployment
   configuration, and follow the [Argo CD installation steps](k8s/README.md#install-argo-cd-aks)
   and [CSI configuration steps](k8s/README.md#key-vault-csi-configuration).
   Register the application with `kubectl apply -f argocd/application.yaml`.
   Once the deployment is healthy, retrieve the Service's `EXTERNAL-IP` and open
   `http://<external-ip>` to try the shortener.

## Automated quality and security checks

GitHub Actions runs unit and integration tests, Ruff formatting and lint checks,
and ty type checks. It also validates Terraform and Kubernetes configuration,
builds the container image, and runs Gitleaks and Trivy security scans. Dependabot
proposes updates to Python dependencies and GitHub Actions.

Python dependencies are declared in `pyproject.toml` and resolved reproducibly
by the committed `uv.lock`.

## Layout

- `app/api`: HTTP routes and request/response models
- `app/db`: SQLAlchemy model and session setup
- `app/services`: short-code and link business logic
- `app/web`: responsive HTML/CSS/JavaScript frontend
- `migrations`: Alembic database migrations
- `tests`: unit and API tests
- `infrastructure`: Terraform state storage and Azure resource definitions
- `k8s`: Kubernetes base resources and production overlay
- `argocd`: GitOps application configuration
- `.github/workflows`: automated checks and release pipeline
