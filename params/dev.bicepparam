using '../main.bicep'

param environmentType = 'DEV'
param environmentNumber = '1'

param teams = [
  {
    actionGroupName: 'ActionGroup-PlatformTeam'
    emailReceivers: [
      'paul.barnard@esynergy.co.uk'
    ]
    groupShortName: 'AGPlatform'
    slackWebhookUrl: '***REMOVED***'
    teamKey: 'platformTeam'
    webhookReceivers: []
  }
  {
    actionGroupName: 'ActionGroup-RegulatorTeam'
    emailReceivers: [
      'paul.barnard@esynergy.co.uk'
    ]
    groupShortName: 'AGRegulator'
    slackWebhookUrl: '***REMOVED***'
    teamKey: 'regulatorTeam'
    webhookReceivers: []
  }
]
