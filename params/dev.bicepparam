using '../main.bicep'

param environmentType = 'DEV'
param environmentNumber = '1'

param slackChannels = [
  {
    channelKey: 'platformTeam'
    workflowName: 'SlackChannel-PlatformTeam'
  }
  {
    channelKey: 'regulatorTeam'
    workflowName: 'SlackChannel-RegulatorTeam'
  }
]

param actionGroupChannels = [
  {
    channelKey: 'platformTeam'
    actionGroupName: 'ActionGroup-PlatformTeam'
    groupShortName: 'AGPlatform'
    emailReceivers: [
      'paul.barnard@esynergy.co.uk'
    ]
  }
  {
    channelKey: 'regulatorTeam'
    actionGroupName: 'ActionGroup-RegulatorTeam'
    groupShortName: 'AGRegulator'
    emailReceivers: []
  }
]

param slackWebhookUrls = {
  platformTeam: '***REMOVED***'
  regulatorTeam: '***REMOVED***'
}
