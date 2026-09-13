#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

REPO_DIR="/home/admin/kubernetes-the-hard-way"
WORK_DIR="/tmp/kthw-worker-assets"

cd "${REPO_DIR}"

# ------------------------------------------------------------
# 1. Generate worker-specific configuration
# ------------------------------------------------------------

log "Generating worker-specific configs"

for HOST in node-0 node-1; do

	SUBNET="$(
		awk -v host="$HOST" '$3 == host {print $4}' machines.txt
	)"

	if [ -z "$SUBNET" ]; then
		die "Missing subnet for ${HOST}"
	fi

	echo "${HOST} subnet: ${SUBNET}"

	sed "s|SUBNET|${SUBNET}|g" \
		configs/10-bridge.conf \
		>"${HOST}-10-bridge.conf"

	cp \
		configs/kubelet-config.yaml \
		"${HOST}-kubelet-config.yaml"

	require_file "${HOST}-10-bridge.conf"
	require_file "${HOST}-kubelet-config.yaml"

	if ! grep -q "${SUBNET}" "${HOST}-10-bridge.conf"; then
		die "Subnet ${SUBNET} was not written to ${HOST}-10-bridge.conf"
	fi

done

# ------------------------------------------------------------
# 2. Prepare worker binaries on jumpbox
# ------------------------------------------------------------

log "Preparing worker binaries"

rm -rf "${WORK_DIR}"

mkdir -p \
	"${WORK_DIR}/bin" \
	"${WORK_DIR}/cni"

# kubelet
KUBELET_PATH="$(
	find downloads \
		-type f \
		-name kubelet \
		-print \
		-quit
)"

[ -n "$KUBELET_PATH" ] || die "kubelet binary not found"

cp "$KUBELET_PATH" "${WORK_DIR}/bin/kubelet"

# kube-proxy
KUBE_PROXY_PATH="$(
	find downloads \
		-type f \
		-name kube-proxy \
		-print \
		-quit
)"

[ -n "$KUBE_PROXY_PATH" ] || die "kube-proxy binary not found"

cp "$KUBE_PROXY_PATH" "${WORK_DIR}/bin/kube-proxy"

# runc
RUNC_PATH="$(
	find downloads \
		-type f \
		\( -name runc -o -name 'runc.amd64' \) \
		-print \
		-quit
)"

[ -n "$RUNC_PATH" ] || die "runc binary not found"

cp "$RUNC_PATH" "${WORK_DIR}/bin/runc"

# ------------------------------------------------------------
# crictl
# ------------------------------------------------------------

CRICTL_PATH="$(
	find downloads \
		-type f \
		-name crictl \
		-print \
		-quit
)"

if [ -z "$CRICTL_PATH" ]; then

	CRICTL_ARCHIVE="$(
		find downloads \
			-maxdepth 1 \
			-type f \
			-name 'crictl-*-linux-amd64.tar.gz' \
			-print \
			-quit
	)"

	[ -n "$CRICTL_ARCHIVE" ] || die "crictl binary/archive not found"

	mkdir -p "${WORK_DIR}/crictl-extract"

	tar -xzf "$CRICTL_ARCHIVE" \
		-C "${WORK_DIR}/crictl-extract"

	CRICTL_PATH="$(
		find "${WORK_DIR}/crictl-extract" \
			-type f \
			-name crictl \
			-print \
			-quit
	)"

fi

[ -n "$CRICTL_PATH" ] || die "Unable to prepare crictl"

cp "$CRICTL_PATH" "${WORK_DIR}/bin/crictl"

# ------------------------------------------------------------
# containerd
# ------------------------------------------------------------

CONTAINERD_PATH="$(
	find downloads \
		-type f \
		-name containerd \
		-print \
		-quit
)"

if [ -z "$CONTAINERD_PATH" ]; then

	CONTAINERD_ARCHIVE="$(
		find downloads \
			-maxdepth 1 \
			-type f \
			-name 'containerd-*-linux-amd64.tar.gz' \
			-print \
			-quit
	)"

	[ -n "$CONTAINERD_ARCHIVE" ] || die "containerd binary/archive not found"

	mkdir -p "${WORK_DIR}/containerd-extract"

	tar -xzf "$CONTAINERD_ARCHIVE" \
		-C "${WORK_DIR}/containerd-extract"

	CONTAINERD_PATH="$(
		find "${WORK_DIR}/containerd-extract" \
			-type f \
			-name containerd \
			-print \
			-quit
	)"

fi

