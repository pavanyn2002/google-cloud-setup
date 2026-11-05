# DevOps from Scratch on Google Cloud

A hands-on path from an empty Google Cloud account to 5 company apps running on
self-managed Kubernetes, deployed by GitOps (Argo CD), with CI, security,
monitoring and cost control. Do the stages in order, one at a time; each one ends
with a "Done when" check. Don't move on until it passes.

Everything you build lives in this repo, so by the end the repo *is* your
platform, and rebuilding it from zero is one of the final tests.

## Target architecture

```
GitHub repo ──► GitHub Actions (build, test, scan, push image)
     │                         │
     │                         ▼
     │                 Artifact Registry
     ▼
  Argo CD  ◄── watches k8s manifests in Git
     │
     ▼
Kubernetes cluster (kubeadm on Compute Engine VMs, built by Terraform, then kubeadm)
  ├─ Traefik ingress + cert-manager (HTTPS)
  ├─ External Secrets ◄── GCP Secret Manager
  ├─ Prometheus + Grafana + Loki (monitoring/logs)
  ├─ Kyverno + NetworkPolicies (security)
  └─ app1 … app5  (dev and prod namespaces)
         │
         ▼
     Cloud SQL (databases)
```

## Planned repo layout

```
terraform/
  bootstrap/        # state bucket, APIs, budget
  modules/          # network, vm, registry, iam ...
  envs/dev/         # calls modules for dev
  envs/prod/
ansible/            # installs Kubernetes on the VMs
apps/app1..app5/   # app source + Dockerfile (or links to their repos)
charts/             # one shared Helm chart for all apps
gitops/             # Argo CD Applications, per-env values
platform/           # ingress, cert-manager, monitoring, policies ...
.github/workflows/  # CI pipelines
docs/               # your notes per stage
```

---

## Stage 0 - Foundations (local, free)
**Learn:** Linux shell, Git & GitHub, Docker, basic networking (IP, CIDR, DNS, ports, HTTP).
**Build:** containerize one of your 5 apps and run it with `docker compose` on your laptop.
**Done when:** you can explain what a CIDR like `10.10.0.0/24` means and your app runs in Docker.

## Stage 1 - Cloud account & tools
**Learn:** GCP projects, billing, IAM basics, `gcloud`.
**Build:** a project, a **budget alert** (very important), install `gcloud`, `terraform`, `kubectl`, `helm`, `ansible`.
**Done when:** `gcloud projects list` shows your project and a budget email alert exists.

## Stage 2 - Terraform basics
**Learn:** providers, resources, variables, outputs, `plan`/`apply`/`destroy`, **remote state**.
**Build:** `terraform/bootstrap`: a GCS bucket for Terraform state, enable APIs, a Terraform service account.
**Done when:** `terraform plan` shows no changes and state lives in the bucket, not on your laptop.

## Stage 3 - Enterprise network & IAM ("landing zone lite")
**Learn:** VPC design, subnets, firewall rules, Cloud NAT, private VMs, IAP, least-privilege IAM, separate dev/prod projects.
**Build:** `terraform/modules/network` + `envs/dev`: custom VPC, private subnet, Cloud NAT, IAP SSH, no public IPs on nodes.
**Done when:** you can SSH to a private VM through IAP and it can reach the internet only outbound.

## Stage 4 - Compute for Kubernetes with Terraform
**Learn:** modules, instance templates, service accounts for VMs, static IPs, tags.
**Build:** 1 control-plane VM + 2 worker VMs + a reserved IP + Artifact Registry, all in Terraform.
**Done when:** `terraform destroy && terraform apply` recreates everything identically.

## Stage 5 - Build Kubernetes with Ansible (native, kubeadm)
**Learn:** configuration management, idempotency, how Kubernetes is really put together (containerd, kubelet, etcd, CNI).
**Build:** first by hand (`docs/01-infrastructure.md`: a Terraform startup script prepares the nodes, you run `kubeadm init`/`join` yourself), then automate it with `ansible/` playbooks.
**Done when:** one command gives you `kubectl get nodes` → 3 `Ready` nodes.

## Stage 6 - Kubernetes fundamentals (by hand first)
**Learn:** Pods, Deployments, Services, ConfigMaps, Secrets, namespaces, probes, requests/limits, PVCs, Ingress.
**Build:** deploy app1 with plain YAML + Traefik ingress; reach it from a browser.
**Done when:** you can kill a pod/node and explain what Kubernetes did.

