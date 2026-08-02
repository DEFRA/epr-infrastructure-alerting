import { commonTags } from './common.bicep'

param environmentNumber string
param environmentType string
param location string = resourceGroup().location
param keyVaultName string
param logAnalyticsWorkspaceName string
param logAnalyticsWorkspaceResourceGroup string = resourceGroup().name

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
  scope: resourceGroup(logAnalyticsWorkspaceResourceGroup)
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

module healthCheckAlerts './modules/metricAlert.bicep' = [for target in loadJsonContent('./data/healthcheck-targets.json'): {
  params: {
    alertName: 'HealthCheckAlert-${target.targetName}'
    actionGroupIds: [
      genericActionGroup.outputs.actionGroupId
    ]
    targetResourceName: target.targetName
    targetResourceGroup: target.targetResourceGroup
    metricName: 'HealthCheckStatus'
    customTags: union(commonTags, {
      AlertType: 'HealthCheck'
      Environment: '${environmentType}${environmentNumber}'
    })
  }
}]

resource acrVulnerabilityAlerts 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = [for rule in loadJsonContent('./data/acr-vulnerability-query-rules.json'): {
  name: '${rule.nameSuffix}-${environmentType}${environmentNumber}'
  location: resourceGroup().location
  kind: 'LogAlert'
  tags: union(commonTags, {
    Environment: '${environmentType}${environmentNumber}'
    AlertType: 'AcrVulnerability'
  })
  properties: {
    displayName: '${rule.nameSuffix}-${environmentType}${environmentNumber}'
    description: rule.description
    enabled: true
    severity: rule.severity
    evaluationFrequency: 'PT1H'
    windowSize: 'PT1H'
    scopes: [
      logAnalyticsWorkspace.id
    ]
    targetResourceTypes: [
      'Microsoft.ContainerRegistry/registries'
    ]
    criteria: {
      allOf: [
        {
          query: rule.query
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            minFailingPeriodsToAlert: 1
            numberOfEvaluationPeriods: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        genericActionGroup.outputs.actionGroupId
      ]
      customProperties: {
        AlertCategory: 'Security'
        SignalSource: 'DefenderForCloud'
      }
    }
    autoMitigate: false
    skipQueryValidation: true
  }
}]
