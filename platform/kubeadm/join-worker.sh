#!/bin/bash
# Run ON a worker. Fills in join-config.yaml and joins this VM to the cluster.
#
#   bash ~/platform/kubeadm/join-worker.sh <api-server> <token> <ca-cert-hash>
#   e.g. join-worker.sh 10.10.0.2:6443 abcdef.0123456789abcdef sha256:1a2b...
#
# Get the three values on cp-1: sudo kubeadm token create --print-join-command
set -euo pipefail
cd "$(dirname "$0")"

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <api-server> <token> <ca-cert-hash>" >&2
  exit 1
fi

# kubelet.conf only exists on a node that has already joined.
if sudo test -f /etc/kubernetes/kubelet.conf; then
  echo "==> $(hostname) has already joined, skipping"
  exit 0
fi

# The filled-in file holds the token, so make it private and delete it afterwards.
umask 077
CONFIG="$(mktemp)"
trap 'rm -f "$CONFIG"' EXIT
sed -e "s|__API_SERVER__|$1|" -e "s|__TOKEN__|$2|" -e "s|__CA_CERT_HASH__|$3|" \
  join-config.yaml > "$CONFIG"

echo "==> Joining $(hostname) to the cluster at $1"
sudo kubeadm join --config "$CONFIG"
