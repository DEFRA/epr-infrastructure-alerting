import { commonTags } from './common.bicep'

param appInsightsName string
param environmentNumber string
param environmentType string
param keyVaultName string
param location string = resourceGroup().location
param logAnalyticsWorkspaceName string
param channelInterfaces object

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

module commonAlertSchemaProcessor './modules/logicApp/slack-commonAlertSchema.bicep' = {
  params: {
    workflowName: 'SlackChannel-Processor-CommonAlertSchema'
    location: location
    routerCallbackUrl: slackChannelRouter.outputs.manualTriggerCallbackUrl
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
    })
  }
}

module slackChannelInterfacePlatform './modules/logicApp/slack-channelInterface.bicep' = {
  params: {
    workflowName: 'SlackChannel-Interface-platform'
    location: location
    slackWebhookUrl: platformSecretsKeyVault.getSecret(channelInterfaces.platform)
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
    })
  }
}

module slackChannelInterfaceTeam1 './modules/logicApp/slack-channelInterface.bicep' = {
  params: {
    workflowName: 'SlackChannel-Interface-team1'
    location: location
    slackWebhookUrl: platformSecretsKeyVault.getSecret(channelInterfaces.team1)
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
    })
  }
}

module slackChannelRouter './modules/logicApp/slack-router.bicep' = {
  params: {
    workflowName: 'SlackChannel-Router'
    location: location
    platformCallbackUrl: slackChannelInterfacePlatform.outputs.manualTriggerCallbackUrl
    team1CallbackUrl: slackChannelInterfaceTeam1.outputs.manualTriggerCallbackUrl
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
    })
  }
}

module genericActionGroup './modules/actionGroup/generic.bicep' = {
  params: {
    actionGroupName: 'ActionGroup-Generic'
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
  name: 'acrVulnerability-${rule.nameSuffix}-${environmentType}${environmentNumber}-${rule.team}'
  params: {
    actionGroupId: genericActionGroup.outputs.actionGroupId
    alertName: '${rule.nameSuffix}-${environmentType}${environmentNumber}-${rule.team}'
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
    displayName: '${rule.nameSuffix}-${environmentType}${environmentNumber}-${rule.team}'
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
  name: 'healthCheckAlert-${replace(replace(target.targetName, '{ENV}', environmentType), '{ENV_NO}', environmentNumber)}-${target.team}'
  params: {
    alertName: 'HealthCheckAlert-${replace(replace(target.targetName, '{ENV}', environmentType), '{ENV_NO}', environmentNumber)}-${target.team}'
    actionGroupIds: [
      genericActionGroup.outputs.actionGroupId
    ]
    customTags: union(commonTags, {
      AlertType: 'HealthCheck'
      Environment: '${environmentType}${environmentNumber}'
    })
    description: replace(replace(target.description, '{ENV}', environmentType), '{ENV_NO}', environmentNumber)
    metricName: 'HealthCheckStatus'
    targetResourceName: replace(replace(target.targetName, '{ENV}', environmentType), '{ENV_NO}', environmentNumber)
    targetResourceGroup: replace(replace(target.targetResourceGroup, '{ENV}', environmentType), '{ENV_NO}', environmentNumber)
    team: target.team
  }
}]

module appInsightsQueryAlerts './modules/scheduledQueryRule.bicep' = [for rule in appInsightsQueryRules: {
  name: 'appInsightsQuery-${rule.nameSuffix}-${environmentType}${environmentNumber}-${rule.team}'
  params: {
    actionGroupId: genericActionGroup.outputs.actionGroupId
    alertName: '${rule.nameSuffix}-${environmentType}${environmentNumber}-${rule.team}'
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
    displayName: '${rule.nameSuffix}-${environmentType}${environmentNumber}-${rule.team}'
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
