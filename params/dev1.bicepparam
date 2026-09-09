using '../main.bicep'

param appInsightsName = 'DEVRWDINFAI1401'
param environmentNumber = '1'
param environmentType = 'DEV'
param keyVaultName = 'DEVRWDINFKV1401'
param logAnalyticsWorkspaceName = 'DEVRWDINFLA1401'
param channelInterfaces = [
  'epr-alerts-manage-account-non-prod'
  'epr-alerts-manage-liabilities-non-prod'
  'epr-alerts-meet-obligations-non-prod'
  'epr-alerts-platform-non-prod'
  'epr-alerts-regulator-tooling-non-prod'
  'epr-alerts-submit-data-non-prod'
  'epr-alerts-team1-non-prod'
]
