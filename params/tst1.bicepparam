using '../main.bicep'

param appInsightsName = 'TSTRWDINFAI1401'
param environmentNumber = '1'
param environmentType = 'TST'
param keyVaultName = 'TSTRWDINFKV1401'
param logAnalyticsWorkspaceName = 'TSTRWDINFLA1401'
param slackPlatformSecretName = 'slack-webhook-url-alerting-platform'

// Commented out for now as we are not using teams in the alerting module yet.  We will add this back in when we have a requirement to use it.
// param teams = [
//   {
//     actionGroupName: 'ActionGroup-PlatformTeam'
//     emailReceivers: [
//       'paul.barnard@esynergy.co.uk'
//     ]
//     groupShortName: 'AGPlatform'
//     slackWebhookUrl: '***REMOVED***'
//     teamKey: 'platformTeam'
//     webhookReceivers: []
//   }
//   {
//     actionGroupName: 'ActionGroup-RegulatorTeam'
//     emailReceivers: [
//       'paul.barnard@esynergy.co.uk'
//     ]
//     groupShortName: 'AGRegulator'
//     slackWebhookUrl: '***REMOVED***'
//     teamKey: 'regulatorTeam'
//     webhookReceivers: []
//   }
// ]
