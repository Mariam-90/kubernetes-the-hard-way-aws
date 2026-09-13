#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

REPO_DIR="/home/admin/kubernetes-the-hard-way"

log "Waiting for cluster machines"

for host in server node-0 node-1; do
  wait_for_ssh "$host"
done

log "Creating machines.txt"

cd "$REPO_DIR"

cat > machines.txt <<'EOF'
10.0.1.20 server.kubernetes.local server
10.0.1.30 node-0.kubernetes.local node-0 10.200.0.0/24
10.0.1.40 node-1.kubernetes.local node-1 10.200.1.0/24
EOF

cat machines.txt

log "Configuring hostnames and local host resolution"

while read -r IP FQDN HOST SUBNET; do

  ssh "admin@${HOST}" "
    sudo hostnamectl set-hostname '${HOST}'

    if grep -q '^127\.0\.1\.1' /etc/hosts; then
      sudo sed -i 's/^127\.0\.1\.1.*/127.0.1.1 ${FQDN} ${HOST}/' /etc/hosts
    else
      echo '127.0.1.1 ${FQDN} ${HOST}' | sudo tee -a /etc/hosts >/dev/null
    fi
  "

done < machines.txt

log "Verifying hostnames"

for host in server node-0 node-1; do
  ssh "admin@${host}" "hostname && hostname --fqdn"
done

log "Lab 03 complete"