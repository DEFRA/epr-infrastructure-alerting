using '../main.bicep'

param channelInterfaces = [
  'epr-alerts-manage-account-non-prod'
  'epr-alerts-manage-liabilities-non-prod'
  'epr-alerts-meet-obligations-non-prod'
  'epr-alerts-platform-non-prod'
  'epr-alerts-regulator-tooling-non-prod'
  'epr-alerts-submit-data-non-prod'
  'epr-alerts-team1-non-prod'
]
param channelInterfaceDefault = 'epr-alerts-platform-non-prod'
param environmentNumber = '1'
param environmentType = 'PRE'
param keyVaultName = 'PRERWDINFKV1401'
