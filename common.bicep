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
type alertTeamType = {
  @description('Unique key for the team')
  teamKey: string
  @description('Name of the Action Group resource')
  actionGroupName: string
  @description('Short name for the Action Group (max 12 chars)')
  groupShortName: string
  @description('Name of the Logic App workflow resource for Slack notifications; leave empty for email-only teams')
  slackWorkflowName: string
  @description('Optional list of email addresses to include in the Action Group')
  emailReceivers: string[]
  @description('Optional list of webhook endpoints to include in the Action Group')
  webhookReceivers: string[]
}
