import { alertTeamType, commonTags } from './common.bicep'

param teams alertTeamType[] = []
param environmentNumber string
param environmentType string
param location string = resourceGroup().location

module slackLogicApps './modules/logic-app/slack-alerting.bicep' = [for team in teams: {
  params: {
    workflowName: 'SlackChannel-${team.teamKey}'
    location: location
    slackWebhookUrl: team.slackWebhookUrl
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
      AlertChannel: team.teamKey
      Team: team.teamKey
    })
  }
}]

module acrVulnerabilitySlackLogicApps './modules/logic-app/slack-acrVulnerability.bicep' = [for team in teams: {
  params: {
    workflowName: 'SlackChannel-AcrVulnerability-${team.teamKey}'
    location: location
    slackWebhookUrl: team.slackWebhookUrl
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
      AlertChannel: team.teamKey
      Team: team.teamKey
      AlertType: 'ACR-VULNERABILITY'
    })
  }
}]

module genericSlackLogicApps './modules/logic-app/slack-generic.bicep' = {
  params: {
    workflowName: 'SlackChannel-Generic'
    location: location
    slackWebhookUrl: '***REMOVED***'
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
      AlertChannel: 'Generic'
      AlertType: 'GENERIC'
    })
  }
}

module healthCheckSlackLogicApps './modules/logic-app/slack-healthCheckStatus.bicep' = [for team in teams: {
  params: {
    workflowName: 'SlackChannel-HealthCheck-${team.teamKey}'
    location: location
    slackWebhookUrl: team.slackWebhookUrl
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
      AlertChannel: team.teamKey
      Team: team.teamKey
      AlertType: 'HEALTH-CHECK'
    })
  }
}]

var slackTeamKeys = [for team in teams: team.teamKey]

module alertActionGroups './modules/action-group/alerting.bicep' = [for team in teams: {
  params: {
    actionGroupName: team.actionGroupName
    groupShortName: 'TeamAlerts'
    workflowResourceId: slackLogicApps[indexOf(slackTeamKeys, team.teamKey)].outputs.workflowResourceId
    workflowCallbackUrl: slackLogicApps[indexOf(slackTeamKeys, team.teamKey)].outputs.manualTriggerCallbackUrl
    emailReceivers: team.emailReceivers
    webhookReceivers: team.webhookReceivers
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
      AlertChannel: team.teamKey
      Team: team.teamKey
    })
  }
}]

module acrVulnerabilityActionGroups './modules/action-group/acrVulnerability.bicep' = [for (team, i) in teams: {
  params: {
    actionGroupName: '${team.actionGroupName}-AcrVulnerability'
    groupShortName: 'TeamAlerts'
    workflowResourceId: acrVulnerabilitySlackLogicApps[i].outputs.workflowResourceId
    workflowCallbackUrl: acrVulnerabilitySlackLogicApps[i].outputs.manualTriggerCallbackUrl
    emailReceivers: team.emailReceivers
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
      AlertChannel: team.teamKey
      Team: team.teamKey
      AlertType: 'ACR-VULNERABILITY'
    })
  }
}]

module healthCheckStatusActionGroups './modules/action-group/healthCheckStatus.bicep' = [for (team, i) in teams: {
  params: {
    actionGroupName: '${team.actionGroupName}-HealthCheckStatus'
    groupShortName: 'TeamAlerts'
    workflowResourceId: healthCheckSlackLogicApps[i].outputs.workflowResourceId
    workflowCallbackUrl: healthCheckSlackLogicApps[i].outputs.manualTriggerCallbackUrl
    emailReceivers: team.emailReceivers
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
      AlertChannel: team.teamKey
      Team: team.teamKey
      AlertType: 'HEALTH-CHECK'
    })
  }
}]

module genericActionGroup './modules/action-group/generic.bicep' = {
  params: {
    actionGroupName: 'ActionGroup-Generic'
    groupShortName: 'TeamAlerts'
    workflowResourceId: genericSlackLogicApps.outputs.workflowResourceId
    workflowCallbackUrl: genericSlackLogicApps.outputs.manualTriggerCallbackUrl
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
      AlertType: 'GENERIC'
    })
  }
}

// Action group IDs are safe to output - consumers reference these to attach alerts
output channels array = [for (team, i) in teams: {
  teamKey: team.teamKey
  actionGroupId: alertActionGroups[i].outputs.actionGroupId
  actionGroupName: alertActionGroups[i].outputs.actionGroupName
  acrVulnerabilityActionGroupId: acrVulnerabilityActionGroups[i].outputs.actionGroupId
  acrVulnerabilityActionGroupName: acrVulnerabilityActionGroups[i].outputs.actionGroupName
  healthCheckStatusActionGroupId: healthCheckStatusActionGroups[i].outputs.actionGroupId
  healthCheckStatusActionGroupName: healthCheckStatusActionGroups[i].outputs.actionGroupName
}]
