#!/bin/bash
# Run ON cp-1, after the workers have joined. Installs what a bare kubeadm
# cluster is missing: environments, storage, metrics and the ingress controller.
# Safe to run again.
#
#   bash ~/platform/install-addons.sh
set -euo pipefail
cd "$(dirname "$0")"

LOCAL_PATH_VERSION="${LOCAL_PATH_VERSION:-v0.0.30}"

echo "==> Waiting for all nodes to be Ready"
kubectl wait --for=condition=Ready node --all --timeout=600s

# Workers get no role label by default; this makes `kubectl get nodes` show ROLES=worker.
kubectl label nodes -l '!node-role.kubernetes.io/control-plane' \
  node-role.kubernetes.io/worker= --overwrite

echo "==> Environments: dev, test, prod namespaces with quotas"
kubectl apply -f namespaces/environments.yaml

echo "==> Storage: default StorageClass (data lives on the node's disk)"
kubectl apply -f "https://raw.githubusercontent.com/rancher/local-path-provisioner/$LOCAL_PATH_VERSION/deploy/local-path-storage.yaml"
kubectl patch storageclass local-path \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

echo "==> Metrics server (for kubectl top and autoscaling)"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# kubeadm's kubelet certificates are self-signed, so metrics-server must not verify them.
if ! kubectl -n kube-system get deployment metrics-server \
  -o jsonpath='{.spec.template.spec.containers[0].args}' | grep -q kubelet-insecure-tls; then
  kubectl -n kube-system patch deployment metrics-server --type=json \
    -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
fi

echo "==> Ingress controller: Traefik on ports 80/443 of every worker"
if ! command -v helm >/dev/null 2>&1 && [ ! -x /snap/bin/helm ]; then
  sudo snap install helm --classic
fi
HELM="$(command -v helm || echo /snap/bin/helm)"
"$HELM" repo add traefik https://traefik.github.io/charts --force-update
"$HELM" repo update traefik
"$HELM" upgrade --install traefik traefik/traefik -n traefik --create-namespace \
  -f traefik/values.yaml --wait --timeout 5m

echo
kubectl get nodes -o wide
echo
kubectl get pods -A
