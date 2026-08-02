param systemTopicName string
param keyVaultName string
param keyVaultResourceGroup string
param keyVaultSubscriptionId string = subscription().subscriptionId
param location string = resourceGroup().location
param customTags object = {}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
  scope: resourceGroup(keyVaultSubscriptionId, keyVaultResourceGroup)
}

resource systemTopic 'Microsoft.EventGrid/systemTopics@2022-06-15' = {
  name: systemTopicName
  location: location
  tags: customTags
  properties: {
    source: keyVault.id
    topicType: 'Microsoft.KeyVault.vaults'
  }
}

output systemTopicId string = systemTopic.id
output systemTopicName string = systemTopic.name
