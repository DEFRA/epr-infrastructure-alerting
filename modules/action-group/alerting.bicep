param actionGroupName string
param groupShortName string
param workflowResourceId string = ''

@secure()
param workflowCallbackUrl string = ''

param emailReceivers array = []
param webhookReceivers array = []
param customTags object = {}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  tags: customTags
  properties: {
    enabled: true
    groupShortName: groupShortName
    emailReceivers: [for (email, i) in emailReceivers: {
      name: '${actionGroupName}Email${i}'
      emailAddress: trim(email)
      useCommonAlertSchema: true
    }]
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
