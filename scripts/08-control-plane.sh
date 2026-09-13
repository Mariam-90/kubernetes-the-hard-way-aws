#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

REPO_DIR="/home/admin/kubernetes-the-hard-way"

cd "${REPO_DIR}"

log "Copying control-plane binaries and configs"

scp \
	downloads/kube-apiserver \
	downloads/kube-controller-manager \
	downloads/kube-scheduler \
	downloads/kubectl \
	units/kube-apiserver.service \
	units/kube-controller-manager.service \
	units/kube-scheduler.service \
	configs/kube-scheduler.yaml \
	configs/kube-apiserver-to-kubelet.yaml \
	admin@server:/tmp/

log "Installing control plane"

ssh admin@server bash <<'REMOTE'
set -Eeuo pipefail

sudo install -m 0755 \
  /tmp/kube-apiserver \
  /usr/local/bin/kube-apiserver

sudo install -m 0755 \
  /tmp/kube-controller-manager \
  /usr/local/bin/kube-controller-manager

sudo install -m 0755 \
  /tmp/kube-scheduler \
  /usr/local/bin/kube-scheduler

sudo install -m 0755 \
  /tmp/kubectl \
  /usr/local/bin/kubectl

sudo mkdir -p \
  /etc/kubernetes/config \
  /var/lib/kubernetes

sudo install -m 0644 \
  /tmp/kube-apiserver.service \
  /etc/systemd/system/kube-apiserver.service

sudo install -m 0644 \
  /tmp/kube-controller-manager.service \
  /etc/systemd/system/kube-controller-manager.service

sudo install -m 0644 \
  /tmp/kube-scheduler.service \
  /etc/systemd/system/kube-scheduler.service

sudo install -m 0644 \
  /tmp/kube-scheduler.yaml \
  /etc/kubernetes/config/kube-scheduler.yaml

sudo systemctl daemon-reload

sudo systemctl enable \
  kube-apiserver \
  kube-controller-manager \
  kube-scheduler

sudo systemctl restart \
  kube-apiserver \
  kube-controller-manager \
  kube-scheduler

for service in kube-apiserver kube-controller-manager kube-scheduler; do

  for i in {1..30}; do
    if sudo systemctl is-active --quiet "$service"; then
      break
    fi

    sleep 2
  done

  if ! sudo systemctl is-active --quiet "$service"; then
    sudo journalctl -u "$service" -n 100 --no-pager
    exit 1
  fi

done

echo "Waiting for kube-apiserver readiness"

for i in {1..30}; do
  if kubectl get --raw='/readyz' \
    --kubeconfig /home/admin/admin.kubeconfig \
    >/dev/null 2>&1; then

    echo "kube-apiserver is ready"
    break
  fi

  sleep 2
done

if ! kubectl get --raw='/readyz' \
  --kubeconfig /home/admin/admin.kubeconfig \
  >/dev/null 2>&1; then

  echo "ERROR: kube-apiserver did not become ready"

  sudo journalctl \
    -u kube-apiserver \
    -n 100 \
    --no-pager

  exit 1
fi

kubectl cluster-info \
  --kubeconfig /home/admin/admin.kubeconfig

kubectl apply \
  -f /tmp/kube-apiserver-to-kubelet.yaml \
  --kubeconfig /home/admin/admin.kubeconfig



REMOTE

log "Lab 08 complete"
