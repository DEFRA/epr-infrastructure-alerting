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
type alertChannelType = {
  @description('Name of the Action Group resource')
  actionGroupName: string
  @description('Optional list of email addresses to include in the Action Group')
  emailReceivers: string[]
  @description('Short name for the Action Group (max 12 chars)')
  groupShortName: string
  @description('Slack webhook URL for the channel')
  slackWebhookUrl: string
  @description('Unique key for the channel')
  channelKey: string
  @description('Optional list of webhook endpoints to include in the Action Group')
  webhookReceivers: string[]
}
