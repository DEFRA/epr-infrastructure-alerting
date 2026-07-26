using '../main.bicep'

param environmentType = 'DEV'
param environmentNumber = '1'

param teams = [
  {
    teamKey: 'platformTeam'
    actionGroupName: 'ActionGroup-PlatformTeam'
    groupShortName: 'AGPlatform'
    slackWorkflowName: 'SlackChannel-PlatformTeam'
    emailReceivers: [
      'paul.barnard@esynergy.co.uk'
    ]
    webhookReceivers: []
  }
  {
    teamKey: 'regulatorTeam'
    actionGroupName: 'ActionGroup-RegulatorTeam'
    groupShortName: 'AGRegulator'
    slackWorkflowName: 'SlackChannel-RegulatorTeam'
    emailReceivers: []
    webhookReceivers: []
  }
]

param slackWebhookUrls = {
  platformTeam: '***REMOVED***'
  regulatorTeam: '***REMOVED***'
}
