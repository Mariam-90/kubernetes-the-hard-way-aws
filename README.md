# Kubernetes The Hard Way on AWS — Automated with Terraform and Bash

A hands-on DevOps project that provisions AWS infrastructure with Terraform and automates a complete Kubernetes The Hard Way cluster bootstrap using Bash.

The purpose of this project is not to replace a production Kubernetes platform. It is to understand Kubernetes internals deeply, then automate the manual process in a reproducible way.

## Project Goals

- Provision AWS infrastructure with Terraform.
- Bootstrap EC2 instances with `user_data`.
- Build the Kubernetes control plane from individual binaries.
- Configure PKI, kubeconfigs, encryption, etcd, worker nodes, networking, and RBAC.
- Automate Kubernetes The Hard Way Labs 02–12 with Bash.
- Add fail-fast verification and readiness checks.
- Troubleshoot real issues involving Linux, systemd, TLS, CNI, SSH, networking, and Kubernetes readiness.
- Prove that the complete environment can be rebuilt from scratch.

## Final Status

**Completed and validated end-to-end.**

The infrastructure was destroyed and recreated from scratch, and the full automation workflow completed successfully.

Final validation:

```text
node-0   Ready
node-1   Ready
```

A test NGINX workload reached:

```text
1/1 Running
```

and a NodePort Service was created successfully.

Final output:

```text
Lab 12 complete
Kubernetes The Hard Way automation completed successfully.
```

## Architecture

```text
                Local Workstation
                     │
                     │ Terraform
                     ▼
             AWS VPC + Public Subnet
                     │
    ┌────────────────┼────────────────┐
    │                │                │
    ▼                ▼                ▼
 jumpbox           server          workers
10.0.1.10         10.0.1.20     10.0.1.30/.40
    │                │                │
    │                │                ├─ containerd
    │                │                ├─ kubelet
    │                │                ├─ kube-proxy
    │                │                └─ CNI
    │                │
    │                ├─ etcd
    │                ├─ kube-apiserver
    │                ├─ kube-controller-manager
    │                └─ kube-scheduler
    │
    └──── SSH + Bash orchestration ───┘
```

## Network Layout

| Machine |  Private IP | Purpose                       |
| ------- | ----------: | ----------------------------- |
| jumpbox | `10.0.1.10` | Administration and automation |
| server  | `10.0.1.20` | Kubernetes control plane      |
| node-0  | `10.0.1.30` | Worker node                   |
| node-1  | `10.0.1.40` | Worker node                   |

Pod networks:

| Worker | Pod CIDR        |
| ------ | --------------- |
| node-0 | `10.200.0.0/24` |
| node-1 | `10.200.1.0/24` |

AWS networking includes a VPC, public subnet, Internet Gateway, routing, Security Groups, deterministic private IP addresses, and internal connectivity between cluster instances.

## Automation Design

```text
Terraform
  ↓
AWS infrastructure

user_data
  ↓
Base OS bootstrap

Bash scripts
  ↓
Kubernetes The Hard Way Labs 02–12

Verification
  ↓
Service checks + readiness checks + smoke test
```

### Terraform

Terraform manages:

- VPC
- Subnet
- Security Group
- EC2 instances
- Deterministic private IP addresses
- Instance metadata used by templates
- EC2 `user_data`

Kubernetes private keys and cluster secrets are intentionally not stored in Terraform state.

### user_data

The bootstrap template:

- Sets hostnames
- Installs required packages
- Writes `/etc/hosts`
- Configures worker kernel modules
- Applies Kubernetes-related sysctl settings
- Creates required directories
- Writes a completion marker

### Bash Automation

The automation runs from the jumpbox and connects directly to:

```text
server
node-0
node-1
```

SSH agent forwarding is used from the workstation:

```bash
ssh -A admin@<JUMPBOX_PUBLIC_IP>
```

## Repository Structure

```text
kubernetes-the-hard-way-aws/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── terraform.tfvars
│   └── modules/
│       ├── vpc/
│       ├── security_group/
│       └── ec2/
├── user-data/
│   └── base.sh.tftpl
├── scripts/
│   ├── lib/
│   │   └── common.sh
│   ├── 02-jumpbox.sh
│   ├── 03-compute-resources.sh
│   ├── 04-pki.sh
│   ├── 05-kubeconfigs.sh
│   ├── 06-encryption.sh
│   ├── 07-etcd.sh
│   ├── 08-control-plane.sh
│   ├── 09-workers.sh
│   ├── 10-kubectl.sh
│   ├── 11-routes.sh
│   ├── 12-smoke-test.sh
│   └── bootstrap-all.sh
├── .gitignore
└── README.md
```

