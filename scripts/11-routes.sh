#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

NODE_0_IP="10.0.1.30"
NODE_0_SUBNET="10.200.0.0/24"

NODE_1_IP="10.0.1.40"
NODE_1_SUBNET="10.200.1.0/24"

log "Configuring server routes"

ssh admin@server "
  sudo ip route replace ${NODE_0_SUBNET} via ${NODE_0_IP}
  sudo ip route replace ${NODE_1_SUBNET} via ${NODE_1_IP}
"

log "Configuring node-0 route"

ssh admin@node-0 "
  sudo ip route replace ${NODE_1_SUBNET} via ${NODE_1_IP}
"

log "Configuring node-1 route"

ssh admin@node-1 "
  sudo ip route replace ${NODE_0_SUBNET} via ${NODE_0_IP}
"

log "Verifying routes"

ssh admin@server "ip route"
ssh admin@node-0 "ip route"
ssh admin@node-1 "ip route"

log "Lab 11 complete"