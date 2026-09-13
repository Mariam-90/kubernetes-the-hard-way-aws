#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

REPO_DIR="/home/admin/kubernetes-the-hard-way"
ETCD_DIR="downloads/etcd-v3.6.0-rc.3-linux-amd64"

cd "${REPO_DIR}"

log "Copying etcd assets"

scp \
  "${ETCD_DIR}/etcd" \
  "${ETCD_DIR}/etcdctl" \
  units/etcd.service \
  admin@server:/tmp/

log "Installing etcd"

ssh admin@server bash <<'REMOTE'
set -Eeuo pipefail

sudo install -m 0755 \
  /tmp/etcd \
  /usr/local/bin/etcd

sudo install -m 0755 \
  /tmp/etcdctl \
  /usr/local/bin/etcdctl

sudo mkdir -p \
  /etc/etcd \
  /var/lib/etcd

sudo chmod 700 /var/lib/etcd

sudo install -m 0644 \
  /var/lib/kubernetes/ca.crt \
  /etc/etcd/ca.crt

sudo install -m 0644 \
  /var/lib/kubernetes/kube-api-server.crt \
  /etc/etcd/kube-api-server.crt

sudo install -m 0600 \
  /var/lib/kubernetes/kube-api-server.key \
  /etc/etcd/kube-api-server.key

sudo install -m 0644 \
  /tmp/etcd.service \
  /etc/systemd/system/etcd.service

sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl restart etcd

for i in {1..30}; do

  if sudo systemctl is-active --quiet etcd; then
    break
  fi

  sleep 2

done

if ! sudo systemctl is-active --quiet etcd; then

  echo "ERROR: etcd failed to start"

  sudo journalctl \
    -u etcd \
    -n 100 \
    --no-pager

  exit 1

fi

etcdctl member list \
  --endpoints=http://127.0.0.1:2379
REMOTE

log "Lab 07 complete"