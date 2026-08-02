param actionGroupName string
param groupShortName string
param workflowResourceId string = ''

@secure()
param workflowCallbackUrl string = ''

param webhookReceivers array = []
param customTags object = {}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  tags: customTags
  properties: {
    enabled: true
    groupShortName: groupShortName
    logicAppReceivers: empty(workflowResourceId) ? [] : [
      {
        name: '${actionGroupName}Slack'
        resourceId: workflowResourceId
        callbackUrl: workflowCallbackUrl
        useCommonAlertSchema: true
      }
    ]
    webhookReceivers: [for (webhook, i) in webhookReceivers: {
      name: '${actionGroupName}Webhook${i}'
      serviceUri: trim(webhook)
      useCommonAlertSchema: true
    }]
  }
}

output actionGroupId string = actionGroup.id
output actionGroupName string = actionGroup.name
