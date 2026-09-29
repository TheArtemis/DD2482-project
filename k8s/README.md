# Kubernetes deployment

RUntime database secrets init

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

Deploy:

```bash
kubectl apply -k k8s
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
