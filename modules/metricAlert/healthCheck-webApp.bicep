param actionGroupIds string[]
param alertName string
param channel string
param description string
param environmentType string
param metricName string = 'HealthCheckStatus'
param targetResourceName string
param targetResourceGroup string = ''
param targetResourceRegion string = resourceGroup().location
param targetResourceType string = 'Microsoft.Web/sites'
param tags object = {}

var resolvedTargetResourceGroup = empty(targetResourceGroup) ? resourceGroup().name : targetResourceGroup
var targetResourceId = resourceId(resolvedTargetResourceGroup, targetResourceType, targetResourceName)

var healthAlertConfig = {
  dev: { severity: 3, evaluationFrequency: 'PT5M', windowSize: 'PT15M', threshold: 50 }
  tst: { severity: 2, evaluationFrequency: 'PT5M', windowSize: 'PT15M', threshold: 75 }
  pre: { severity: 1, evaluationFrequency: 'PT1M', windowSize: 'PT5M',  threshold: 90 }
  prd: { severity: 1, evaluationFrequency: 'PT1M', windowSize: 'PT5M',  threshold: 90 }
}
var cfg = healthAlertConfig[environmentType]

resource healthCheckAlert 'Microsoft.Insights/metricAlerts@2024-03-01-preview' = {
  name: alertName
  location: 'global'
  tags: tags
  properties: {
    actions: [for id in actionGroupIds: {
      actionGroupId: id
      webHookProperties: {
        runbookUrl: 'This is a test of custom webhook properties for resource: ${targetResourceName}'
        channel: channel
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
          threshold: cfg.threshold
          metricName: metricName
          metricNamespace: 'microsoft.web/sites'
          skipMetricValidation: false
          timeAggregation: 'Average'
        }
      ]
    }
    description: description
    enabled: true
    evaluationFrequency: cfg.evaluationFrequency
    scopes: [
      targetResourceId
    ]
    severity: cfg.severity
    targetResourceRegion: targetResourceRegion
    targetResourceType: targetResourceType
    windowSize: cfg.windowSize
  }
}

output metricAlertId string = healthCheckAlert.id
output metricAlertName string = healthCheckAlert.name