## Automation Flow

### Lab 02 — Jumpbox

- Clones the Kubernetes The Hard Way repository.
- Detects system architecture.
- Downloads required binaries.
- Extracts archives.
- Installs `kubectl`.
- Verifies the client.

### Lab 03 — Compute Resources

Creates the machine inventory and verifies hostname/FQDN configuration.

### Lab 04 — PKI

Generates and distributes certificates for:

- Kubernetes CA
- Admin
- Worker nodes
- kube-proxy
- kube-scheduler
- kube-controller-manager
- kube-apiserver
- Service Accounts

### Lab 05 — Kubeconfigs

Generates kubeconfigs for:

- Workers
- kube-proxy
- Controller Manager
- Scheduler
- Admin

### Lab 06 — Encryption

Generates a random encryption key, Base64 encodes it, injects it into the encryption configuration, and distributes it to the control-plane server.

### Lab 07 — etcd

Installs etcd, starts it with systemd, and verifies membership.

### Lab 08 — Control Plane

Installs:

- kube-apiserver
- kube-controller-manager
- kube-scheduler
- kubectl

It also:

- installs systemd units
- enables and starts services
- verifies service state
- waits for the API Server `/readyz` endpoint
- applies API Server → Kubelet RBAC

Important lesson:

```text
Process running ≠ Application ready
```

### Lab 09 — Workers

Configures both workers with:

- containerd
- runc
- crictl
- kubelet
- kube-proxy
- CNI plugins
- bridge networking
- kubeconfigs
- certificates
- systemd units
- kernel/sysctl settings

The automation waits until both workers report:

```text
Ready
```

### Lab 10 — kubectl

Configures the admin context on the jumpbox and verifies authenticated access.

### Lab 11 — Pod Routes

Configures routing between the control-plane host and both Pod CIDRs.

### Lab 12 — Smoke Test

The final validation:

- creates an NGINX Deployment
- waits for availability
- reads Pod logs
- executes a command in the Pod
- exposes the Deployment with NodePort
- tests connectivity
- prints final Nodes, Pods, and Services

## How to Run

### 1. Configure Terraform

Update:

```text
terraform/terraform.tfvars
```

Example:

```hcl
region   = "us-east-1"
key_name = "key_for_mac"
ssh_cidr = "<YOUR_PUBLIC_IPV4>/32"
```

Get the current public IPv4:

```bash
curl -4 ifconfig.me
```

### 2. Provision Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 3. Load SSH Key

```bash
ssh-add ~/Downloads/key_for_mac.pem
ssh-add -L
```

### 4. Copy Automation Scripts

```bash
scp -r scripts admin@<JUMPBOX_PUBLIC_IP>:~/
```

### 5. Connect with Agent Forwarding

```bash
ssh -A admin@<JUMPBOX_PUBLIC_IP>
```

### 6. Run Full Bootstrap

```bash
cd ~/scripts
./bootstrap-all.sh
```

A successful run ends with:

```text
Kubernetes The Hard Way automation completed successfully.
```

## Validation

```bash
kubectl get nodes
```

Expected:

```text
NAME     STATUS   ROLES    VERSION
node-0   Ready    <none>   v1.32.3
node-1   Ready    <none>   v1.32.3
```

The smoke test should also show an NGINX Pod in `Running` state and a NodePort Service.

## Troubleshooting Lessons Learned

### Nested SSH

Early scripts accidentally used:

```text
Mac → jumpbox → jumpbox → server
```

which caused SSH agent-forwarding problems.

Correct pattern:

```text
Mac
  │ ssh -A
  ▼
jumpbox
  ├── server
  ├── node-0
  └── node-1
```

### Download Path Assumptions

Initial scripts assumed fixed binary layouts such as:

```text
downloads/controller/kube-apiserver
downloads/client/kubectl
```

The downloaded structure did not always match those assumptions, so the scripts were corrected to use the real paths.

### etcd HTTP vs HTTPS

