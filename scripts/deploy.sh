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