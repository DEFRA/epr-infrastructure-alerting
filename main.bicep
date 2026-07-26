import { alertTeamType, commonTags } from './common.bicep'

param teams alertTeamType[] = []
param environmentNumber string
param environmentType string
param location string = resourceGroup().location
@secure()
param slackWebhookUrls object = {}

module slackLogicApps './modules/slack-alerting-logic-app.bicep' = [for team in teams: {
  params: {
    workflowName: team.slackWorkflowName
    location: location
    slackWebhookUrl: slackWebhookUrls[team.teamKey]
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
      AlertChannel: team.teamKey
      Team: team.teamKey
    })
  }
}]

var slackTeamKeys = [for team in teams: team.teamKey]

module alertActionGroups './modules/alerting-action-group.bicep' = [for team in teams: {
  params: {
    actionGroupName: team.actionGroupName
    groupShortName: team.groupShortName
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

// Action group IDs are safe to output - consumers reference these to attach alerts
output channels array = [for (team, i) in teams: {
  teamKey: team.teamKey
  actionGroupId: alertActionGroups[i].outputs.actionGroupId
  actionGroupName: alertActionGroups[i].outputs.actionGroupName
}]
