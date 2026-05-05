# azure-logistics-infra
End-to-end Azure infrastructure deployment for logistics demo
# Azure Logistics Infrastructure

End-to-end Azure infrastructure deployment for a logistics company, built with security best practices, monitoring, and CI/CD automation.

## Architecture

```
Azure Subscription (North Europe)
│
├── Azure Policy: Require "Environment" tag on all resources
│
└── Resource Group: logistics-demo-rg
    │
    ├── Virtual Network (10.0.0.0/16)
    │   ├── web-subnet (10.0.1.0/24)
    │   │   ├── NSG: Allow HTTP/HTTPS/SSH (restricted IP)
    │   │   └── VM (Ubuntu 22.04 + Nginx)
    │   │       ├── System-assigned Managed Identity
    │   │       └── Key Vault access (no stored credentials)
    │   │
    │   └── data-subnet (10.0.2.0/24)
    │       └── NSG: Allow traffic only from web-subnet
    │
    ├── Storage Account (Standard LRS, Hot tier, HTTPS-only)
    │   └── Blob Container: static-files
    │
    ├── Key Vault (RBAC-enabled)
    │   └── Secrets: db-connection-string
    │
    ├── Log Analytics Workspace
    │   └── VM Diagnostic Settings (metrics)
    │
    └── Azure Monitor
        └── Alert: CPU > 80% → Email notification
```

## Security Highlights

- **Zero hardcoded credentials** — VM uses Managed Identity to access Key Vault
- **Network segmentation** — Web and data tiers isolated via NSGs
- **SSH restricted** — Access limited to deployer's IP only
- **HTTPS enforced** — Storage Account rejects unencrypted traffic
- **Azure Policy** — Resources require Environment tag (Deny effect)
- **RBAC** — Least-privilege access (Reader for test users, Secrets User for VM)

## Tech Stack

- **Infrastructure:** Azure CLI, Bicep (IaC)
- **Compute:** Ubuntu 22.04 VM with Nginx
- **Monitoring:** Azure Monitor, Log Analytics, Metric Alerts
- **CI/CD:** GitHub Actions (Bicep validation pipeline)
- **Security:** Key Vault, Managed Identity, NSGs, Azure Policy

## Project Structure

```
├── .github/
│   └── workflows/
│       └── validate.yml          # CI pipeline: Bicep build + lint
├── arm-templates/
│   └── main.bicep                # Infrastructure as Code
├── scripts/
│   ├── deploy.sh                 # Full deployment script
│   ├── cloud-init.yaml           # VM post-deployment config
│   └── policy-params.json        # Azure Policy parameters
├── .gitignore
└── README.md
```

## Quick Start

### Prerequisites
- Azure CLI installed and logged in
- Azure subscription with appropriate quotas
- Git

### Deploy

```bash
# Clone
git clone https://github.com/Ignius003/azure-logistics-infra.git
cd azure-logistics-infra

# Login to Azure
az login

# Run deployment (update <YOUR_IP> in deploy.sh first)
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

### Cleanup

```bash
# Deallocate VM (stop billing)
az vm deallocate --resource-group logistics-demo-rg --name logistics-vm

# Delete everything
az group delete --name logistics-demo-rg --yes --no-wait
```

## CI/CD Pipeline

Every push to `main` triggers automated validation:

1. Checkout code
2. Install Azure CLI + Bicep
3. Build Bicep template (syntax validation)
4. Lint check (best practices)

Future enhancement: Add CD step with Azure credentials for auto-deployment.

## Lessons Learned

- **Regional capacity constraints** — B-series VMs unavailable in West Europe; redeployed to North Europe using IaC scripts, demonstrating the value of Infrastructure as Code
- **Azure Policy enforcement** — Storage account creation blocked until HTTPS-only was enabled, validating governance controls
- **RBAC propagation** — Role assignments take up to 5 minutes to propagate; scripts include wait steps
- **Resource Provider registration** — Services like Key Vault and Monitor require explicit provider registration on new subscriptions

