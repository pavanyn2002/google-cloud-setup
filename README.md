# google-cloud-setup

A self-managed (native, kubeadm) Kubernetes platform on Google Cloud for 5 company
apps, built step by step as a DevOps learning project.

- **[ROADMAP.md](ROADMAP.md)**: all stages, from Terraform to Argo CD, security, monitoring and cost
- **[docs/01-infrastructure.md](docs/01-infrastructure.md)**: start here: empty project → working cluster

## Layout

```
terraform/
  bootstrap/            state bucket + APIs (run once)
  modules/network/      VPC, subnet, Cloud NAT, firewall
  modules/k8s-nodes/    control plane + worker VMs, node prep script
  modules/ingress-lb/   static IP + load balancer to the workers
  envs/dev/             the dev environment
platform/
  calico/               pod network settings for GCP
  traefik/              ingress controller settings
  smoke-test/           end-to-end test app
docs/                   step-by-step guides
.claude/                Claude Code skills and plugins for this project
```
