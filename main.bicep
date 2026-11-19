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

// One alerts.json per team folder under data/. To add a team, add a line here.
// (Bicep can't build this list in a loop: loadJsonContent needs a literal path.)
var teamFiles = [
  { team: 'manage-account', config: loadJsonContent('data/manage-account/alerts.json') }
  { team: 'manage-liabilities', config: loadJsonContent('data/manage-liabilities/alerts.json') }
  { team: 'meet-obligations', config: loadJsonContent('data/meet-obligations/alerts.json') }
  { team: 'platform', config: loadJsonContent('data/platform/alerts.json') }
  { team: 'regulator-tooling', config: loadJsonContent('data/regulator-tooling/alerts.json') }
  { team: 'submit-data', config: loadJsonContent('data/submit-data/alerts.json') }
]

// A team's alerts go to epr-alerts-<team>-prod in PRD and epr-alerts-<team>-non-prod elsewhere,
// unless an alert sets its own `channel`.
var channelSuffix = environmentType == 'PRD' ? 'prod' : 'non-prod'

var teamConfigs = [
  for tf in teamFiles: {
    channel: 'epr-alerts-${tf.team}-${channelSuffix}'
    healthChecks: tf.config.?healthChecks[?environmentKey] ?? []
    queryAlerts: tf.config.?queryAlerts ?? []
    keyVaultRoutes: tf.config.?keyVaultRoutes ?? []
  }
]

var healthcheckTargets = flatten(map(teamConfigs, tc => map(tc.healthChecks, h => {
  targetName: h.app
  targetResourceGroup: h.resourceGroup
  description: h.?description ?? 'Health check for ${h.app} dropped below 100% in the last 5 minutes'
  channel: h.?channel ?? tc.channel
})))

// Query alerts are defined once per team; `environments` lists where each one is deployed,
// with the target resource and any per-environment overrides.
var queryAlertKinds = {
  AppInsightsQuery: { deploymentPrefix: 'appInsights', alertCategory: 'Application', signalSource: 'AppInsights' }
  AcrVulnerability: { deploymentPrefix: 'acrVuln', alertCategory: 'Security', signalSource: 'DefenderForCloud' }
}

var queryAlertsForEnvironment = flatten(map(teamConfigs, tc => map(
  filter(tc.queryAlerts, a => contains(a.environments, environmentKey)),
  a => union(a, a.environments[environmentKey], { teamChannel: tc.channel })
)))

var queryAlerts = map(queryAlertsForEnvironment, q => {
  name: q.name
  kind: q.?kind ?? 'AppInsightsQuery'
  description: replace(q.?description ?? q.name, '{env}', environmentKey)
  query: q.query
  severity: q.?severity ?? 3
  evaluationFrequency: q.?frequency ?? 'PT5M'
  windowSize: q.?window ?? (q.?frequency ?? 'PT5M')
  runbookUrl: q.?runbookUrl ?? ''
  channel: q.?channel ?? q.teamChannel
  scopeResourceId: q.target
  scopeResourceType: contains(toLower(q.target), '/microsoft.operationalinsights/workspaces/') ? 'loganalytics' : 'appinsights'
})

// Event Grid advanced filters on the event subject (the secret/certificate name).
// Advanced filters are ANDed, so use objectNames OR objectNamePrefixes per entry;
// excludedObjectNames and excludedObjectNamePrefixes can be combined with either.
func keyVaultSubjectFilters(entry object) array => concat(
  empty(entry.?objectNames ?? []) ? [] : [{ operatorType: 'StringIn', key: 'subject', values: entry.objectNames }],
  empty(entry.?objectNamePrefixes ?? []) ? [] : [{ operatorType: 'StringBeginsWith', key: 'subject', values: entry.objectNamePrefixes }],
  empty(entry.?excludedObjectNames ?? []) ? [] : [{ operatorType: 'StringNotIn', key: 'subject', values: entry.excludedObjectNames }],
  empty(entry.?excludedObjectNamePrefixes ?? []) ? [] : [{ operatorType: 'StringNotBeginsWith', key: 'subject', values: entry.excludedObjectNamePrefixes }]
)

var keyVaultSecretRoutes = flatten(map(teamConfigs, tc => map(tc.keyVaultRoutes, r => union(r, {
  channel: r.?channel ?? tc.channel
}))))

// Flattened, lower-cased match rules for the processor Logic App. Exact names come first,
// then prefixes longest-first, so the most specific route wins.
var keyVaultSecretRouteRules = concat(
  flatten(map(keyVaultSecretRoutes, route => map(route.?objectNames ?? [], name => {
    match: 'exact'
    value: toLower(name)
    channel: route.channel
  }))),
  sort(
    flatten(map(keyVaultSecretRoutes, route => map(filter(route.?objectNamePrefixes ?? [], prefix => !empty(prefix)), prefix => {
      match: 'prefix'
      value: toLower(prefix)
      channel: route.channel
    }))),
    (a, b) => length(a.value) > length(b.value)
  )
)

resource platformSecretsKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

module commonAlertSchemaProcessor './modules/logicApp/slack-commonAlertSchema.bicep' = {
  params: {
    defaultChannel: channelInterfaceDefault
    keyVaultSecretRoutes: keyVaultSecretRouteRules
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
      advancedFilters: keyVaultSubjectFilters(eventSubscription)
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
      environmentType: environmentType
      metricName: 'HealthCheckStatus'
      tags: union(environmentScopedTags, {
        AlertType: 'HealthCheck'
      })
      targetResourceGroup: target.targetResourceGroup
      targetResourceName: target.targetName
    }
  }
]

module queryAlertRules './modules/scheduledQueryRule.bicep' = [
  for rule in queryAlerts: {
    name: '${queryAlertKinds[rule.kind].deploymentPrefix}-${uniqueString('${rule.name}-${rule.channel}-${environmentType}${environmentNumber}')}'
    params: {
      actionGroupId: genericActionGroup.outputs.actionGroupId
      alertName: '${rule.name}-${rule.channel}-${environmentType}${environmentNumber}'
      customProperties: {
        AlertCategory: queryAlertKinds[rule.kind].alertCategory
        channel: rule.channel
        runbookUrl: rule.runbookUrl
        SignalSource: queryAlertKinds[rule.kind].signalSource
      }
      description: rule.description
      displayName: '${rule.name}-${rule.channel}-${environmentType}${environmentNumber}'
      evaluationFrequency: rule.evaluationFrequency
      query: rule.query
      scopeResourceId: rule.scopeResourceId
      scopeResourceType: any(rule.scopeResourceType)
      severity: rule.severity
      tags: union(environmentScopedTags, {
        AlertType: rule.kind
      })
      windowSize: rule.windowSize
    }
  }
]
