import { commonTags } from './common.bicep'

param appInsightsName string
param environmentNumber string
param environmentType string
param keyVaultName string
param location string = resourceGroup().location
param logAnalyticsWorkspaceName string
param slackWebhookSecretName string

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource appInsightsComponent 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource platformSecretsKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

module genericSlackLogicApps './modules/logicApp/slack-commonAlertSchema.bicep' = {
  params: {
    workflowName: 'SlackChannel-CommonAlertSchema'
    location: location
    slackWebhookUrl: platformSecretsKeyVault.getSecret(slackWebhookSecretName)
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
    })
  }
}

module genericActionGroup './modules/actionGroup/generic.bicep' = {
  params: {
    actionGroupName: 'ActionGroup-Generic'
    groupShortName: 'TeamAlerts'
    workflowResourceId: genericSlackLogicApps.outputs.workflowResourceId
    workflowCallbackUrl: genericSlackLogicApps.outputs.manualTriggerCallbackUrl
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
    })
  }
}

module systemTopic './modules/systemTopic.bicep' = {
  params: {
    systemTopicName: '${keyVaultName}-SecretExpiryTopic'
    keyVaultName: keyVaultName
    keyVaultResourceGroup: resourceGroup().name
    keyVaultSubscriptionId: subscription().subscriptionId
    location: location
    customTags: union(commonTags, {
      AlertType: 'KeyvaultEvents'
      Environment: '${environmentType}${environmentNumber}'
    })
  }
}

module eventSubscriptionsModules './modules/eventSubscription.bicep' = [for eventSubscription in loadJsonContent('./data/keyvault-event-subscriptions.json'): {
  params: {
    actionGroupResourceIds: [
      genericActionGroup.outputs.actionGroupId
    ]
    eventSubscriptionDescription: eventSubscription.description
    eventSubscriptionName: '${keyVaultName}-${eventSubscription.nameSuffix}'
    includedEventTypes: eventSubscription.eventTypes
    monitorAlertSeverity: eventSubscription.severity
    systemTopicName: systemTopic.outputs.systemTopicName
  }
}]

module healthCheckAlerts './modules/metricAlert/healthCheck-webApp.bicep' = [for target in loadJsonContent('./data/healthcheck-targets.json'): {
  params: {
    alertName: 'HealthCheckAlert-${target.targetName}'
    actionGroupIds: [
      genericActionGroup.outputs.actionGroupId
    ]
    targetResourceName: target.targetName
    targetResourceGroup: target.targetResourceGroup
    metricName: 'HealthCheckStatus'
    description: target.description
    customTags: union(commonTags, {
      AlertType: 'HealthCheck'
      Environment: '${environmentType}${environmentNumber}'
    })
  }
}]

module acrVulnerabilityAlerts './modules/scheduledQueryRule.bicep' = [for rule in loadJsonContent('./data/acr-vulnerability-query-rules.json'): {
  name: 'acrVulnerability-${rule.nameSuffix}-${environmentType}${environmentNumber}'
  params: {
    actionGroupId: genericActionGroup.outputs.actionGroupId
    alertName: '${rule.nameSuffix}-${environmentType}${environmentNumber}'
    customProperties: {
      AlertCategory: 'Security'
      SignalSource: 'DefenderForCloud'
      runbookUrl: rule.runbookUrl
    }
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
      AlertType: 'AcrVulnerability'
    })
    displayName: '${rule.nameSuffix}-${environmentType}${environmentNumber}'
    description: rule.description
    evaluationFrequency: 'PT1H'
    query: rule.query
    scopeResourceId: logAnalyticsWorkspace.id
    severity: rule.severity
    targetResourceTypes: [
      'Microsoft.ContainerRegistry/registries'
    ]
    windowSize: 'PT1H'
  }
}]

module appInsightsQueryAlerts './modules/scheduledQueryRule.bicep' = [for rule in loadJsonContent('./data/appinsights-query-rules.json'): {
  name: 'appInsightsQuery-${rule.nameSuffix}-${environmentType}${environmentNumber}'
  params: {
    actionGroupId: genericActionGroup.outputs.actionGroupId
    alertName: '${rule.nameSuffix}-${environmentType}${environmentNumber}'
    customProperties: {
      AlertCategory: 'Application'
      SignalSource: 'AppInsights'
      runbookUrl: rule.runbookUrl
    }
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
      AlertType: 'AppInsightsQuery'
    })
    displayName: '${rule.nameSuffix}-${environmentType}${environmentNumber}'
    description: rule.description
    evaluationFrequency: rule.evaluationFrequency
    query: rule.query
    scopeResourceId: appInsightsComponent.id
    severity: rule.severity
    targetResourceTypes: [
      'Microsoft.Insights/components'
    ]
    windowSize: rule.windowSize
  }
}]
