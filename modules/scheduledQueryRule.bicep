param alertName string
param displayName string
param description string
param severity int
param evaluationFrequency string
param windowSize string
param query string
@allowed([
  'loganalytics'
  'appinsights'
])
param scopeResourceType string
param scopeResourceId string
param actionGroupId string
param customProperties object = {}
param tags object = {}

var logAnalyticsScopeResourceType = 'Microsoft.OperationalInsights/workspaces'
var appInsightsScopeResourceType = 'Microsoft.Insights/components'

resource logQueryAlert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: alertName
  location: resourceGroup().location
  kind: 'LogAlert'
  tags: tags
  properties: {
    displayName: displayName
    description: description
    enabled: true
    severity: severity
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    scopes: [
      scopeResourceId
    ]
    targetResourceTypes: toLower(scopeResourceType) == 'loganalytics'
      ? [logAnalyticsScopeResourceType]
      : [appInsightsScopeResourceType]
    criteria: {
      allOf: [
        {
          query: query
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            minFailingPeriodsToAlert: 1
            numberOfEvaluationPeriods: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroupId
      ]
      customProperties: customProperties
    }
    autoMitigate: false
    skipQueryValidation: true
  }
}

output alertId string = logQueryAlert.id
output alertName string = logQueryAlert.name
