using '../main.bicep'

param appInsightsName = 'TSTRWDINFAI1401'
param environmentNumber = '1'
param environmentType = 'TST'
param keyVaultName = 'TSTRWDINFKV1401'
param logAnalyticsWorkspaceName = 'TSTRWDINFLA1401'
param channelInterfaces = [
	{
		team: 'ManageAccount'
		secretName: 'slack-webhook-epr-alerts-manage-account-non-prod'
	}
	{
		team: 'ManageLiabilities'
		secretName: 'slack-webhook-epr-alerts-manage-liabilities-non-prod'
	}
	{
		team: 'MeetObligations'
		secretName: 'slack-webhook-epr-alerts-meet-obligations-non-prod'
	}
	{
		team: 'Platform'
		secretName: 'slack-webhook-epr-alerts-platform-non-prod'
	}
	{
		team: 'RegulatorTooling'
		secretName: 'slack-webhook-epr-alerts-regulator-tooling-non-prod'
	}
	{
		team: 'SubmitData'
		secretName: 'slack-webhook-epr-alerts-submit-data-non-prod'
	}
	{
		team: 'Team1'
		secretName: 'slack-webhook-epr-alerts-team1-non-prod'
	}
]
