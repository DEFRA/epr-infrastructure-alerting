param alertName string
param actionGroupIds string[]
param targetResourceName string
param targetResourceGroup string = ''
param targetResourceRegion string = resourceGroup().location
param targetResourceType string = 'Microsoft.Web/sites'
param metricNamespace string = 'microsoft.web/sites'
param metricName string = 'HealthCheckStatus'
param threshold int = 100
param severity int = 2
param customTags object = {}
param location string = 'global'

var resolvedTargetResourceGroup = empty(targetResourceGroup) ? resourceGroup().name : targetResourceGroup
var targetResourceId = resourceId(resolvedTargetResourceGroup, targetResourceType, targetResourceName)

resource healthCheckAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: alertName
  location: location
  tags: customTags
  properties: {
    actions: [for id in actionGroupIds: {
      actionGroupId: id
      webHookProperties: {}
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
          metricNamespace: metricNamespace
          skipMetricValidation: false
          timeAggregation: 'Average'
        }
      ]
    }
    description: 'Health check alert routed via shared alerting Action Groups.'
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
