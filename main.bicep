import { commonTags } from './common.bicep'

param appInsightsName string
param environmentNumber string
param environmentType string
param keyVaultName string
param location string = resourceGroup().location
param logAnalyticsWorkspaceName string
param slackWebhookPlatform string
param slackWebhookTeam1 string

var appInsightsQueryRules = concat(
  loadJsonContent('./data/team1/appinsights-query-rules.json')
)

var healthcheckTargets = concat(
  loadJsonContent('./data/platform/healthcheck-targets.json'),
  loadJsonContent('./data/team1/healthcheck-targets.json')
)

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
    slackWebhookUrl: platformSecretsKeyVault.getSecret(slackWebhookPlatform)
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

module acrVulnerabilityAlerts './modules/scheduledQueryRule.bicep' = [for rule in loadJsonContent('./data/platform/acr-vulnerability-query-rules.json'): {
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
    evaluationFrequency: 'PT24H'
    query: rule.query
    scopeResourceId: logAnalyticsWorkspace.id
    severity: rule.severity
    targetResourceTypes: [
      'Microsoft.ContainerRegistry/registries'
    ]
    windowSize: 'PT24H'
  }
}]

module eventSubscriptionsModules './modules/eventSubscription.bicep' = [for eventSubscription in loadJsonContent('./data/platform/keyvault-event-subscriptions.json'): {
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

module healthCheckAlerts './modules/metricAlert/healthCheck-webApp.bicep' = [for target in healthcheckTargets: {
  params: {
    alertName: 'HealthCheckAlert-${replace(replace(target.targetName, '{ENV}', environmentType), '{ENV_NO}', environmentNumber)}'
    actionGroupIds: [
      genericActionGroup.outputs.actionGroupId
    ]
    targetResourceName: replace(replace(target.targetName, '{ENV}', environmentType), '{ENV_NO}', environmentNumber)
    targetResourceGroup: replace(replace(target.targetResourceGroup, '{ENV}', environmentType), '{ENV_NO}', environmentNumber)
    metricName: 'HealthCheckStatus'
    description: replace(replace(target.description, '{ENV}', environmentType), '{ENV_NO}', environmentNumber)
    customTags: union(commonTags, {
      AlertType: 'HealthCheck'
      Environment: '${environmentType}${environmentNumber}'
    })
  }
}]

module appInsightsQueryAlerts './modules/scheduledQueryRule.bicep' = [for rule in appInsightsQueryRules: {
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
