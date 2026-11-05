param location string
@secure()
param routerCallbackUrl string
param tags object = {}
param workflowName string

resource genericWorkflow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: workflowName
  location: location
  tags: tags
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        routerCallbackUrl: {
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
          inputs: '@{if(or(equals(outputs(\'Get_Severity\'), \'sev0\'), equals(outputs(\'Get_Severity\'), \'0\')), \'💀 Critical\', if(or(equals(outputs(\'Get_Severity\'), \'sev1\'), equals(outputs(\'Get_Severity\'), \'1\')), \'🚨 Error\', if(or(equals(outputs(\'Get_Severity\'), \'sev2\'), equals(outputs(\'Get_Severity\'), \'2\')), \'⚠️ Warning\', if(or(equals(outputs(\'Get_Severity\'), \'sev3\'), equals(outputs(\'Get_Severity\'), \'3\')), \'ℹ️ Informational\', if(or(equals(outputs(\'Get_Severity\'), \'sev4\'), equals(outputs(\'Get_Severity\'), \'4\')), \'📝 Verbose\', \'Unknown\')))))}'
          runAfter: {
            Get_Severity: ['Succeeded']
          }
        }
        Get_Resource_Name: {
          type: 'Compose'
          inputs: '@{coalesce(string(triggerBody()?[\'data\']?[\'essentials\']?[\'alertTargetIDs\']?[0]), \'NOTSET\')}'
          runAfter: {}
        }
        // Event Grid (Key Vault) alerts carry the source CloudEvent in data.alertContext.event
        Get_Event_Object_Name: {
          type: 'Compose'
          inputs: '@{trim(string(coalesce(triggerBody()?[\'data\']?[\'alertContext\']?[\'event\']?[\'data\']?[\'ObjectName\'], triggerBody()?[\'data\']?[\'alertContext\']?[\'event\']?[\'subject\'], \'\')))}'
          runAfter: {}
        }
        Get_Event_Object_Type: {
          type: 'Compose'
          inputs: '@{trim(string(coalesce(triggerBody()?[\'data\']?[\'alertContext\']?[\'event\']?[\'data\']?[\'ObjectType\'], \'Object\')))}'
          runAfter: {}
        }
        Get_Event_Vault_Name: {
          type: 'Compose'
          inputs: '@{trim(string(coalesce(triggerBody()?[\'data\']?[\'alertContext\']?[\'event\']?[\'data\']?[\'VaultName\'], \'NOTSET\')))}'
          runAfter: {}
        }
        // EXP is Unix epoch seconds; coalesce to 0 because if() evaluates both branches
        Get_Event_Expiry_Display: {
          type: 'Compose'
          inputs: '@{if(equals(int(string(coalesce(triggerBody()?[\'data\']?[\'alertContext\']?[\'event\']?[\'data\']?[\'EXP\'], 0))), 0), \'Not set\', concat(addSeconds(\'1970-01-01T00:00:00Z\', int(string(coalesce(triggerBody()?[\'data\']?[\'alertContext\']?[\'event\']?[\'data\']?[\'EXP\'], 0))), \'yyyy-MM-dd HH:mm\'), \' UTC\'))}'
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
        Get_Runbook_Url: {
          type: 'Compose'
          inputs: '@{trim(string(coalesce(triggerBody()?[\'data\']?[\'customProperties\']?[\'runbookUrl\'], \'\')))}'
          runAfter: {}
        }
        Get_Channel: {
          type: 'Compose'
          inputs: '@{trim(string(coalesce(triggerBody()?[\'data\']?[\'customProperties\']?[\'channel\'], \'\')))}'
          runAfter: {}
        }
        Get_Routing_Channel: {
          type: 'Compose'
          inputs: '@{if(empty(outputs(\'Get_Channel\')), \'epr-alerts-platform-non-prod\', toLower(outputs(\'Get_Channel\')))}'
          runAfter: {
            Get_Channel: [ 'Succeeded' ]
          }
        }
        Get_Runbook_Button_Url: {
          type: 'Compose'
          inputs: '@{if(or(startsWith(toLower(outputs(\'Get_Runbook_Url\')), \'https://\'), startsWith(toLower(outputs(\'Get_Runbook_Url\')), \'http://\')), outputs(\'Get_Runbook_Url\'), \'\')}'
          runAfter: {
            Get_Runbook_Url: [ 'Succeeded' ]
          }
        }
        Initialize_Slack_Blocks: {
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'SlackBlocks'
                type: 'Array'
                value: [
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
                ]
              }
            ]
          }
          runAfter: {
            Get_Alert_Portal_Link: [ 'Succeeded' ]
            Get_Alert_Rule: [ 'Succeeded' ]
            Get_Description: [ 'Succeeded' ]
            Get_Monitor_Condition: [ 'Succeeded' ]
            Get_Resource_Name: [ 'Succeeded' ]
            Get_Severity_Display: [ 'Succeeded' ]
            Get_Investigation_Link_Button_Url: [ 'Succeeded' ]
            Get_Runbook_Button_Url: [ 'Succeeded' ]
          }
        }
        Add_Runbook_Section_If_Present: {
          type: 'If'
          expression: '@not(empty(outputs(\'Get_Runbook_Button_Url\')))'
          actions: {
            Append_Runbook_Section: {
              type: 'AppendToArrayVariable'
              inputs: {
                name: 'SlackBlocks'
                value: {
                  type: 'section'
                  text: {
                    type: 'mrkdwn'
                    text: '*Runbook:*\n @{outputs(\'Get_Runbook_Button_Url\')}'
                  }
                }
              }
              runAfter: {}
            }
          }
          else: {
            actions: {}
          }
          runAfter: {
            Initialize_Slack_Blocks: [ 'Succeeded' ]
          }
        }
        Add_Event_Object_Section_If_Present: {
          type: 'If'
          expression: '@not(empty(outputs(\'Get_Event_Object_Name\')))'
          actions: {
            Append_Event_Object_Section: {
              type: 'AppendToArrayVariable'
              inputs: {
                name: 'SlackBlocks'
                value: {
                  type: 'section'
                  fields: [
                    {
                      type: 'mrkdwn'
                      text: '*@{outputs(\'Get_Event_Object_Type\')}:*\n`@{outputs(\'Get_Event_Object_Name\')}`'
                    }
                    {
                      type: 'mrkdwn'
                      text: '*Key Vault:*\n`@{outputs(\'Get_Event_Vault_Name\')}`'
                    }
                    {
                      type: 'mrkdwn'
                      text: '*Expires:*\n@{outputs(\'Get_Event_Expiry_Display\')}'
                    }
                  ]
                }
              }
              runAfter: {}
            }
          }
          else: {
            actions: {}
          }
          runAfter: {
            Add_Runbook_Section_If_Present: [ 'Succeeded' ]
            Get_Event_Object_Name: [ 'Succeeded' ]
            Get_Event_Object_Type: [ 'Succeeded' ]
            Get_Event_Vault_Name: [ 'Succeeded' ]
            Get_Event_Expiry_Display: [ 'Succeeded' ]
          }
        }
        Append_Resource_Section: {
          type: 'AppendToArrayVariable'
          inputs: {
            name: 'SlackBlocks'
            value: {
              type: 'section'
              text: {
                type: 'mrkdwn'
                text: '*Resource:*\n`@{outputs(\'Get_Resource_Name\')}`'
              }
            }
          }
          runAfter: {
            Add_Event_Object_Section_If_Present: [ 'Succeeded' ]
          }
        }
        // AppendToArrayVariable only accepts one item; divider must be a separate append
        Append_Divider: {
          type: 'AppendToArrayVariable'
          inputs: {
            name: 'SlackBlocks'
            value: {
              type: 'divider'
            }
          }
          runAfter: {
            Append_Resource_Section: [ 'Succeeded' ]
          }
        }
        Append_Action_Buttons: {
          type: 'AppendToArrayVariable'
          inputs: {
            name: 'SlackBlocks'
            value: {
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
          }
          runAfter: {
            Append_Divider: [ 'Succeeded' ]
          }
        }
        Build_Router_Payload: {
          type: 'Compose'
          inputs: {
            channelName: '@{outputs(\'Get_Routing_Channel\')}'
            payload: {
              blocks: '@{variables(\'SlackBlocks\')}'
            }
          }
          runAfter: {
            Append_Action_Buttons: [ 'Succeeded' ]
            Get_Routing_Channel: [ 'Succeeded' ]
          }
        }
        Forward_To_Router: {
          type: 'Http'
          inputs: {
            method: 'POST'
            uri: '@parameters(\'routerCallbackUrl\')'
            headers: {
              'Content-Type': 'application/json'
            }
            body: '@outputs(\'Build_Router_Payload\')'
          }
          runAfter: {
            Build_Router_Payload: [ 'Succeeded' ]
          }
        }
        Return_Accepted: {
          type: 'Response'
          kind: 'Http'
          inputs: {
            statusCode: 202
            headers: {
              'Content-Type': 'application/json'
            }
            body: {
              status: 'Forwarded'
              channelName: '@{outputs(\'Get_Routing_Channel\')}'
            }
          }
          runAfter: {
            Forward_To_Router: [ 'Succeeded' ]
          }
        }
      }
      outputs: {}
    }
    parameters: {
      routerCallbackUrl: {
        value: routerCallbackUrl
      }
    }
  }
}

output workflowResourceId string = genericWorkflow.id
#disable-next-line outputs-should-not-contain-secrets
output manualTriggerCallbackUrl string = listCallbackUrl(resourceId('Microsoft.Logic/workflows/triggers', workflowName, 'manual'),  '2019-05-01').value
