using '../main.bicep'

param channelInterfaces = [
  'epr-alerts-manage-account-prod'
  'epr-alerts-manage-liabilities-prod'
  'epr-alerts-meet-obligations-prod'
  'epr-alerts-platform-prod'
  'epr-alerts-regulator-tooling-prod'
  'epr-alerts-submit-data-prod'
]
param channelInterfaceDefault = 'epr-alerts-platform-prod'
param environmentNumber = '1'
param environmentType = 'PRD'
param keyVaultName = 'PRDRWDINFKV1401'
