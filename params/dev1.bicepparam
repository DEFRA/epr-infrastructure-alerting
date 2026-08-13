using '../main.bicep'

param appInsightsName = 'DEVRWDINFAI1401'
param environmentNumber = '1'
param environmentType = 'DEV'
param keyVaultName = 'DEVRWDINFKV1401'
param logAnalyticsWorkspaceName = 'DEVRWDINFLA1401'
param channelInterfaces = {
	platform: 'slack-webhook-epr-alerts-platform-non-prod'
	team1: 'slack-webhook-epr-alerts-team1-non-prod'
}
