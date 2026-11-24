# 02 · Production on GKE (Direct, Connect, Partner)

Production for the three traffic-facing backends runs on **GKE Standard** in Mumbai.
Dev and test for all products run on the Hostinger server with Coolify, so this project
holds production only. Google runs the control plane, upgrades and node repairs.

```
Cloudflare (proxied DNS, WAF)
   -> Google load balancer, static IP, Cloud Armor: Cloudflare-only     (modules/edge)
   -> GKE Gateway -> direct / connect / partner namespaces              (platform/gke)
   -> 2 private nodes, e2-standard-2, zones a + b                       (modules/gke)
   -> Cloud NAT with ONE reserved static IP -> MongoDB Atlas, Supabase  (modules/gke-network)
```

## Monthly cost (Mumbai, estimates, no free tier)

| Item | Monthly |
|---|---|
| GKE management fee ($0.10/hour) | ≈ $73 |
| 2 × e2-standard-2, on-demand | ≈ $118 |
| Node disks | ≈ $11 |
| Load balancer + static IP + Cloud Armor | ≈ $25 |
| Cloud NAT + static IP, registry, secrets, logs | ≈ $12 |
| **Total** | **≈ $225–245** |

## 1. Bootstrap (APIs)

`terraform/bootstrap` now also enables `container`, `sts` and `billingbudgets`. Re-apply it:

```sh
cd terraform/bootstrap
terraform init && terraform apply
```

## 2. Moving the registry (only if envs/dev was ever applied)

`envs/prod` manages the `apps` Artifact Registry repo. If `envs/dev` already created it,
move it instead of creating a second one:

```sh
cd terraform/envs/dev
terraform state rm google_artifact_registry_repository.apps
cd ../prod
terraform init -backend-config="bucket=YOUR_PROJECT_ID-tfstate"
terraform import google_artifact_registry_repository.apps \
  projects/YOUR_PROJECT_ID/locations/asia-south1/repositories/apps
```

If the old kubeadm VMs from `envs/dev` are running, destroy them deliberately
(`terraform plan -destroy` first) so you don't pay for both setups.

## 3. Create production

```sh
cd terraform/envs/prod
cp terraform.tfvars.example terraform.tfvars   # fill in project_id (and billing_account)
terraform init -backend-config="bucket=YOUR_PROJECT_ID-tfstate"
terraform plan
terraform apply
```

Then use the outputs:

| Output | What to do with it |
|---|---|
| `nat_ip` | Add to **MongoDB Atlas** Network Access and **Supabase** network restrictions |
| `gateway_ip` | Point the production API hostnames here in **Cloudflare** (proxied) |
| `get_credentials` | Run it to get `kubectl` access through the DNS endpoint (IAM-authorised) |
| `github_wif_provider`, `github_ci_service_account` | Use in GitHub Actions `google-github-actions/auth` (no keys) |
| `external_secrets_service_account` | Annotate the `external-secrets/external-secrets` Kubernetes service account |
| `coolify_puller_service_account` | Create its key by hand for the Coolify servers (below) |

## 4. Cluster add-ons

```sh
kubectl apply -f platform/gke/namespaces.yaml

# External Secrets Operator (reads Secret Manager through Workload Identity)
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace \
  --set serviceAccount.annotations."iam\.gke\.io/gcp-service-account"=<external_secrets_service_account>

# Argo CD (deploys only what is approved in Git)
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd -n argocd --create-namespace

# Gateway: create the Cloudflare origin cert secret first (see the file header)
kubectl apply -f platform/gke/gateway.yaml
```

Pin chart versions (`--version`) once you've chosen them, and keep the values in Git.

## 5. GitHub Actions (keyless)

```yaml
permissions:
  id-token: write
  contents: read
steps:
  - uses: google-github-actions/auth@v2
    with:
      workload_identity_provider: <github_wif_provider>
      service_account: <github_ci_service_account>
  - run: gcloud auth configure-docker asia-south1-docker.pkg.dev --quiet
```

## 6. Coolify servers (pull-only key)

```sh
gcloud iam service-accounts keys create coolify-puller.json \
  --iam-account=<coolify_puller_service_account>
# copy to each Coolify server, then on the server (root only):
#   chmod 600 coolify-puller.json
#   cat coolify-puller.json | docker login -u _json_key --password-stdin https://asia-south1-docker.pkg.dev
# delete the local copy; rotate every 90 days
```

## Safety switches

- `deletion_protection = true` on the cluster: set it to `false` and apply before any destroy.
- Node autoscaling is capped at 2 per zone; the budget alert fires at 50/90/100% of $250.
- Upgrades happen automatically in the Tue–Thu night window (02:00–06:00 IST).