etcd was listening on:

```text
http://127.0.0.1:2379
```

while an early verification command attempted HTTPS, producing a TLS handshake error.

### Encryption Configuration

The encryption template used:

```text
${ENCRYPTION_KEY}
```

The first implementation replaced only the variable name, leaving invalid syntax around the generated value. The full placeholder replacement was fixed and the key is validated as Base64.

### containerd systemd Path

The containerd service expected:

```text
/bin/containerd
```

while an earlier script installed it under:

```text
/usr/local/bin/containerd
```

This caused:

```text
status=203/EXEC
```

The install and verification paths were aligned.

### CNI Packaging

A clean rebuild exposed a bug where the script copied the entire downloads directory as if it were CNI plugins.

The final implementation extracts only the CNI archive into a dedicated working directory.

### API Server Readiness

`systemctl is-active` was not sufficient.

The API Server process could be running while Kubernetes post-start initialization was still incomplete.

The script now waits for:

```text
/readyz
```

before continuing.

### Worker Readiness

A running kubelet does not automatically mean a Kubernetes Node is Ready.

The automation waits for the control plane to report both workers as:

```text
Ready
```

## DevOps Skills Demonstrated

### Linux

- systemd
- journald
- permissions
- package management
- kernel modules
- sysctl
- process troubleshooting

### Networking

- VPCs
- subnets
- routing
- Pod CIDRs
- CNI
- NodePort
- ports and listeners
- loopback
- `/etc/hosts`

### Security

- PKI
- TLS
- certificates
- CA trust
- kubeconfigs
- RBAC
- encryption at rest
- SSH agent forwarding

### AWS

- EC2
- VPC
- subnet
- Security Groups
- Internet Gateway
- deterministic private IPs

### Terraform

- modules
- variables
- `for_each`
- templates
- `user_data`
- infrastructure lifecycle

### Bash

- strict mode
- reusable functions
- loops
- SSH orchestration
- fail-fast checks
- readiness polling
- idempotent operations
- verification

### Kubernetes

- etcd
- API Server
- Controller Manager
- Scheduler
- kubelet
- kube-proxy
- CNI
- Pods
- Deployments
- Services
- RBAC
- networking

## Why This Project Matters

Managed Kubernetes hides most control-plane internals.

This project exposes the full request path:

```text
kubectl
   ↓
API Server
   ↓
etcd / Controllers / Scheduler
   ↓
kubelet
   ↓
containerd
   ↓
CNI
   ↓
Pod
```

It connects infrastructure, Linux, networking, security, automation, and Kubernetes into one complete DevOps workflow.

## Production Context

This project is intentionally educational.

A typical production AWS architecture would more commonly use:

```text
Terraform
   ↓
Amazon EKS
   ↓
Managed Node Groups / Karpenter
   ↓
CI/CD
   ↓
Monitoring and Observability
```

A self-managed production cluster would additionally require:

- highly available control-plane nodes
- highly available etcd
- persistent routing
- load balancers
- backups
- centralized secrets management
- monitoring and alerting
- hardened IAM
- stronger network controls
- upgrade strategy

## Key Result

The strongest validation was not that the cluster worked once.

The infrastructure was destroyed and rebuilt from scratch, and the full automation completed successfully again.

That demonstrates that the project is functional and reproducible.

## Future Improvements

- Add Ansible for configuration management.
- Build an EKS-based production-style version.
- Add CI validation for Terraform and Bash.
- Add ShellCheck.
- Add automated infrastructure tests.
- Add Prometheus and Grafana.
- Add centralized logging.
- Add persistent routing.
- Explore a highly available control-plane architecture.

## Technologies

```text
AWS
Terraform
Bash
Linux
systemd
Kubernetes
containerd
etcd
CNI
PKI / TLS
RBAC
Git
SSH
```

## Summary

```text
Infrastructure
      ↓
Operating System Bootstrap
      ↓
Kubernetes PKI
      ↓
Kubeconfigs
      ↓
Encryption
      ↓
etcd
      ↓
Control Plane
      ↓
Worker Nodes
      ↓
Networking
      ↓
kubectl
      ↓
Application Deployment
      ↓
Smoke Testing
```

The final result is a fully automated Kubernetes The Hard Way environment on AWS, validated through a clean rebuild from scratch.
