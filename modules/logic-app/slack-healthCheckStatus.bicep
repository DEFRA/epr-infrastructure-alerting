param workflowName string
param location string
@secure()
param slackWebhookUrl string
param customTags object = {}

resource healthCheckWorkflow 'Microsoft.Logic/workflows@2019-05-01' = {
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
        Get_Resource_Name: {
          type: 'Compose'
          inputs: '@{coalesce(string(triggerBody()?[\'data\']?[\'essentials\']?[\'configurationItems\']?[0]), \'NOTSET\')}'
          runAfter: {}
        }
        Get_Investigation_Link: {
          type: 'Compose'
          inputs: '@{coalesce(triggerBody()?[\'data\']?[\'essentials\']?[\'investigationLink\'], \'\')}'
          runAfter: {}
        }
        Post_To_Slack: {
          type: 'Http'
          inputs: {
            method: 'POST'
            uri: '@parameters(\'slackWebhookUrl\')'
            headers: {
              'Content-Type': 'application/json'
            }
            body: {
              blocks: [
                {
                  type: 'divider'
                }
                {
                  type: 'header'
                  text: {
                    type: 'plain_text'
                    text: '🚑 Health Check Alert'
                  }
                  level: 1
                }
                {
                  type: 'section'
                  fields: [
                    {
                      type: 'mrkdwn'
                      text: '*Resource:* `@{outputs(\'Get_Resource_Name\')}`'
                    }
                  ]
                }
                {
                  type: 'divider'
                }
                {
                  type: 'rich_text'
                  elements: [
                    {
                      type: 'rich_text_quote'
                      elements: [
                        {
                          type: 'text'
                          text: 'A health check alert has been triggered for the above resource. Please investigate the issue and take appropriate action.'
                        }
                      ]
                    }
                  ]
                }
                {
                  type: 'actions'
                  elements: [
                    {
                      type: 'button'
                      text: {
                        type: 'plain_text'
                        text: '🔍 Open in Azure Monitor'
                        emoji: false
                      }
                      style: 'primary'
                      url: '@{outputs(\'Get_Investigation_Link\')}'
                    }
                  ]
                }
              ]
            }
          }
          runAfter: {
            Get_Resource_Name: ['Succeeded']
            Get_Investigation_Link: ['Succeeded']
          }
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

output workflowResourceId string = healthCheckWorkflow.id
#disable-next-line outputs-should-not-contain-secrets
output manualTriggerCallbackUrl string = listCallbackUrl(
  resourceId('Microsoft.Logic/workflows/triggers', workflowName, 'manual'),
  '2019-05-01'
).value
