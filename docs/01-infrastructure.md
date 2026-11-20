# Guide 1: From an empty project to a working Kubernetes cluster

Covers roadmap Stages 1–6. At the end you will have:

- a private network on Google Cloud, built with Terraform
- 3 VMs (1 control plane, 2 workers, all e2-medium) with no public IPs
- a native Kubernetes cluster you built yourself with `kubeadm`
- `dev`, `test` and `prod` namespaces, each with its own resource quota
- one public IP that routes web traffic into the cluster
- a private registry for your 5 apps' images

Run every command **on your laptop** unless the step says **(on cp-1)** or
**(on each worker)**. Read the comments: they explain *why*, which is the part
that matters for interviews and real work.

```
Internet ──► Static IP + Network Load Balancer (TCP 80/443)
                       │
        ┌──────────────┴──────────────┐
        ▼                             ▼
   worker-1 (Traefik :80/:443)   worker-2 (Traefik :80/:443)
        │   pods for app1..app5       │
        └──────── VPC 10.10.0.0/24 ───┘
                       │
                    cp-1 (API server, etcd)  ◄── you, via IAP tunnel
                       │
                  Cloud NAT ──► internet (apt, image pulls)
```

**Cost while running:** about US$120/month (3 VMs + load balancer + NAT).
Step 10 shows how to stop the VMs when you're not using them.

---

## Step 1: Tools and login

Install on your laptop: `gcloud`, `terraform` (1.9+), `kubectl`, `helm`, `git`.
On Windows, do all of this inside WSL2 (Ubuntu).

```bash
gcloud auth login
gcloud auth application-default login     # credentials Terraform uses
gcloud config set project YOUR_PROJECT_ID
gcloud auth application-default set-quota-project YOUR_PROJECT_ID
```

Make sure billing is linked and a **budget alert** exists (Billing → Budgets & alerts).

Clone this repo and work from its root:

```bash
git clone https://github.com/pavanyn2002/google-cloud-setup.git
cd google-cloud-setup
```

## Step 2: Bootstrap (state bucket + APIs) - once per project

Terraform records what it created in a *state file*. Keeping it in a GCS bucket
(not on your laptop) means it's backed up, versioned and shareable with a team.

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars    # then edit project_id
terraform init
terraform plan      # read it: what will be created?
terraform apply
cd ../..
```

Note the `state_bucket` output (`YOUR_PROJECT_ID-tfstate`).

> This one config keeps its own state locally in `terraform/bootstrap/terraform.tfstate`.
> It's tiny and git-ignored; don't delete it.

## Step 3: Build the network, VMs, load balancer and registry

```bash
cd terraform/envs/dev
cp terraform.tfvars.example terraform.tfvars    # then edit project_id
terraform init -backend-config="bucket=YOUR_PROJECT_ID-tfstate"
terraform plan
terraform apply
terraform output
cd ../../..
```

What just happened (open each file and read it):

| File | Creates |
|---|---|
| `modules/network/main.tf` | VPC, subnet, Cloud NAT, 3 firewall rules |
| `modules/k8s-nodes/main.tf` | node service account, cp-1, worker-1, worker-2 |
| `modules/k8s-nodes/node-prep.sh.tftpl` | startup script: containerd + kubeadm on each VM |
| `modules/ingress-lb/main.tf` | static IP + load balancer to the workers |
| `envs/dev/main.tf` | wires the modules together + Artifact Registry |

## Fast path: Steps 4–7 and the add-ons in one command

```bash
./scripts/bootstrap-cluster.sh
```

It waits for the VMs, creates the control plane, joins both workers and installs
the add-ons (about 10 minutes). It only copies `platform/` to each VM and runs the
small scripts in it, so read those to see exactly what happens. Then go to Step 8.

**Learning for the CKA?** Do Steps 4–7 by hand instead, at least once. They are
the same commands the scripts run.

## Step 4: Wait for the nodes to finish preparing

The startup script takes 2–4 minutes after the VMs boot. Check each node:

```bash
for vm in k8s-dev-cp-1 k8s-dev-worker-1 k8s-dev-worker-2; do
  gcloud compute ssh $vm --zone=asia-south1-a --tunnel-through-iap \
    --command='test -f /var/lib/k8s-node-prep.done && echo "$(hostname): ready" || echo "$(hostname): not yet"'
done
```

If one stays "not yet", read its log:

```bash
gcloud compute ssh k8s-dev-cp-1 --zone=asia-south1-a --tunnel-through-iap \
  --command='sudo journalctl -u google-startup-scripts --no-pager | tail -50'
```

## Step 5: Create the control plane (on cp-1)

The cluster's settings live in `platform/kubeadm/init-config.yaml` (open it: every
line is explained). Copy the `platform/` folder to cp-1, then log in:

```bash
gcloud compute scp --recurse platform k8s-dev-cp-1:~/ --zone=asia-south1-a --tunnel-through-iap
gcloud compute ssh k8s-dev-cp-1 --zone=asia-south1-a --tunnel-through-iap
```

Then, **on cp-1**:

```bash
cd ~/platform/kubeadm
sudo kubeadm config validate --config init-config.yaml   # catches typos before anything is created
sudo kubeadm init --config init-config.yaml

mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown "$(id -u):$(id -g)" $HOME/.kube/config
kubectl get nodes        # cp-1 shows NotReady: there's no pod network yet
```

**Copy the `kubeadm join ...` command** it prints at the end; you need it in Step 7.

## Step 6: Install the pod network: Calico (on cp-1)

Pods on different nodes need a network between them. Calico provides it (and
NetworkPolicies, which you'll use in Stage 14).

```bash
CALICO=v3.33.1   # check https://github.com/projectcalico/calico/releases for newer
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/$CALICO/manifests/operator-crds.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/$CALICO/manifests/tigera-operator.yaml
```

The Calico settings must use VXLAN on Google Cloud (the file explains why):

```bash
kubectl create -f ~/platform/calico/installation.yaml
watch kubectl get pods -n calico-system      # wait until all are Running, then Ctrl+C
kubectl get nodes                            # cp-1 is now Ready
```

## Step 7: Join the workers (on each worker)

```bash
gcloud compute ssh k8s-dev-worker-1 --zone=asia-south1-a --tunnel-through-iap
sudo kubeadm join 10.10.0.X:6443 --token ... --discovery-token-ca-cert-hash sha256:...   # from Step 5
exit
```

Repeat for `k8s-dev-worker-2`. Lost the join command, or more than 24h passed?
Make a new one **on cp-1**: `sudo kubeadm token create --print-join-command`.

The same join written as a config file is `platform/kubeadm/join-config.yaml`;
`join-worker.sh` fills in its three values and runs `kubeadm join --config`.

On cp-1: `kubectl get nodes` should show 3 nodes, all `Ready`.

## Step 8: Use kubectl from your laptop

The API server has no public IP. An IAP tunnel forwards it to `localhost:6443`.

```bash
# copy the admin kubeconfig to your laptop (it is cluster-admin: keep it private, never commit it)
mkdir -p ~/.kube
gcloud compute ssh k8s-dev-cp-1 --zone=asia-south1-a --tunnel-through-iap \
  --command='sudo cat /etc/kubernetes/admin.conf' > ~/.kube/gcp-dev.conf
sed -i.bak 's#server: https://.*:6443#server: https://127.0.0.1:6443#' ~/.kube/gcp-dev.conf
chmod 600 ~/.kube/gcp-dev.conf
```

Open the tunnel in **a separate terminal** and leave it running:

```bash
gcloud compute start-iap-tunnel k8s-dev-cp-1 6443 --local-host-port=localhost:6443 --zone=asia-south1-a
```

Back in your main terminal:

```bash
export KUBECONFIG=~/.kube/gcp-dev.conf
kubectl get nodes -o wide
```

From here on, every `kubectl`/`helm` command runs on your laptop.

## Step 9: Cluster add-ons

A bare kubeadm cluster has no storage, no metrics and no ingress.
`platform/install-addons.sh` adds them (the fast path already ran it). By hand:

```bash
# Environments: dev, test and prod namespaces, each with a quota
kubectl apply -f platform/namespaces/environments.yaml

# Storage: a default StorageClass so PersistentVolumeClaims work (data lives on the node's disk)
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.30/deploy/local-path-storage.yaml
kubectl patch storageclass local-path \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Metrics: needed for `kubectl top` and autoscaling.
# --kubelet-insecure-tls because kubeadm's kubelet certificates are self-signed.
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# Ingress: Traefik on ports 80/443 of every worker (see platform/traefik/values.yaml)
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm upgrade --install traefik traefik/traefik -n traefik --create-namespace \
  -f platform/traefik/values.yaml
```

Check:

```bash
kubectl get pods -A          # everything Running
kubectl top nodes            # works after ~1 minute
kubectl get storageclass     # local-path (default)
```

### The end-to-end test

```bash
kubectl apply -f platform/smoke-test/whoami.yaml
INGRESS_IP=$(terraform -chdir=terraform/envs/dev output -raw ingress_ip)
curl http://$INGRESS_IP/whoami
```

You should see a reply showing the pod's hostname. Run it a few times: the
hostname changes as traffic is spread across both pods. **That's the internet
reaching a pod in your own Kubernetes cluster.** Clean up:

```bash
kubectl delete -f platform/smoke-test/whoami.yaml
```

If curl hangs: the load balancer health check needs a minute after Traefik starts.
Check it with `gcloud compute backend-services get-health k8s-dev-backend --region=asia-south1`.

## Step 10: Save money when you're not practising

```bash
# stop (you keep paying only for disks, the IP and the load balancer)
gcloud compute instances stop k8s-dev-cp-1 k8s-dev-worker-1 k8s-dev-worker-2 --zone=asia-south1-a
# start again later: the cluster comes back by itself in a few minutes
gcloud compute instances start k8s-dev-cp-1 k8s-dev-worker-1 k8s-dev-worker-2 --zone=asia-south1-a
```

Tear everything down (the state bucket stays):

```bash
terraform -chdir=terraform/envs/dev destroy
```

---

## Done when

- [ ] `kubectl get nodes` from your laptop shows 3 `Ready` nodes
- [ ] `curl http://<ingress_ip>/whoami` answers
- [ ] you can explain what each Terraform module creates and why the nodes have no public IPs
- [ ] you've done `terraform destroy` + `apply` + Steps 4–9 once more from memory

Next: **Guide 2: deploy your first app** (Dockerfile → Artifact Registry → Deployment, Service, Ingress).
