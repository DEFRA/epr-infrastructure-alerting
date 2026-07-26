@export()
var commonTags = {
  ManagedBy: 'Bicep'
  Owner: 'Platform Team'
  Purpose: 'SHARED-ALERTING'
  Repo: 'ccoe-epr-infrastructure'
  ServiceCode: 'RWD'
  Tier: 'SHARED'
}

@export()
type slackChannelType = {
  @description('Unique key used to look up the webhook URL at deploy time')
  channelKey: string
  @description('Name of the Logic App workflow resource')
  workflowName: string
}

@export()
type actionGroupChannelType = {
  @description('Unique key used to bind this Action Group to a Slack workflow channel')
  channelKey: string
  @description('Name of the Action Group resource')
  actionGroupName: string
  @description('Short name for the Action Group (max 12 chars)')
  groupShortName: string
  @description('Optional list of email addresses to include in the Action Group')
  emailReceivers: string[]
}
