// Parameters
@description('Location for all resources')
param location string = resourceGroup().location

@description('Environment tag')
param environment string = 'Development'

@description('Storage account name')
param storageAccountName string = 'logisticsdemosa2026'

@description('Key Vault name')
param keyVaultName string = 'logistics-kv2-2026'

@description('VM admin username')
param adminUsername string = 'azureuser'

@description('VM size')
param vmSize string = 'Standard_D2s_v3'

// Variables
var vnetName = 'logistics-vnet'
var webSubnetName = 'web-subnet'
var dataSubnetName = 'data-subnet'
var webNsgName = 'web-nsg'
var dataNsgName = 'data-nsg'
var vmName = 'logistics-vm'
var tags = {
  Environment: environment
  Project: 'LogisticsDemo'
  Owner: 'V'
}

// Web NSG
resource webNsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: webNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHTTP'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          destinationPortRange: '80'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowHTTPS'
        properties: {
          priority: 110
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          destinationPortRange: '443'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Data NSG
resource dataNsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: dataNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowFromWebSubnet'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: '10.0.1.0/24'
          destinationPortRange: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DenyAllOther'
        properties: {
          priority: 200
          access: 'Deny'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// VNet with Subnets
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        name: webSubnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: { id: webNsg.id }
        }
      }
      {
        name: dataSubnetName
        properties: {
          addressPrefix: '10.0.2.0/24'
          networkSecurityGroup: { id: dataNsg.id }
        }
      }
    ]
  }
}

// Storage Account
resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
  }
}

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
  }
}

// Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'logistics-law'
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

// Outputs
output vnetId string = vnet.id
output storageId string = storage.id
output keyVaultId string = keyVault.id
output workspaceId string = logAnalytics.id