[ -n "$CONTAINERD_PATH" ] || die "Unable to prepare containerd"

CONTAINERD_DIR="$(dirname "$CONTAINERD_PATH")"

for BINARY in \
	containerd \
	containerd-shim-runc-v2 \
	ctr; do

	if [ -f "${CONTAINERD_DIR}/${BINARY}" ]; then
		cp \
			"${CONTAINERD_DIR}/${BINARY}" \
			"${WORK_DIR}/bin/${BINARY}"
	fi

done

# ------------------------------------------------------------
# CNI plugins
# ------------------------------------------------------------

CNI_BRIDGE_PATH="$(
	find downloads \
		-type f \
		-name bridge \
		-print \
		-quit
)"

if [ -n "$CNI_BRIDGE_PATH" ]; then

	CNI_DIR="$(dirname "$CNI_BRIDGE_PATH")"

	cp -a \
		"${CNI_DIR}/." \
		"${WORK_DIR}/cni/"

else

	CNI_ARCHIVE="$(
		find downloads \
			-maxdepth 1 \
			-type f \
			-name 'cni-plugins-linux-amd64-*.tgz' \
			-print \
			-quit
	)"

	[ -n "$CNI_ARCHIVE" ] || die "CNI plugins archive not found"

	tar -xzf "$CNI_ARCHIVE" \
		-C "${WORK_DIR}/cni"

fi

require_file "${WORK_DIR}/bin/kubelet"
require_file "${WORK_DIR}/bin/kube-proxy"
require_file "${WORK_DIR}/bin/crictl"
require_file "${WORK_DIR}/bin/runc"
require_file "${WORK_DIR}/bin/containerd"
require_file "${WORK_DIR}/cni/bridge"

chmod +x \
	"${WORK_DIR}/bin/"* \
	"${WORK_DIR}/cni/"*

# ------------------------------------------------------------
# 3. Copy assets to workers
# ------------------------------------------------------------

log "Copying worker assets"

for HOST in node-0 node-1; do

	log "Copying assets to ${HOST}"

	ssh "admin@${HOST}" "
    rm -rf ~/worker-bin ~/cni-plugins
    mkdir -p ~/worker-bin ~/cni-plugins
  "

	scp \
		"${WORK_DIR}/bin/"* \
		"admin@${HOST}:~/worker-bin/"

	scp \
		"${WORK_DIR}/cni/"* \
		"admin@${HOST}:~/cni-plugins/"

	scp \
		units/containerd.service \
		units/kubelet.service \
		units/kube-proxy.service \
		configs/containerd-config.toml \
		configs/kube-proxy-config.yaml \
		configs/99-loopback.conf \
		"${HOST}-10-bridge.conf" \
		"${HOST}-kubelet-config.yaml" \
		"admin@${HOST}:~/"

done

# ------------------------------------------------------------
# 4. Install and configure workers
# ------------------------------------------------------------

log "Installing worker services"

for HOST in node-0 node-1; do

	log "Configuring ${HOST}"

	ssh "admin@${HOST}" bash <<'REMOTE'

set -Eeuo pipefail

HOSTNAME_NOW="$(hostname)"

echo "Configuring ${HOSTNAME_NOW}"


# ------------------------------------------------------------
# Kernel / swap
# ------------------------------------------------------------

sudo swapoff -a || true

sudo modprobe br-netfilter

echo "br-netfilter" \
  | sudo tee /etc/modules-load.d/kubernetes.conf \
  >/dev/null

cat <<'EOF' \
  | sudo tee /etc/sysctl.d/kubernetes.conf \
  >/dev/null
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system


# ------------------------------------------------------------
# Directories
# ------------------------------------------------------------

sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /etc/containerd \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes


# ------------------------------------------------------------
# Worker binaries
# ------------------------------------------------------------

sudo install -m 0755 \
  worker-bin/crictl \
  /usr/local/bin/crictl

sudo install -m 0755 \
  worker-bin/runc \
  /usr/local/bin/runc

sudo install -m 0755 \
  worker-bin/kubelet \
  /usr/local/bin/kubelet

sudo install -m 0755 \
  worker-bin/kube-proxy \
  /usr/local/bin/kube-proxy

sudo install -m 0755 \
  worker-bin/containerd \
  /bin/containerd


if [ -f worker-bin/containerd-shim-runc-v2 ]; then

  sudo install -m 0755 \
    worker-bin/containerd-shim-runc-v2 \
    /usr/local/bin/containerd-shim-runc-v2

fi


