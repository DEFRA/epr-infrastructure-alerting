param workflowName string
param location string
@secure()
param slackWebhookUrl string
param customTags object = {}

resource workflow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: workflowName
  location: location
  tags: customTags
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        slackWebhookUrl: {
          type: 'SecureString'
        }
      }
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              type: 'object'
            }
          }
        }
      }
      actions: {
        Post_To_Slack: {
          type: 'Http'
          inputs: {
            method: 'POST'
            uri: '@parameters(\'slackWebhookUrl\')'
            headers: {
              'Content-Type': 'application/json'
            }
            body: '@triggerBody()'
          }
          runAfter: {}
        }
      }
      outputs: {}
    }
    parameters: {
      slackWebhookUrl: {
        value: slackWebhookUrl
      }
    }
  }
}

output workflowResourceId string = workflow.id
#disable-next-line outputs-should-not-contain-secrets
output manualTriggerCallbackUrl string = listCallbackUrl(resourceId('Microsoft.Logic/workflows/triggers', workflowName, 'manual'), '2019-05-01').value
