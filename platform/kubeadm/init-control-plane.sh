#!/bin/bash
# Run ON cp-1. Creates the control plane and installs the pod network (Calico).
# Safe to run again: it skips steps that are already done.
#
#   bash ~/platform/kubeadm/init-control-plane.sh
set -euo pipefail
cd "$(dirname "$0")"

CALICO_VERSION="${CALICO_VERSION:-v3.33.1}"
CALICO_URL="https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests"

# 1. Create the control plane: API server, etcd, scheduler, controller manager.
if sudo test -f /etc/kubernetes/admin.conf; then
  echo "==> Control plane already exists, skipping kubeadm init"
else
  echo "==> Checking init-config.yaml"
  sudo kubeadm config validate --config init-config.yaml
  echo "==> Running kubeadm init (takes 1-2 minutes)"
  sudo kubeadm init --config init-config.yaml
fi

# 2. Let this user run kubectl (admin.conf is the cluster-admin login file).
mkdir -p "$HOME/.kube"
sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
chmod 600 "$HOME/.kube/config"

# 3. Pod network. Until this exists the node stays NotReady.
#    --server-side: these files are too large for a normal `kubectl apply`.
echo "==> Installing Calico $CALICO_VERSION"
kubectl apply --server-side --force-conflicts -f "$CALICO_URL/operator-crds.yaml"
kubectl apply --server-side --force-conflicts -f "$CALICO_URL/tigera-operator.yaml"
kubectl wait --for=condition=Established --timeout=120s \
  crd/installations.operator.tigera.io crd/apiservers.operator.tigera.io
kubectl apply -f ../calico/installation.yaml

echo "==> Waiting for the node to become Ready (2-4 minutes)"
kubectl wait --for=condition=Ready node --all --timeout=600s
kubectl get nodes -o wide
