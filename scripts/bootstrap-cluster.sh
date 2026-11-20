#!/bin/bash
# Run ON YOUR LAPTOP, from anywhere in this repo, after `terraform apply`.
# Turns the 3 prepared VMs into a working cluster:
#
#   1. waits for every VM's startup script to finish
#   2. creates the control plane on cp-1 and installs Calico
#   3. joins worker-1 and worker-2
#   4. installs namespaces, storage, metrics and Traefik
#
# It only copies files and runs the small scripts in platform/ over SSH, so you
# can read exactly what happens on each node. Safe to run again.
#
#   ./scripts/bootstrap-cluster.sh
#
# Needs: gcloud logged in, with the project set (gcloud config set project ...).
# Your account needs IAP tunnel access and OS Login with sudo (project Owner has both).
set -euo pipefail
cd "$(dirname "$0")/.."

PREFIX="${PREFIX:-k8s-dev}"
ZONE="${ZONE:-asia-south1-a}"
WORKER_COUNT="${WORKER_COUNT:-2}"

CP="$PREFIX-cp-1"
WORKERS=()
for i in $(seq 1 "$WORKER_COUNT"); do
  WORKERS+=("$PREFIX-worker-$i")
done

# Run a command on a VM through the IAP tunnel (the VMs have no public IP).
on() {
  local vm="$1"
  shift
  gcloud compute ssh "$vm" --zone "$ZONE" --tunnel-through-iap --quiet \
    --command "$*" </dev/null
}

# Copy the platform/ folder to a VM's home directory.
copy_platform() {
  gcloud compute scp --recurse platform "$1:~/" \
    --zone "$ZONE" --tunnel-through-iap --quiet
}

echo "### 1/4 Waiting for the VMs to finish preparing (containerd, kubeadm, kubelet)"
for vm in "$CP" "${WORKERS[@]}"; do
  ready=no
  for attempt in $(seq 1 60); do
    if on "$vm" "test -f /var/lib/k8s-node-prep.done" 2>/dev/null; then
      ready=yes
      break
    fi
    echo "    $vm: not ready yet ($attempt/60)"
    sleep 10
  done
  if [ "$ready" != yes ]; then
    echo "ERROR: $vm did not finish preparing. Read its log with:" >&2
    echo "  gcloud compute ssh $vm --zone $ZONE --tunnel-through-iap --command 'sudo journalctl -u google-startup-scripts --no-pager | tail -50'" >&2
    exit 1
  fi
  echo "    $vm: ready"
done

echo "### 2/4 Creating the control plane on $CP"
copy_platform "$CP"
on "$CP" "bash ~/platform/kubeadm/init-control-plane.sh"

echo "### 3/4 Joining the workers"
# Prints: kubeadm join <ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
JOIN="$(on "$CP" "sudo kubeadm token create --print-join-command" | tr -d '\r' | grep '^kubeadm join' || true)"
API_SERVER="$(awk '{print $3}' <<<"$JOIN")"
TOKEN="$(awk '{print $5}' <<<"$JOIN")"
CA_HASH="$(awk '{print $7}' <<<"$JOIN")"
if [ -z "$API_SERVER" ] || [ -z "$TOKEN" ] || [ -z "$CA_HASH" ]; then
  echo "ERROR: could not read the join command from $CP" >&2
  exit 1
fi
for vm in "${WORKERS[@]}"; do
  copy_platform "$vm"
  on "$vm" "bash ~/platform/kubeadm/join-worker.sh $API_SERVER $TOKEN $CA_HASH"
done

echo "### 4/4 Installing namespaces, storage, metrics and Traefik"
on "$CP" "bash ~/platform/install-addons.sh"

echo
echo "Cluster is up. Next:"
echo "  - kubectl from your laptop:  docs/01-infrastructure.md, Step 8"
echo "  - end-to-end test:           docs/01-infrastructure.md, Step 9"