if [ -f worker-bin/ctr ]; then

  sudo install -m 0755 \
    worker-bin/ctr \
    /usr/local/bin/ctr

fi


# ------------------------------------------------------------
# CNI plugins
# ------------------------------------------------------------

sudo cp -a \
  cni-plugins/. \
  /opt/cni/bin/

sudo chmod +x /opt/cni/bin/*


# ------------------------------------------------------------
# CNI configuration
# ------------------------------------------------------------

sudo install -m 0644 \
  "${HOSTNAME_NOW}-10-bridge.conf" \
  /etc/cni/net.d/10-bridge.conf

sudo install -m 0644 \
  99-loopback.conf \
  /etc/cni/net.d/99-loopback.conf


# ------------------------------------------------------------
# containerd configuration
# ------------------------------------------------------------

sudo install -m 0644 \
  containerd-config.toml \
  /etc/containerd/config.toml


# ------------------------------------------------------------
# kubelet configuration
# ------------------------------------------------------------

sudo install -m 0644 \
  "${HOSTNAME_NOW}-kubelet-config.yaml" \
  /var/lib/kubelet/kubelet-config.yaml


# ------------------------------------------------------------
# kube-proxy configuration
# ------------------------------------------------------------

sudo install -m 0644 \
  kube-proxy-config.yaml \
  /var/lib/kube-proxy/kube-proxy-config.yaml


# ------------------------------------------------------------
# systemd units
# ------------------------------------------------------------

sudo install -m 0644 \
  containerd.service \
  /etc/systemd/system/containerd.service

sudo install -m 0644 \
  kubelet.service \
  /etc/systemd/system/kubelet.service

sudo install -m 0644 \
  kube-proxy.service \
  /etc/systemd/system/kube-proxy.service


# ------------------------------------------------------------
# Fail-fast verification
# ------------------------------------------------------------

sudo test -s /etc/cni/net.d/10-bridge.conf

sudo test -s /etc/cni/net.d/99-loopback.conf

sudo test -s /var/lib/kubelet/kubelet-config.yaml

sudo test -s /var/lib/kubelet/kubeconfig

sudo test -s /var/lib/kubelet/ca.crt

sudo test -s /var/lib/kubelet/kubelet.crt

sudo test -s /var/lib/kubelet/kubelet.key

sudo test -s /var/lib/kube-proxy/kubeconfig

test -x /bin/containerd

test -x /usr/local/bin/kubelet

test -x /usr/local/bin/kube-proxy

test -x /opt/cni/bin/bridge


# ------------------------------------------------------------
# Start services
# ------------------------------------------------------------

sudo systemctl daemon-reload

sudo systemctl enable \
  containerd \
  kubelet \
  kube-proxy

sudo systemctl restart \
  containerd \
  kubelet \
  kube-proxy


# ------------------------------------------------------------
# Verify services stay alive
# ------------------------------------------------------------

for service in \
  containerd \
  kubelet \
  kube-proxy
do

  echo "Checking ${service}"

  for i in {1..30}; do

    if sudo systemctl is-active --quiet "$service"; then
      sleep 2

      if sudo systemctl is-active --quiet "$service"; then
        break
      fi
    fi

    sleep 2

  done

  if ! sudo systemctl is-active --quiet "$service"; then

    echo "ERROR: ${service} failed on ${HOSTNAME_NOW}"

    sudo journalctl \
      -u "$service" \
      -n 100 \
      --no-pager

    exit 1

  fi

done

echo "${HOSTNAME_NOW} services are running"

REMOTE

done

# ------------------------------------------------------------
# 5. Wait for nodes
# ------------------------------------------------------------

log "Waiting for nodes to become Ready"

ssh admin@server bash <<'REMOTE'

set -Eeuo pipefail

for i in {1..60}; do

  READY_COUNT="$(
    kubectl get nodes \
      --kubeconfig /home/admin/admin.kubeconfig \
      --no-headers \
      2>/dev/null \
    | awk '$2 == "Ready" {count++} END {print count+0}'
  )"

  echo "Ready nodes: ${READY_COUNT}/2"

  if [ "$READY_COUNT" -eq 2 ]; then

    echo
    kubectl get nodes \
      --kubeconfig /home/admin/admin.kubeconfig \
      -o wide

    exit 0

  fi

  sleep 5

done


echo "ERROR: Workers did not become Ready"

kubectl get nodes \
  --kubeconfig /home/admin/admin.kubeconfig \
  -o wide || true

exit 1

REMOTE

log "Lab 09 complete"
