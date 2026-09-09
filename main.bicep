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

module slackChannelInterfaces './modules/logicApp/slack-channelInterface.bicep' = [for channelInterface in channelInterfaces: {
  name: 'slackChannelInterface-${uniqueString(channelInterface)}-${environmentType}${environmentNumber}'
  params: {
    workflowName: 'SlackChannel-Interface-${channelInterface}-${environmentType}${environmentNumber}'
    location: location
    slackWebhookUrl: platformSecretsKeyVault.getSecret('slack-webhook-${channelInterface}')
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
    })
  }
}]

module slackChannelRouter './modules/logicApp/slack-router.bicep' = {
  params: {
    workflowName: 'SlackChannel-Router-${environmentType}${environmentNumber}'
    location: location
    defaultCallbackUrl: slackChannelInterfaces[indexOf(channelInterfaces, 'epr-alerts-platform-non-prod')].outputs.manualTriggerCallbackUrl
    slackChannels: [for (channelInterface, i) in channelInterfaces: {
      channelName: channelInterface
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
  name: 'acrVuln-${uniqueString('${rule.nameSuffix}-${rule.channel}-${environmentType}${environmentNumber}')}'
  params: {
    actionGroupId: genericActionGroup.outputs.actionGroupId
    alertName: '${rule.nameSuffix}-${rule.channel}-${environmentType}${environmentNumber}'
    customProperties: {
      AlertCategory: 'Security'
      SignalSource: 'DefenderForCloud'
      runbookUrl: rule.runbookUrl
      channel: rule.channel
    }
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
      AlertType: 'AcrVulnerability'
    })
    displayName: '${rule.nameSuffix}-${rule.channel}-${environmentType}${environmentNumber}'
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
  name: 'healthCheckAlert-${target.targetName}-${target.channel}'
  params: {
    alertName: 'HealthCheckAlert-${target.targetName}-${target.channel}'
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
    channel: target.channel
  }
}]

module appInsightsQueryAlerts './modules/scheduledQueryRule.bicep' = [for rule in appInsightsQueryRules: {
  name: 'appInsights-${uniqueString('${rule.nameSuffix}-${rule.channel}-${environmentType}${environmentNumber}')}'
  params: {
    actionGroupId: genericActionGroup.outputs.actionGroupId
    alertName: '${rule.nameSuffix}-${rule.channel}-${environmentType}${environmentNumber}'
    customProperties: {
      AlertCategory: 'Application'
      SignalSource: 'AppInsights'
      runbookUrl: rule.runbookUrl
      channel: rule.channel
    }
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
      AlertType: 'AppInsightsQuery'
    })
    displayName: '${rule.nameSuffix}-${rule.channel}-${environmentType}${environmentNumber}'
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
