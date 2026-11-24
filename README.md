# google-cloud-setup

Kubernetes on Google Cloud for the company apps.

- **Production (current plan):** GKE Standard in Mumbai for Direct, Connect and Partner.
  Private nodes, one static outgoing IP for MongoDB Atlas and Supabase, Cloudflare-only
  load balancer, keyless GitHub Actions. Start with **[docs/02-gke-production.md](docs/02-gke-production.md)**.
- **Self-managed kubeadm (earlier path):** `envs/dev` + `platform/kubeadm`, kept for reference.
  Do not delete it while its VMs or state still exist.

- **[ROADMAP.md](ROADMAP.md)**: all stages, from Terraform to Argo CD, security, monitoring and cost
- **[docs/01-infrastructure.md](docs/01-infrastructure.md)**: the kubeadm path, empty project → working cluster

## Layout

```
terraform/
  bootstrap/            state bucket + APIs (run once; re-run when APIs are added)
  modules/gke-network/  VPC, pod/service ranges, Cloud NAT with a STATIC IP, IAP SSH
  modules/gke/          GKE Standard cluster + node pool (two zones, autoscaling, Workload Identity)
  modules/edge/         static Gateway IP + Cloud Armor (Cloudflare-only)
  envs/prod/            production: network, GKE, edge, registry, keyless identities, budget
  modules/network/      (kubeadm) VPC, subnet, Cloud NAT, firewall
  modules/k8s-nodes/    (kubeadm) control plane + worker VMs, node prep script
  modules/ingress-lb/   (kubeadm) static IP + load balancer to the workers
  envs/dev/             (kubeadm) the earlier dev environment
platform/
  gke/                  production namespaces + Gateway (Cloud Armor, health checks)
  kubeadm/              (kubeadm) cluster config: init (control plane) and join (workers)
  calico/               (kubeadm) pod network settings for GCP
  namespaces/           (kubeadm) dev, test and prod environments with quotas
  traefik/              (kubeadm) ingress controller settings
  smoke-test/           end-to-end test app
  install-addons.sh     (kubeadm) namespaces, storage, metrics, Traefik
scripts/
  bootstrap-cluster.sh  (kubeadm) after terraform apply: 3 VMs -> working cluster
docs/                   step-by-step guides
.claude/                Claude Code skills and plugins for this project
```
