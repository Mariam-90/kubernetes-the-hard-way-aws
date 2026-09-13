#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

REPO_DIR="/home/admin/kubernetes-the-hard-way"
KUBERNETES_ADDRESS="server.kubernetes.local"

cd "${REPO_DIR}"

log "Generating kubeconfigs"

for host in node-0 node-1; do

  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server="https://${KUBERNETES_ADDRESS}:6443" \
    --kubeconfig="${host}.kubeconfig"

  kubectl config set-credentials "system:node:${host}" \
    --client-certificate="${host}.crt" \
    --client-key="${host}.key" \
    --embed-certs=true \
    --kubeconfig="${host}.kubeconfig"

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user="system:node:${host}" \
    --kubeconfig="${host}.kubeconfig"

  kubectl config use-context default \
    --kubeconfig="${host}.kubeconfig"

  require_file "${host}.kubeconfig"

done


log "Generating kube-proxy kubeconfig"

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.crt \
  --embed-certs=true \
  --server="https://${KUBERNETES_ADDRESS}:6443" \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
  --client-certificate=kube-proxy.crt \
  --client-key=kube-proxy.key \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default \
  --kubeconfig=kube-proxy.kubeconfig

require_file kube-proxy.kubeconfig


log "Generating controller-manager kubeconfig"

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.crt \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=kube-controller-manager.crt \
  --client-key=kube-controller-manager.key \
  --embed-certs=true \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default \
  --kubeconfig=kube-controller-manager.kubeconfig

require_file kube-controller-manager.kubeconfig


log "Generating scheduler kubeconfig"

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.crt \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
  --client-certificate=kube-scheduler.crt \
  --client-key=kube-scheduler.key \
  --embed-certs=true \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default \
  --kubeconfig=kube-scheduler.kubeconfig

require_file kube-scheduler.kubeconfig


log "Generating admin kubeconfig"

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.crt \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
  --client-certificate=admin.crt \
  --client-key=admin.key \
  --embed-certs=true \
  --kubeconfig=admin.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=admin \
  --kubeconfig=admin.kubeconfig

kubectl config use-context default \
  --kubeconfig=admin.kubeconfig

require_file admin.kubeconfig


log "Distributing worker kubeconfigs"

for host in node-0 node-1; do

  scp \
    "${host}.kubeconfig" \
    kube-proxy.kubeconfig \
    "admin@${host}:/tmp/"

  ssh "admin@${host}" "
    sudo mkdir -p /var/lib/kubelet
    sudo mkdir -p /var/lib/kube-proxy

    sudo install \
      -o root \
      -g root \
      -m 0600 \
      /tmp/${host}.kubeconfig \
      /var/lib/kubelet/kubeconfig

    sudo install \
      -o root \
      -g root \
      -m 0600 \
      /tmp/kube-proxy.kubeconfig \
      /var/lib/kube-proxy/kubeconfig

    rm -f \
      /tmp/${host}.kubeconfig \
      /tmp/kube-proxy.kubeconfig
  "

done


log "Verifying worker kubeconfigs"

for host in node-0 node-1; do

  ssh "admin@${host}" "
    sudo test -s /var/lib/kubelet/kubeconfig
    sudo test -s /var/lib/kube-proxy/kubeconfig
  "

done


log "Distributing control-plane kubeconfigs"

scp \
  kube-controller-manager.kubeconfig \
  kube-scheduler.kubeconfig \
  admin.kubeconfig \
  admin@server:/tmp/


ssh admin@server "
  sudo mkdir -p /var/lib/kubernetes

  sudo install \
    -o root \
    -g root \
    -m 0600 \
    /tmp/kube-controller-manager.kubeconfig \
    /var/lib/kubernetes/kube-controller-manager.kubeconfig

  sudo install \
    -o root \
    -g root \
    -m 0600 \
    /tmp/kube-scheduler.kubeconfig \
    /var/lib/kubernetes/kube-scheduler.kubeconfig

  install \
    -m 0600 \
    /tmp/admin.kubeconfig \
    /home/admin/admin.kubeconfig

  rm -f \
    /tmp/kube-controller-manager.kubeconfig \
    /tmp/kube-scheduler.kubeconfig \
    /tmp/admin.kubeconfig
"


log "Verifying control-plane kubeconfigs"

ssh admin@server "
  sudo test -s /var/lib/kubernetes/kube-controller-manager.kubeconfig
  sudo test -s /var/lib/kubernetes/kube-scheduler.kubeconfig
  test -s /home/admin/admin.kubeconfig
"


log "Lab 05 complete"