# Kubernetes deployment

## Install Argo CD (AKS)

Argo CD is installed once per cluster. Connect `kubectl` to the AKS cluster
first, then install the upstream stable manifests and register this repository's
application. Terraform enables the Azure Key Vault Secrets Store CSI Driver
add-on on AKS; no database value is copied manually into the cluster:

```bash
az aks get-credentials \
  --resource-group <resource-group> \
  --name <aks-cluster-name>

kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl rollout status deployment/argocd-server -n argocd --timeout=5m
```

The Argo CD `Application` watches `main` at `k8s/overlays/production`, uses
Kustomize, and automatically syncs, prunes removed resources, and repairs live
drift. The production overlay uses an immutable source commit SHA for the app
image. During the `Sync` phase, the namespace is applied at wave `-3`, followed
by the Workload Identity ServiceAccount and SecretProviderClass at wave `-2`.
These resources are available before the migration Job at wave `-1`, allowing
it to retrieve its database connection on the first Argo CD synchronization.

For the initial login, port-forward the API server and retrieve the generated
admin password:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# In another terminal:
argocd admin initial-password -n argocd
argocd login localhost:8080 --username admin --password '<initial-password>' --insecure
```

Open <https://localhost:8080> for the web UI. Change the initial password after
logging in. To inspect reconciliation, run `kubectl get applications -n argocd`
or `argocd app get url-shortener`.

The common resources live in `k8s/base/`; production-specific settings live in
`k8s/overlays/production/`. The release workflow builds and pushes the commit
SHA-tagged image, then commits that tag and `GIT_SHA` to the production overlay.
Ensure `url-shortener-config` exists in the `url-shortener` namespace before the
application starts (see below).

## Configure automated releases

The `.github/workflows/release.yml` workflow uses Azure OIDC; it does not need a
client secret. Before merging to `main`:

1. Create an Entra application/service principal and add a federated credential
   with issuer `https://token.actions.githubusercontent.com`, subject
   `repo:TheArtemis/DD2482-project:ref:refs/heads/main`, and audience
   `api://AzureADTokenExchange`.
2. Assign the service principal the `AcrPush` role on the project ACR.
3. Add these GitHub Actions repository secrets: `AZURE_CLIENT_ID`,
   `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID`.
4. Add the repository Actions variable `ACR_NAME` with the registry resource
   name (not its login server URL).
5. Create a dedicated GitHub App with repository **Contents: Read and write**
   permission and install it on this repository. Add its client ID as the
   Actions variable `RELEASE_APP_CLIENT_ID` and its private key as the Actions
   secret `RELEASE_APP_PRIVATE_KEY`. The workflow generates a temporary,
   repository-scoped installation token for its desired-state commit.
6. Protect `main` with required developer PRs, reviews, and CI checks. Give only
   the release App an **Always** bypass for the rules that would block its
   direct desired-state commit (including required PRs and checks), and allow
   it to push if push restrictions are enabled. Do not grant this exception to
   developers. The workflow stages only the two production image/version files
   and never force-pushes. Contents write permission alone does not bypass
   branch protection.

See GitHub's [App-token setup guide](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/making-authenticated-api-requests-with-a-github-app-in-a-github-actions-workflow)
and [ruleset bypass configuration](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets).

Developers work on feature branches and merge reviewed PRs. A push to `main`
runs the same quality, security, and configuration workflows via `workflow_call`;
the release job requires all three to succeed on that exact commit. PR checks
still run independently and should remain required merge gates. Only the release
job receives Azure OIDC permission and the release App credentials.

Before publishing, the workflow verifies that `main` still points at the source
commit, validates both manifest replacements, then builds and scans the release
image. It pushes that same image to ACR and commits the tag and `GIT_SHA` directly
to `main` with the release App token. The bot commit does not require a second PR.
If `main` advances during release, the normal Git push fails instead of overwriting
newer changes; the newer commit's workflow provides the next release.

The release trigger excludes pushes changing only `k8s/overlays/production/**`.
This prevents a desired-state commit or an overlay-only rollback from publishing
another image, regardless of which identity authored it. PR checks still validate
overlay changes. Configure Argo CD separately before expecting these commits to
deploy the application.

## Sync hooks

Argo CD orders resources by phase first, then by wave within each phase. The
migration Job is a `Sync` hook at wave `-1`. It runs `alembic upgrade head` from
the same SHA-tagged image and must succeed before Argo CD proceeds to the
Deployment and Service at the default wave `0`. A failed migration prevents
the application rollout from proceeding.

The `PostSync` smoke-test Job creates
a temporary link, verifies the redirect destination, and deletes the link after
the Deployment becomes healthy. A failed hook leaves the Argo CD sync unhealthy
for inspection. The migration Job and Deployment mount the Key Vault CSI volume.
The `SecretProviderClass` mirrors Key Vault's `database-url` value into the
`url-shortener-config` Kubernetes Secret as the `DATABASE_URL` key expected by
the application.

## Key Vault CSI configuration

Terraform creates the Key Vault secret, Workload Identity, federated credential,
and least-privilege `Key Vault Secrets User` assignment. It also enables the AKS
CSI add-on and automatic secret rotation. The non-secret identifiers in
`k8s/base/service-account.yaml` and `k8s/base/secret-provider-class.yaml` must
match these Terraform outputs:

```bash
terraform -chdir=infrastructure/terraform output -raw key_vault_name
terraform -chdir=infrastructure/terraform output -raw tenant_id
terraform -chdir=infrastructure/terraform output -raw workload_identity_client_id
```

If Terraform recreates the Key Vault or Workload Identity, update those
identifiers before releasing. They are identifiers, not credentials; the
database URL remains only in Terraform's protected remote state, Key Vault, and
the CSI-managed Kubernetes Secret.

After applying the infrastructure, verify the add-on before registering the
Argo CD application:

```bash
az aks show \
  --resource-group <resource-group> \
  --name <aks-cluster-name> \
  --query addonProfiles.azureKeyvaultSecretsProvider.enabled

kubectl get csidriver secrets-store.csi.k8s.io
```

Register the application; its first sync creates and mounts the
SecretProviderClass, which in turn creates `url-shortener-config`:

```bash
kubectl apply -f argocd/application.yaml
kubectl get secretproviderclass -n url-shortener
kubectl get secret url-shortener-config -n url-shortener
```

CSI rotation refreshes the mounted content and synchronized Kubernetes Secret.
Because `DATABASE_URL` is consumed as an environment variable, running
containers pick up a rotated value on their next restart or rollout.

Manual render/apply (Argo CD normally owns this step):

```bash
kubectl apply -k k8s/overlays/production
```

Rollout:

```bash
kubectl rollout status deployment/url-shortener -n url-shortener
kubectl get service url-shortener -n url-shortener
```

Smoke test:

```bash
curl http://<external-ip>/health/live
curl http://<external-ip>/health/ready
```

# Utilities

Inside scripts folder use:

```bash
./azure-services.sh start
./azure-services.sh status
./azure-services.sh stop
```
