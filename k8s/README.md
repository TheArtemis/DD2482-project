# Kubernetes deployment

## Install Argo CD (AKS)

Argo CD is installed once per cluster. Connect `kubectl` to the AKS cluster
first, then install the upstream stable manifests and register this repository's
application after creating the database secret:

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
image. The namespace is declared in Kustomize; the secret bootstrap below
creates it before Argo CD's first sync.

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
5. Allow GitHub Actions to push the release commit to `main`. If branch
   protection disallows that, the release workflow's final push will fail and
   the Argo CD desired state will stay on the previous image.

The workflow skips bot-authored pushes so a desired-state commit cannot start a
second release.

## Sync hooks

The `PreSync` migration Job runs `alembic upgrade head` from the same SHA-tagged
image before Argo CD updates the Deployment. The `PostSync` smoke-test Job creates
a temporary link, verifies the redirect destination, and deletes the link after
the Deployment becomes healthy. A failed hook leaves the Argo CD sync unhealthy
for inspection. Both jobs read `DATABASE_URL` from `url-shortener-config`.

## Runtime database secret setup

```bash
kubectl create namespace url-shortener --dry-run=client -o yaml | kubectl apply -f -

DATABASE_URL="$(az keyvault secret show \
  --vault-name urlshortener-pf9nt4-kv \
  --name database-url \
  --query value \
  --output tsv)"

kubectl create secret generic url-shortener-config \
  --namespace url-shortener \
  --from-literal=DATABASE_URL="$DATABASE_URL" \
  --dry-run=client \
  -o yaml | kubectl apply -f -
```

Register the application after the secret exists:

```bash
kubectl apply -f argocd/application.yaml
```

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
