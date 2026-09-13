#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

REPO_DIR="/home/admin/kubernetes-the-hard-way"

log "Generating Kubernetes PKI on jumpbox"

cd "${REPO_DIR}"

openssl genrsa -out ca.key 4096

openssl req \
  -x509 \
  -new \
  -sha512 \
  -noenc \
  -key ca.key \
  -days 3653 \
  -config ca.conf \
  -out ca.crt

certs=(
  admin
  node-0
  node-1
  kube-proxy
  kube-scheduler
  kube-controller-manager
  kube-api-server
  service-accounts
)

for name in "${certs[@]}"; do

  openssl genrsa \
    -out "${name}.key" \
    4096

  openssl req \
    -new \
    -key "${name}.key" \
    -sha256 \
    -config ca.conf \
    -section "${name}" \
    -out "${name}.csr"

  openssl x509 \
    -req \
    -days 3653 \
    -in "${name}.csr" \
    -copy_extensions copyall \
    -sha256 \
    -CA ca.crt \
    -CAkey ca.key \
    -CAcreateserial \
    -out "${name}.crt"

  require_file "${name}.key"
  require_file "${name}.crt"

done

require_file ca.key
require_file ca.crt

log "Verifying worker certificate subjects"

openssl x509 \
  -in node-0.crt \
  -noout \
  -subject

openssl x509 \
  -in node-1.crt \
  -noout \
  -subject

log "Distributing worker certificates"

for host in node-0 node-1; do

  ssh "admin@${host}" \
    "sudo mkdir -p /var/lib/kubelet"

  scp \
    ca.crt \
    "${host}.crt" \
    "${host}.key" \
    "admin@${host}:/tmp/"

  ssh "admin@${host}" "
    sudo install \
      -o root \
      -g root \
      -m 0644 \
      /tmp/ca.crt \
      /var/lib/kubelet/ca.crt

    sudo install \
      -o root \
      -g root \
      -m 0644 \
      /tmp/${host}.crt \
      /var/lib/kubelet/kubelet.crt

    sudo install \
      -o root \
      -g root \
      -m 0600 \
      /tmp/${host}.key \
      /var/lib/kubelet/kubelet.key

    rm -f \
      /tmp/ca.crt \
      /tmp/${host}.crt \
      /tmp/${host}.key
  "

done

log "Verifying worker certificate distribution"

for host in node-0 node-1; do

  ssh "admin@${host}" "
    sudo test -s /var/lib/kubelet/ca.crt
    sudo test -s /var/lib/kubelet/kubelet.crt
    sudo test -s /var/lib/kubelet/kubelet.key
  "

done

log "Distributing control-plane certificates"

scp \
  ca.key \
  ca.crt \
  kube-api-server.key \
  kube-api-server.crt \
  service-accounts.key \
  service-accounts.crt \
  admin@server:/tmp/

ssh admin@server "
  sudo mkdir -p /var/lib/kubernetes

  sudo install \
    -o root \
    -g root \
    -m 0600 \
    /tmp/ca.key \
    /var/lib/kubernetes/ca.key

  sudo install \
    -o root \
    -g root \
    -m 0644 \
    /tmp/ca.crt \
    /var/lib/kubernetes/ca.crt

  sudo install \
    -o root \
    -g root \
    -m 0600 \
    /tmp/kube-api-server.key \
    /var/lib/kubernetes/kube-api-server.key

  sudo install \
    -o root \
    -g root \
    -m 0644 \
    /tmp/kube-api-server.crt \
    /var/lib/kubernetes/kube-api-server.crt

  sudo install \
    -o root \
    -g root \
    -m 0600 \
    /tmp/service-accounts.key \
    /var/lib/kubernetes/service-accounts.key

  sudo install \
    -o root \
    -g root \
    -m 0644 \
    /tmp/service-accounts.crt \
    /var/lib/kubernetes/service-accounts.crt

  rm -f \
    /tmp/ca.key \
    /tmp/ca.crt \
    /tmp/kube-api-server.key \
    /tmp/kube-api-server.crt \
    /tmp/service-accounts.key \
    /tmp/service-accounts.crt
"

log "Verifying control-plane certificate distribution"

ssh admin@server "
  sudo test -s /var/lib/kubernetes/ca.key
  sudo test -s /var/lib/kubernetes/ca.crt
  sudo test -s /var/lib/kubernetes/kube-api-server.key
  sudo test -s /var/lib/kubernetes/kube-api-server.crt
  sudo test -s /var/lib/kubernetes/service-accounts.key
  sudo test -s /var/lib/kubernetes/service-accounts.crt
"

log "Lab 04 complete"