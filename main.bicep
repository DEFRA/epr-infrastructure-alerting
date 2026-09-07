import { commonTags } from './common.bicep'

param appInsightsName string
param environmentNumber string
param environmentType string
param keyVaultName string
param location string = resourceGroup().location
param logAnalyticsWorkspaceName string
param channelInterfaces array

var appInsightsQueryRules = concat(
  loadJsonContent('./data/team1/appinsights-query-rules.json')
)

var environmentKey = '${environmentType}${environmentNumber}'
var platformHealthcheckTargetsByEnvironment = loadJsonContent('./data/platform/healthcheck-targets.json')
var team1HealthcheckTargetsByEnvironment = loadJsonContent('./data/team1/healthcheck-targets.json')
var healthcheckTargets = concat(
  platformHealthcheckTargetsByEnvironment[?environmentKey] ?? [],
  team1HealthcheckTargetsByEnvironment[?environmentKey] ?? []
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

module commonAlertSchemaProcessor './modules/logicApp/slack-commonAlertSchema.bicep' = {
  params: {
    workflowName: 'SlackChannel-Processor-CommonAlertSchema-${environmentType}${environmentNumber}'
    location: location
    routerCallbackUrl: slackChannelRouter.outputs.manualTriggerCallbackUrl
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
    })
  }
}

module slackChannelInterfaces './modules/logicApp/slack-channelInterface.bicep' = [for (channelInterface, i) in channelInterfaces: {
  name: 'slackChannelInterface-${channelInterface.team}-${environmentType}${environmentNumber}'
  params: {
    workflowName: 'SlackChannel-Interface-${channelInterface.team}-${environmentType}${environmentNumber}'
    location: location
    slackWebhookUrl: platformSecretsKeyVault.getSecret(channelInterface.secretName)
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
    })
  }
}]

var teamNames = [for channelInterface in channelInterfaces: channelInterface.team]
var platformRouteIndex = indexOf(teamNames, 'Platform')

module slackChannelRouter './modules/logicApp/slack-router.bicep' = {
  params: {
    workflowName: 'SlackChannel-Router-${environmentType}${environmentNumber}'
    location: location
    defaultCallbackUrl: slackChannelInterfaces[platformRouteIndex].outputs.manualTriggerCallbackUrl
    teamRoutes: [for (channelInterface, i) in channelInterfaces: {
      team: channelInterface.team
      callbackUrl: slackChannelInterfaces[i].outputs.manualTriggerCallbackUrl
    }]
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
    })
  }
}

module genericActionGroup './modules/actionGroup/generic.bicep' = {
  params: {
    actionGroupName: 'ActionGroup-Generic-${environmentType}${environmentNumber}'
    groupShortName: 'TeamAlerts'
    workflowResourceId: commonAlertSchemaProcessor.outputs.workflowResourceId
    workflowCallbackUrl: commonAlertSchemaProcessor.outputs.manualTriggerCallbackUrl
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

module acrVulnerabilityAlerts './modules/scheduledQueryRule.bicep' = [for rule in loadJsonContent('./data/platform/acr-vulnerability-query-rules.json'): {
  name: 'acrVulnerability-${rule.nameSuffix}-${rule.team}-${environmentType}${environmentNumber}'
  params: {
    actionGroupId: genericActionGroup.outputs.actionGroupId
    alertName: '${rule.nameSuffix}-${rule.team}-${environmentType}${environmentNumber}'
    customProperties: {
      AlertCategory: 'Security'
      SignalSource: 'DefenderForCloud'
      runbookUrl: rule.runbookUrl
      team: rule.team
    }
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
      AlertType: 'AcrVulnerability'
    })
    displayName: '${rule.nameSuffix}-${rule.team}-${environmentType}${environmentNumber}'
    description: rule.description
    evaluationFrequency: 'P1D'
    query: rule.query
    scopeResourceId: logAnalyticsWorkspace.id
    severity: rule.severity
    targetResourceTypes: [
      'Microsoft.ContainerRegistry/registries'
    ]
    windowSize: 'P1D'
  }
}]

module healthCheckAlerts './modules/metricAlert/healthCheck-webApp.bicep' = [for target in healthcheckTargets: {
  name: 'healthCheckAlert-${target.targetName}-${target.team}'
  params: {
    alertName: 'HealthCheckAlert-${target.targetName}-${target.team}'
    actionGroupIds: [
      genericActionGroup.outputs.actionGroupId
    ]
    customTags: union(commonTags, {
      AlertType: 'HealthCheck'
      Environment: '${environmentType}${environmentNumber}'
    })
    description: target.description
    metricName: 'HealthCheckStatus'
    targetResourceName: target.targetName
    targetResourceGroup: target.targetResourceGroup
    team: target.team
  }
}]

module appInsightsQueryAlerts './modules/scheduledQueryRule.bicep' = [for rule in appInsightsQueryRules: {
  name: 'appInsightsQuery-${rule.nameSuffix}-${rule.team}-${environmentType}${environmentNumber}'
  params: {
    actionGroupId: genericActionGroup.outputs.actionGroupId
    alertName: '${rule.nameSuffix}-${rule.team}-${environmentType}${environmentNumber}'
    customProperties: {
      AlertCategory: 'Application'
      SignalSource: 'AppInsights'
      runbookUrl: rule.runbookUrl
      team: rule.team
    }
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
      AlertType: 'AppInsightsQuery'
    })
    displayName: '${rule.nameSuffix}-${rule.team}-${environmentType}${environmentNumber}'
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
