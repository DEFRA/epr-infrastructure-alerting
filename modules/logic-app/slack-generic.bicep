param workflowName string
param location string
@secure()
param slackWebhookUrl string
param customTags object = {}

resource genericWorkflow 'Microsoft.Logic/workflows@2019-05-01' = {
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
        Get_Alert_Id: {
          type: 'Compose'
          inputs: '@{coalesce(string(triggerBody()?[\'data\']?[\'essentials\']?[\'alertId\']), \'NOTSET\')}'
          runAfter: {}
        }
        Get_Alert_Rule: {
          type: 'Compose'
          inputs: '@{coalesce(string(triggerBody()?[\'data\']?[\'essentials\']?[\'alertRule\']), \'NOTSET\')}'
          runAfter: {}
        }
        Get_Description: {
          type: 'Compose'
          inputs: '@{coalesce(string(triggerBody()?[\'data\']?[\'essentials\']?[\'description\']), \'NOTSET\')}'
          runAfter: {}
        }
        Get_Monitor_Condition: {
          type: 'Compose'
          inputs: '@{coalesce(string(triggerBody()?[\'data\']?[\'essentials\']?[\'monitorCondition\']), \'NOTSET\')}'
          runAfter: {}
        }
        Get_Severity: {
          type: 'Compose'
          inputs: '@{toLower(trim(coalesce(string(triggerBody()?[\'data\']?[\'essentials\']?[\'severity\']), \'\')))}'
          runAfter: {}
        }
        Get_Severity_Display: {
          type: 'Compose'
          inputs: '@{if(or(equals(outputs(\'Get_Severity\'), \'sev0\'), equals(outputs(\'Get_Severity\'), \'0\')), \'💀 Critical\', if(or(equals(outputs(\'Get_Severity\'), \'sev1\'), equals(outputs(\'Get_Severity\'), \'1\')), \'🚨 Error\', if(or(equals(outputs(\'Get_Severity\'), \'sev2\'), equals(outputs(\'Get_Severity\'), \'2\')), \'⚠️ Warning\', if(or(equals(outputs(\'Get_Severity\'), \'sev3\'), equals(outputs(\'Get_Severity\'), \'3\')), \'ℹ️ Informational\', if(or(equals(outputs(\'Get_Severity\'), \'sev4\'), equals(outputs(\'Get_Severity\'), \'4\')), \'🔹 Verbose\', \'Unknown\')))))}'
          runAfter: {
            Get_Severity: ['Succeeded']
          }
        }
        Get_Resource_Name: {
          type: 'Compose'
          inputs: '@{coalesce(string(triggerBody()?[\'data\']?[\'essentials\']?[\'alertTargetIDs\']?[0]), \'NOTSET\')}'
          runAfter: {}
        }
        Get_Investigation_Link: {
          type: 'Compose'
          inputs: '@{trim(string(coalesce(triggerBody()?[\'data\']?[\'essentials\']?[\'investigationLink\'], \'\')))}'
          runAfter: {}
        }
        Get_Investigation_Link_Button_Url: {
          type: 'Compose'
          inputs: '@{if(empty(outputs(\'Get_Investigation_Link\')), \'https://portal.azure.com\', if(startsWith(toLower(outputs(\'Get_Investigation_Link\')), \'https://\'), outputs(\'Get_Investigation_Link\'), if(startsWith(toLower(outputs(\'Get_Investigation_Link\')), \'http://\'), outputs(\'Get_Investigation_Link\'), if(startsWith(outputs(\'Get_Investigation_Link\'), \'#\'), concat(\'https://portal.azure.com/\', outputs(\'Get_Investigation_Link\')), \'https://portal.azure.com\'))))}'
          runAfter: {
            Get_Investigation_Link: ['Succeeded']
          }
        }
        Get_Alert_Portal_Link: {
          type: 'Compose'
          inputs: '@{if(equals(outputs(\'Get_Alert_Id\'), \'NOTSET\'), \'https://portal.azure.com\', concat(\'https://portal.azure.com/#view/Microsoft_Azure_Monitoring_Alerts/AlertDetails.ReactView/alertId/\', uriComponent(outputs(\'Get_Alert_Id\'))))}'
          runAfter: {
            Get_Alert_Id: ['Succeeded']
          }
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
                    text: '🔔 @{outputs(\'Get_Alert_Rule\')}'
                  }
                  level: 1
                }
                {
                  type: 'rich_text'
                  elements: [
                    {
                      type: 'rich_text_quote'
                      elements: [
                        {
                          type: 'text'
                          text: '@{outputs(\'Get_Description\')}'
                        }
                      ]
                    }
                  ]
                }
                {
                  type: 'section'
                  fields: [
                    {
                      type: 'mrkdwn'
                      text: '*State:*\n@{outputs(\'Get_Monitor_Condition\')}'
                    }
                    {
                      type: 'mrkdwn'
                      text: '*Severity:*\n@{outputs(\'Get_Severity_Display\')}'
                    }
                  ]
                }
                {
                  type: 'section'
                  text: {
                    type: 'mrkdwn'
                    text: '*Runbook:*\nhttps://eaflood.atlassian.net/wiki/spaces/MWR/overview'
                  }
                }
                {
                  type: 'section'
                  text: {
                    type: 'mrkdwn'
                    text: '*Resource:*\n`@{outputs(\'Get_Resource_Name\')}`'
                  }
                }
                {
                  type: 'divider'
                }                
                {
                  type: 'actions'
                  elements: [
                    {
                      type: 'button'
                      text: {
                        type: 'plain_text'
                        text: '🔍 View Alert'
                        emoji: false
                      }
                      style: 'primary'
                      url: '@{outputs(\'Get_Alert_Portal_Link\')}'
                    }
                    {
                      type: 'button'
                      text: {
                        type: 'plain_text'
                        text: '🤖 Investigate Alert'
                        emoji: false
                      }
                      url: '@{outputs(\'Get_Investigation_Link_Button_Url\')}'
                    }
                  ]
                }
              ]
            }
          }
          runAfter: {
            Get_Alert_Portal_Link: ['Succeeded']
            Get_Alert_Rule: ['Succeeded']
            Get_Description: ['Succeeded']
            Get_Monitor_Condition: ['Succeeded']
            Get_Resource_Name: ['Succeeded']
            Get_Severity_Display: ['Succeeded']
            Get_Investigation_Link_Button_Url: ['Succeeded']
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

output workflowResourceId string = genericWorkflow.id
#disable-next-line outputs-should-not-contain-secrets
output manualTriggerCallbackUrl string = listCallbackUrl(resourceId('Microsoft.Logic/workflows/triggers', workflowName, 'manual'),  '2019-05-01').value
