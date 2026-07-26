import { actionGroupChannelType, commonTags, slackChannelType } from './common.bicep'

param actionGroupChannels actionGroupChannelType[] = []
param environmentNumber string
param environmentType string
param location string = resourceGroup().location
param slackChannels slackChannelType[] = []
@secure()
param slackWebhookUrls object = {}

module slackLogicApps './modules/slack-alerting-logic-app.bicep' = [for channel in slackChannels: {
  params: {
    workflowName: channel.workflowName
    location: location
    slackWebhookUrl: slackWebhookUrls[channel.channelKey]
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
      AlertChannel: channel.channelKey
    })
  }
}]

var slackChannelKeys = [for channel in slackChannels: channel.channelKey]

module alertActionGroups './modules/alerting-action-group.bicep' = [for channel in actionGroupChannels: {
  params: {
    actionGroupName: channel.actionGroupName
    groupShortName: channel.groupShortName
    workflowResourceId: slackLogicApps[indexOf(slackChannelKeys, channel.channelKey)].outputs.workflowResourceId
    workflowCallbackUrl: slackLogicApps[indexOf(slackChannelKeys, channel.channelKey)].outputs.manualTriggerCallbackUrl
    emailReceivers: channel.emailReceivers
    customTags: union(commonTags, {
      Environment: '${environmentType}${environmentNumber}'
      AlertChannel: channel.channelKey
    })
  }
}]

// Action group IDs are safe to output - consumers reference these to attach alerts
output channels array = [for (channel, i) in actionGroupChannels: {
  channelKey: channel.channelKey
  actionGroupId: alertActionGroups[i].outputs.actionGroupId
  actionGroupName: alertActionGroups[i].outputs.actionGroupName
}]
