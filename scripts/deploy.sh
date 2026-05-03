#!/bin/bash
# Azure Logistics Infrastructure Deployment Script

# Variables - set these before running
RESOURCE_GROUP="logistics-demo-rg"
LOCATION="westeurope"
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
  --params scripts/policy-params.json

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