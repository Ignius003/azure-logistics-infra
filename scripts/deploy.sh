#!/bin/bash
# Azure Logistics Infrastructure Deployment Script

# Variables - set these before running
RESOURCE_GROUP="logistics-demo-rg"
LOCATION="northeurope"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Step 2: Create Resource Group with Tags
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION \
  --tags Environment=Development Project=LogisticsDemo Owner=V

# Step 3: Azure Policy - Require Environment Tag
az policy assignment create \
  --name "require-env-tag" \
  --display-name "Require Environment Tag" \
  --policy "871b6d14-10aa-478d-b590-94f262ecfa99" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP" \
  --params '{"tagName":{"value":"Environment"}}'

# Step 4: Create VNet + Subnets
az network vnet create \
  --resource-group $RESOURCE_GROUP \
  --name logistics-vnet \
  --address-prefix 10.0.0.0/16 \
  --subnet-name web-subnet \
  --subnet-prefix 10.0.1.0/24 \
  --tags Environment=Development

az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name logistics-vnet \
  --name data-subnet \
  --address-prefix 10.0.2.0/24

# Step 5: Create NSGs

# Web NSG - allows HTTP, HTTPS, SSH from internet
az network nsg create \
  --resource-group $RESOURCE_GROUP \
  --name web-nsg \
  --tags Environment=Development

az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name web-nsg \
  --name AllowHTTP \
  --priority 100 \
  --access Allow \
  --direction Inbound \
  --protocol Tcp \
  --source-address-prefixes Internet \
  --destination-port-ranges 80

az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name web-nsg \
  --name AllowHTTPS \
  --priority 110 \
  --access Allow \
  --direction Inbound \
  --protocol Tcp \
  --source-address-prefixes Internet \
  --destination-port-ranges 443

az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name web-nsg \
  --name AllowSSH \
  --priority 120 \
  --access Allow \
  --direction Inbound \
  --protocol Tcp \
  --source-address-prefixes Internet \
  --destination-port-ranges 22

# Data NSG - allows traffic ONLY from web-subnet
az network nsg create \
  --resource-group $RESOURCE_GROUP \
  --name data-nsg \
  --tags Environment=Development

az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name data-nsg \
  --name AllowFromWebSubnet \
  --priority 100 \
  --access Allow \
  --direction Inbound \
  --protocol "*" \
  --source-address-prefixes 10.0.1.0/24 \
  --destination-port-ranges "*"

az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name data-nsg \
  --name DenyAllOther \
  --priority 200 \
  --access Deny \
  --direction Inbound \
  --protocol "*" \
  --source-address-prefixes "*" \
  --destination-port-ranges "*"

# Associate NSGs to Subnets
VNET_NAME="logistics-vnet"

az network vnet subnet update \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name web-subnet \
  --network-security-group web-nsg

az network vnet subnet update \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name data-subnet \
  --network-security-group data-nsg

# Step 6: Create Storage Account + Blob Container
STORAGE_NAME="logisticsdemosa2026"

az storage account create \
  --resource-group $RESOURCE_GROUP \
  --name $STORAGE_NAME \
  --location $LOCATION \
  --sku Standard_LRS \
  --access-tier Hot \
  --https-only True \
  --tags Environment=Development

az storage container create \
  --account-name $STORAGE_NAME \
  --name static-files \
  --auth-mode login



# Step 7: Create Key Vault + Secret
KEYVAULT_NAME="logistics-kv2-2026"

az keyvault create \
  --resource-group $RESOURCE_GROUP \
  --name $KEYVAULT_NAME \
  --location $LOCATION \
  --enable-rbac-authorization true \
  --tags Environment=Development


# Assign Key Vault Secrets Officer to deployer
USER_ID=$(az ad signed-in-user show --query id -o tsv)
az role assignment create \
  --role "Key Vault Secrets Officer" \
  --assignee $USER_ID \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KEYVAULT_NAME"

az keyvault secret set \
  --vault-name $KEYVAULT_NAME \
  --name "db-connection-string" \
  --value "<REPLACE_WITH_ACTUAL_SECRET>"


# Step 8: Create VM with Managed Identity + Nginx
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name logistics-vm \
  --image Ubuntu2204 \
  --size Standard_D2s_v3 \
  --vnet-name $VNET_NAME \
  --subnet web-subnet \
  --nsg web-nsg \
  --admin-username azureuser \
  --generate-ssh-keys \
  --assign-identity \
  --custom-data scripts/cloud-init.yaml \
  --tags Environment=Development

# Grant VM access to Key Vault secrets
VM_IDENTITY=$(az vm show \
  --resource-group $RESOURCE_GROUP \
  --name logistics-vm \
  --query identity.principalId -o tsv)

az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee $VM_IDENTITY \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KEYVAULT_NAME"


# Step 9: RBAC - Create test user with Reader role
# Run manually
# az ad user create --display-name "Test Reader" --user-principal-name <YOUR_UPN> --password "<PASSWORD>"
# az role assignment create --role "Reader" --assignee <USER_ID> --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"
