param actionGroupName string
param groupShortName string
param tags object = {}
@secure()
param workflowCallbackUrl string
param workflowResourceId string


resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  tags: tags
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
  }
}

output actionGroupId string = actionGroup.id
output actionGroupName string = actionGroup.name
