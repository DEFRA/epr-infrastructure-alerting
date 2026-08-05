import { commonTags } from './common.bicep'

param environmentNumber string
param environmentType string
param location string = resourceGroup().location
param keyVaultName string
param logAnalyticsWorkspaceName string
param logAnalyticsWorkspaceResourceGroup string = resourceGroup().name
param appInsightsName string
param appInsightsResourceGroup string = resourceGroup().name

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
  scope: resourceGroup(logAnalyticsWorkspaceResourceGroup)
}

resource appInsightsComponent 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
  scope: resourceGroup(appInsightsResourceGroup)
}

module genericSlackLogicApps './modules/logicApp/slack-commonAlertSchema.bicep' = {
  params: {
    workflowName: 'SlackChannel-CommonAlertSchema'
    location: location
    slackWebhookUrl: '***REMOVED***'
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

module acrVulnerabilityAlerts './modules/scheduledQuery/log-query-alert.bicep' = [for rule in loadJsonContent('./data/acr-vulnerability-query-rules.json'): {
  name: 'acrVulnerability-${rule.nameSuffix}-${environmentType}${environmentNumber}'
  params: {
    alertName: '${rule.nameSuffix}-${environmentType}${environmentNumber}'
    displayName: '${rule.nameSuffix}-${environmentType}${environmentNumber}'
    description: rule.description
    severity: rule.severity
    evaluationFrequency: 'PT1H'
    windowSize: 'PT1H'
    query: rule.query
    scopeResourceId: logAnalyticsWorkspace.id
    targetResourceTypes: [
      'Microsoft.ContainerRegistry/registries'
    ]
    actionGroupId: genericActionGroup.outputs.actionGroupId
    customProperties: {
      AlertCategory: 'Security'
      SignalSource: 'DefenderForCloud'
      runbookUrl: rule.runbookUrl
    }
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
      AlertType: 'AcrVulnerability'
    })
  }
}]

module appInsightsQueryAlerts './modules/scheduledQuery/log-query-alert.bicep' = [for rule in loadJsonContent('./data/appinsights-query-rules.json'): {
  name: 'appInsightsQuery-${rule.nameSuffix}-${environmentType}${environmentNumber}'
  params: {
    alertName: '${rule.nameSuffix}-${environmentType}${environmentNumber}'
    displayName: '${rule.nameSuffix}-${environmentType}${environmentNumber}'
    description: rule.description
    severity: rule.severity
    evaluationFrequency: rule.evaluationFrequency
    windowSize: rule.windowSize
    query: rule.query
    scopeResourceId: appInsightsComponent.id
    targetResourceTypes: [
      'Microsoft.Insights/components'
    ]
    actionGroupId: genericActionGroup.outputs.actionGroupId
    customProperties: {
      AlertCategory: 'Application'
      SignalSource: 'AppInsights'
      runbookUrl: rule.runbookUrl
    }
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
      AlertType: 'AppInsightsQuery'
    })
  }
}]
