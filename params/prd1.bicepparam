using '../main.bicep'

param appInsightsName = 'PRDRWDINFAI1401'
param environmentNumber = '1'
param environmentType = 'PRD'
param keyVaultName = 'PRDRWDINFKV1401'
param logAnalyticsWorkspaceName = 'PRDRWDINFLA1401'
param channelInterfaces = [
	'epr-alerts-manage-account-prod'
	'epr-alerts-manage-liabilities-prod'
	'epr-alerts-meet-obligations-prod'
	'epr-alerts-platform-prod'
	'epr-alerts-regulator-tooling-prod'
	'epr-alerts-submit-data-prod'
]