## Stage 7 - Containerize all 5 apps + registry
**Learn:** good Dockerfiles (multi-stage, non-root, small images), image tagging, Artifact Registry auth.
**Build:** Dockerfiles for all 5 apps, images in Artifact Registry.
**Done when:** every app image runs locally and is pushed with a version tag.

## Stage 8 - CI with GitHub Actions
**Learn:** pipelines, **Workload Identity Federation** (GitHub → GCP with no keys), tests, image scanning (Trivy).
**Build:** a reusable workflow: test → build → scan → push → bump image tag in `gitops/`.
**Done when:** a git push to app1 ends with a new scanned image in the registry, no JSON keys anywhere.

## Stage 9 - Packaging with Helm
**Learn:** templating, values per environment, one chart for many apps.
**Build:** `charts/app`: one chart used by all 5 apps; `values-dev.yaml` / `values-prod.yaml`.
**Done when:** `helm template` renders all 5 apps for both envs without copy-paste.

## Stage 10 - GitOps with Argo CD
**Learn:** declarative delivery, app-of-apps / ApplicationSets, sync, rollback, drift.
**Build:** install Argo CD (itself via Git), ApplicationSet that deploys all 5 apps to dev and prod.
**Done when:** you change a value in Git and the cluster updates by itself; `kubectl edit` changes get reverted.

## Stage 11 - Networking, DNS & TLS
**Learn:** ingress routing, DNS records, cert-manager + Let's Encrypt.
**Build:** `app1.dev.yourdomain.com` … with valid HTTPS for all apps.
**Done when:** every app has a green padlock.

## Stage 12 - Secrets & databases
**Learn:** why Git must never hold secrets; External Secrets Operator; Cloud SQL with private IP.
**Build:** secrets in GCP Secret Manager synced into the cluster; Cloud SQL via Terraform.
**Done when:** `grep -r password` in the repo finds nothing real.

## Stage 13 - Observability
**Learn:** metrics, logs, dashboards, alerts, SLOs.
**Build:** kube-prometheus-stack, Loki, Grafana dashboards per app, alerts to email/Slack.
**Done when:** stopping an app sends you an alert within minutes.

## Stage 14 - Security hardening
**Learn:** RBAC, NetworkPolicies, Pod Security Standards, policy engines, supply-chain basics.
**Build:** default-deny NetworkPolicies, Kyverno policies (no root, no `latest` tag), per-team RBAC.
**Done when:** a pod running as root is rejected by the cluster.

## Stage 15 - Scaling & reliability
**Learn:** HPA, PodDisruptionBudgets, backups (Velero + etcd snapshots), cluster upgrades, disaster recovery.
**Build:** HPAs for busy apps, nightly backups, a written upgrade runbook.
**Done when:** you upgrade Kubernetes one minor version with zero app downtime, and restore a deleted namespace from backup.

## Stage 16 - Cost (FinOps)
**Learn:** rightsizing, scheduling dev to stop at night, committed-use discounts.
**Build:** labels on everything, a cost report, dev environment auto-shutdown.
**Done when:** you can say what each app costs per month.

## Stage 17 - Capstone
1. `terraform destroy` everything.
2. Rebuild the whole platform from this repo, timing it.
3. Write a one-page architecture doc + runbook.
4. Bonus: run the same apps on GKE Autopilot and compare what you no longer manage.

---

## Progress

| Stage | Status | Notes |
|---|---|---|
| 0 Foundations | ☐ | |
| 1 Cloud account & tools | ☐ | |
| 2 Terraform basics | ☐ | |
| 3 Network & IAM | ☐ | |
| 4 Compute | ☐ | |
| 5 Kubernetes (kubeadm) | ☐ | |
| 6 K8s fundamentals | ☐ | |
| 7 Containerize apps | ☐ | |
| 8 CI | ☐ | |
| 9 Helm | ☐ | |
| 10 Argo CD | ☐ | |
| 11 DNS & TLS | ☐ | |
| 12 Secrets & DB | ☐ | |
| 13 Observability | ☐ | |
| 14 Security | ☐ | |
| 15 Reliability | ☐ | |
| 16 Cost | ☐ | |
| 17 Capstone | ☐ | |
