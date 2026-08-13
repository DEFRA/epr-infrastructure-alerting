using '../main.bicep'

param appInsightsName = 'TSTRWDINFAI1401'
param environmentNumber = '1'
param environmentType = 'TST'
param keyVaultName = 'TSTRWDINFKV1401'
param logAnalyticsWorkspaceName = 'TSTRWDINFLA1401'
param channelInterfaces = {
	platform: 'slack-webhook-epr-alerts-platform-non-prod'
	team1: 'slack-webhook-epr-alerts-team1-non-prod'
}
