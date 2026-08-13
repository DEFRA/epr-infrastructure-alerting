param alertName string
param actionGroupIds string[]
param description string
param targetResourceName string
param targetResourceGroup string = ''
param targetResourceRegion string = resourceGroup().location
param targetResourceType string = 'Microsoft.Web/sites'
param team string
param metricName string = 'HealthCheckStatus'
param threshold int = 100
param severity int = 2
param customTags object = {}

var resolvedTargetResourceGroup = empty(targetResourceGroup) ? resourceGroup().name : targetResourceGroup
var targetResourceId = resourceId(resolvedTargetResourceGroup, targetResourceType, targetResourceName)

resource healthCheckAlert 'Microsoft.Insights/metricAlerts@2024-03-01-preview' = {
  name: alertName
  location: 'global'
  tags: customTags
  properties: {
    actions: [for id in actionGroupIds: {
      actionGroupId: id
      webHookProperties: {
        runbookUrl: 'This is a test of custom webhook properties for resource: ${targetResourceName}'
        team: team
      }
    }]
    autoMitigate: true
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          name: 'HealthCheckStatusThreshold'
          operator: 'LessThan'
          threshold: threshold
          metricName: metricName
          metricNamespace: 'microsoft.web/sites'
          skipMetricValidation: false
          timeAggregation: 'Average'
        }
      ]
    }
    description: description
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      targetResourceId
    ]
    severity: severity
    targetResourceRegion: targetResourceRegion
    targetResourceType: targetResourceType
    windowSize: 'PT5M'
  }
}

output metricAlertId string = healthCheckAlert.id
output metricAlertName string = healthCheckAlert.name
