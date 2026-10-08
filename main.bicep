import { globalTags } from './common.bicep'

param channelInterfaces array
param channelInterfaceDefault string
param environmentNumber string
param environmentType string
param keyVaultName string
param location string = resourceGroup().location

var environmentKey = '${environmentType}${environmentNumber}'
var environmentScopedTags = union(globalTags, {
  Environment: environmentKey
})

var appInsightsQueryRules = concat(
  loadJsonContent('./data/platform/appinsights-query-rules.json')[?environmentKey] ?? [],
  loadJsonContent('./data/manage-account/appinsights-query-rules.json')[?environmentKey] ?? [],
  loadJsonContent('./data/manage-liabilities/appinsights-query-rules.json')[?environmentKey] ?? [],
  loadJsonContent('./data/meet-obligations/appinsights-query-rules.json')[?environmentKey] ?? [],
  loadJsonContent('./data/regulator-tooling/appinsights-query-rules.json')[?environmentKey] ?? [],
  loadJsonContent('./data/submit-data/appinsights-query-rules.json')[?environmentKey] ?? []
)

var healthcheckTargets = concat(
  loadJsonContent('./data/platform/healthcheck-targets.json')[?environmentKey] ?? [],
  loadJsonContent('./data/manage-account/healthcheck-targets.json')[?environmentKey] ?? [],
  loadJsonContent('./data/manage-liabilities/healthcheck-targets.json')[?environmentKey] ?? [],
  loadJsonContent('./data/meet-obligations/healthcheck-targets.json')[?environmentKey] ?? [],
  loadJsonContent('./data/regulator-tooling/healthcheck-targets.json')[?environmentKey] ?? [],
  loadJsonContent('./data/submit-data/healthcheck-targets.json')[?environmentKey] ?? []
)

resource platformSecretsKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

module commonAlertSchemaProcessor './modules/logicApp/slack-commonAlertSchema.bicep' = {
  params: {
    location: location
    routerCallbackUrl: slackChannelRouter.outputs.manualTriggerCallbackUrl
    tags: environmentScopedTags
    workflowName: 'SlackChannel-Processor-CommonAlertSchema-${environmentType}${environmentNumber}'
  }
}

module slackChannelInterfaces './modules/logicApp/slack-channelInterface.bicep' = [
  for channelInterface in channelInterfaces: {
    name: 'slackChannelInterface-${uniqueString(channelInterface)}-${environmentType}${environmentNumber}'
    params: {
      location: location
      slackWebhookUrl: platformSecretsKeyVault.getSecret('slack-webhook-${channelInterface}')
      tags: environmentScopedTags
      workflowName: 'SlackChannel-Interface-${channelInterface}-${environmentType}${environmentNumber}'
    }
  }
]

module slackChannelRouter './modules/logicApp/slack-router.bicep' = {
  params: {
    defaultCallbackUrl: slackChannelInterfaces[indexOf(channelInterfaces, channelInterfaceDefault)].outputs.manualTriggerCallbackUrl
    location: location
    slackChannels: [
      for (channelInterface, i) in channelInterfaces: {
        channelName: channelInterface
        callbackUrl: slackChannelInterfaces[i].outputs.manualTriggerCallbackUrl
      }
    ]
    tags: environmentScopedTags
    workflowName: 'SlackChannel-Router-${environmentType}${environmentNumber}'
  }
}

module genericActionGroup './modules/actionGroup/generic.bicep' = {
  params: {
    actionGroupName: 'ActionGroup-Generic-${environmentType}${environmentNumber}'
    groupShortName: 'TeamAlerts'
    tags: environmentScopedTags
    workflowCallbackUrl: commonAlertSchemaProcessor.outputs.manualTriggerCallbackUrl
    workflowResourceId: commonAlertSchemaProcessor.outputs.workflowResourceId
  }
}

module systemTopic './modules/systemTopic.bicep' = {
  params: {
    keyVaultName: keyVaultName
    keyVaultResourceGroup: resourceGroup().name
    keyVaultSubscriptionId: subscription().subscriptionId
    location: location
    systemTopicName: '${keyVaultName}-SecretExpiryTopic'
    tags: union(environmentScopedTags, {
      AlertType: 'KeyvaultEvents'
    })
  }
}

module eventSubscriptionsModules './modules/eventSubscription.bicep' = [
  for eventSubscription in loadJsonContent('./data/platform/keyvault-event-subscriptions.json'): {
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
  }
]

module healthCheckAlerts './modules/metricAlert/healthCheck-webApp.bicep' = [
  for target in healthcheckTargets: {
    name: 'healthCheckAlert-${target.targetName}-${target.channel}'
    params: {
      actionGroupIds: [
        genericActionGroup.outputs.actionGroupId
      ]
      alertName: 'HealthCheckAlert-${target.targetName}-${target.channel}'
      channel: target.channel
      description: target.description
      metricName: 'HealthCheckStatus'
      tags: union(environmentScopedTags, {
        AlertType: 'HealthCheck'
      })
      targetResourceGroup: target.targetResourceGroup
      targetResourceName: target.targetName
    }
  }
]

module acrVulnerabilityAlerts './modules/scheduledQueryRule.bicep' = [
  for rule in loadJsonContent('./data/platform/acr-vulnerability-query-rules.json')[?environmentKey] ?? []: {
    name: 'acrVuln-${uniqueString('${rule.nameSuffix}-${rule.channel}-${environmentType}${environmentNumber}')}'
    params: {
      actionGroupId: genericActionGroup.outputs.actionGroupId
      alertName: '${rule.nameSuffix}-${rule.channel}-${environmentType}${environmentNumber}'
      customProperties: {
        AlertCategory: 'Security'
        channel: rule.channel
        runbookUrl: rule.runbookUrl
        SignalSource: 'DefenderForCloud'
      }
      description: rule.description
      displayName: '${rule.nameSuffix}-${rule.channel}-${environmentType}${environmentNumber}'
      evaluationFrequency: rule.evaluationFrequency
      query: rule.query
      scopeResourceId: rule.scopeResourceId
      scopeResourceType: any(toLower(string(rule.scopeResourceType)))
      severity: rule.severity
      tags: union(environmentScopedTags, {
        AlertType: 'AcrVulnerability'
      })
      windowSize: rule.windowSize
    }
  }
]

module appInsightsQueryAlerts './modules/scheduledQueryRule.bicep' = [
  for rule in appInsightsQueryRules: {
    name: 'appInsights-${uniqueString('${rule.nameSuffix}-${rule.channel}-${environmentType}${environmentNumber}')}'
    params: {
      actionGroupId: genericActionGroup.outputs.actionGroupId
      alertName: '${rule.nameSuffix}-${rule.channel}-${environmentType}${environmentNumber}'
      customProperties: {
        AlertCategory: 'Application'
        channel: rule.channel
        runbookUrl: rule.runbookUrl
        SignalSource: 'AppInsights'
      }
      description: rule.description
      displayName: '${rule.nameSuffix}-${rule.channel}-${environmentType}${environmentNumber}'
      evaluationFrequency: rule.evaluationFrequency
      query: rule.query
      scopeResourceId: rule.scopeResourceId
      scopeResourceType: any(toLower(string(rule.scopeResourceType)))
      severity: rule.severity
      tags: union(environmentScopedTags, {
        AlertType: 'AppInsightsQuery'
      })
      windowSize: rule.windowSize
    }
  }
]
