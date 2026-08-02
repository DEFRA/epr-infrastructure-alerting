param workflowName string
param location string
@secure()
param slackWebhookUrl string
param customTags object = {}

resource slackAlertWorkflow 'Microsoft.Logic/workflows@2019-05-01' = {
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
        Get_Rule: {
          type: 'Compose'
          inputs: '@{coalesce(triggerBody()?[\'data\']?[\'essentials\']?[\'alertRule\'], triggerBody()?[\'data\']?[\'operationName\'], triggerBody()?[\'eventType\'], \'Key Vault lifecycle alert\')}'
          runAfter: {}
        }
        Get_Rule_Display: {
          type: 'Compose'
          inputs: '@{if(contains(outputs(\'Get_Rule\'), \'-\'), last(split(outputs(\'Get_Rule\'), \'-\')), outputs(\'Get_Rule\'))}'
          runAfter: {
            Get_Rule: [
              'Succeeded'
            ]
          }
        }
        Get_Rule_Label: {
          type: 'Compose'
          inputs: '@{coalesce(triggerBody()?[\'data\']?[\'essentials\']?[\'alertRule\'], \'Alert\')}'
          runAfter: {
            Get_Rule_Display: [
              'Succeeded'
            ]
          }
        }
        Get_Type: {
          type: 'Compose'
          inputs: '@{coalesce(triggerBody()?[\'data\']?[\'alertContext\']?[\'event\']?[\'type\'], triggerBody()?[\'data\']?[\'alertContext\']?[\'eventType\'], triggerBody()?[\'data\']?[\'alertContext\']?[\'properties\']?[\'eventType\'], triggerBody()?[\'data\']?[\'essentials\']?[\'monitoringService\'], triggerBody()?[\'data\']?[\'alertContext\']?[\'conditionType\'], \'Monitor\')}'
          runAfter: {}
        }
        Get_Type_Display: {
          type: 'Compose'
          inputs: '@{if(contains(outputs(\'Get_Type\'), \'.\'), last(split(outputs(\'Get_Type\'), \'.\')), outputs(\'Get_Type\'))}'
          runAfter: {
            Get_Type: [
              'Succeeded'
            ]
          }
        }
        Get_Type_Label: {
          type: 'Compose'
          inputs: '@{if(equals(outputs(\'Get_Type_Display\'), \'SecretNewVersionCreated\'), \'New KeyVault Secret Created\', if(equals(outputs(\'Get_Type_Display\'), \'SecretExpired\'), \'KeyVault Secret Expired\', if(equals(outputs(\'Get_Type_Display\'), \'SecretNearExpiry\'), \'KeyVault Secret Expiring Soon\', if(equals(outputs(\'Get_Type_Display\'), \'CertificateNewVersionCreated\'), \'New Certificate Created\', if(equals(outputs(\'Get_Type_Display\'), \'CertificateExpired\'), \'Certificate Expired\', if(equals(outputs(\'Get_Type_Display\'), \'CertificateNearExpiry\'), \'Certificate Expiring Soon\', outputs(\'Get_Type_Display\')))))))}'
          runAfter: {
            Get_Type_Display: [
              'Succeeded'
            ]
          }
        }
        Get_Subject_Raw: {
          type: 'Compose'
          inputs: '@{coalesce(triggerBody()?[\'data\']?[\'essentials\']?[\'description\'], \'No description\')}'
          runAfter: {}
        }
        Get_Subject: {
          type: 'Compose'
          inputs: '@{if(greater(length(outputs(\'Get_Subject_Raw\')), 80), concat(substring(outputs(\'Get_Subject_Raw\'), 0, 77), \'...\'), outputs(\'Get_Subject_Raw\'))}'
          runAfter: {
            Get_Subject_Raw: [
              'Succeeded'
            ]
          }
        }
        Get_Severity: {
          type: 'Compose'
          inputs: '@{coalesce(triggerBody()?[\'data\']?[\'essentials\']?[\'severity\'], \'Info\')}'
          runAfter: {}
        }
        Get_Severity_Icon: {
          type: 'Compose'
          inputs: '@{if(or(equals(outputs(\'Get_Severity\'), \'Sev0\'), equals(outputs(\'Get_Severity\'), \'Sev1\')), \'🚨\', if(equals(outputs(\'Get_Severity\'), \'Sev2\'), \'⚠️\', if(equals(outputs(\'Get_Severity\'), \'Sev3\'), \'ℹ️\', \'🔔\')))}'
          runAfter: {
            Get_Severity: [
              'Succeeded'
            ]
          }
        }
        Get_Severity_Color: {
          type: 'Compose'
          inputs: '@{if(or(equals(outputs(\'Get_Severity\'), \'Sev0\'), equals(outputs(\'Get_Severity\'), \'Sev1\')), \'danger\', if(equals(outputs(\'Get_Severity\'), \'Sev2\'), \'warning\', \'good\'))}'
          runAfter: {
            Get_Severity: [
              'Succeeded'
            ]
          }
        }
        Get_Resource: {
          type: 'Compose'
          inputs: '@{coalesce(triggerBody()?[\'data\']?[\'alertContext\']?[\'event\']?[\'source\'], triggerBody()?[\'data\']?[\'essentials\']?[\'alertTargetIDs\']?[0], \'N-A\')}'
          runAfter: {}
        }
        Get_Resource_Display: {
          type: 'Compose'
          inputs: '@{if(contains(outputs(\'Get_Resource\'), \'/\'), last(split(outputs(\'Get_Resource\'), \'/\')), outputs(\'Get_Resource\'))}'
          runAfter: {
            Get_Resource: [
              'Succeeded'
            ]
          }
        }
        Get_Time: {
          type: 'Compose'
          inputs: '@{coalesce(triggerBody()?[\'data\']?[\'alertContext\']?[\'event\']?[\'time\'], triggerBody()?[\'data\']?[\'essentials\']?[\'firedDateTime\'], utcNow())}'
          runAfter: {}
        }
        Get_Time_Display: {
          type: 'Compose'
          inputs: '@{concat(formatDateTime(outputs(\'Get_Time\'), \'yyyy-MM-dd HH:mm:ss\'), \' UTC\')}'
          runAfter: {
            Get_Time: [
              'Succeeded'
            ]
          }
        }
        Get_InvestigationLink: {
          type: 'Compose'
          inputs: '@{coalesce(triggerBody()?[\'data\']?[\'essentials\']?[\'investigationLink\'], \'N-A\')}'
          runAfter: {}
        }
        Get_ObjectName: {
          type: 'Compose'
          inputs: '@{coalesce(triggerBody()?[\'data\']?[\'alertContext\']?[\'event\']?[\'data\']?[\'ObjectName\'], triggerBody()?[\'data\']?[\'alertContext\']?[\'event\']?[\'subject\'], \'Item\')}'
          runAfter: {}
        }
        Get_Item_Display: {
          type: 'Compose'
          inputs: '@{if(equals(outputs(\'Get_ObjectName\'), \'Item\'), coalesce(triggerBody()?[\'data\']?[\'essentials\']?[\'configurationItems\']?[0], triggerBody()?[\'data\']?[\'alertContext\']?[\'properties\']?[\'title\'], outputs(\'Get_Type_Display\')), outputs(\'Get_ObjectName\'))}'
          runAfter: {
            Get_ObjectName: [
              'Succeeded'
            ]
            Get_Type_Display: [
              'Succeeded'
            ]
          }
        }
        Build_Slack_Message: {
          type: 'Compose'
          inputs: '@{concat(\'*Monitor Alert*\', \'\\n*Rule:* \', outputs(\'Get_Rule_Label\'), \'\\n*Type:* \', outputs(\'Get_Type_Display\'), \'\\n*Subject:* \', outputs(\'Get_Subject\'), \'\\n*Resource:* \', outputs(\'Get_Resource_Display\'), \'\\n*Time:* \', outputs(\'Get_Time_Display\'), \'\\n*Severity:* \', outputs(\'Get_Severity\'))}'
          runAfter: {
            Get_Rule: [
              'Succeeded'
            ]
            Get_Rule_Display: [
              'Succeeded'
            ]
            Get_Rule_Label: [
              'Succeeded'
            ]
            Get_Type: [
              'Succeeded'
            ]
            Get_Type_Display: [
              'Succeeded'
            ]
            Get_Subject_Raw: [
              'Succeeded'
            ]
            Get_Subject: [
              'Succeeded'
            ]
            Get_Severity: [
              'Succeeded'
            ]
            Get_Severity_Icon: [
              'Succeeded'
            ]
            Get_Resource: [
              'Succeeded'
            ]
            Get_Resource_Display: [
              'Succeeded'
            ]
            Get_Time: [
              'Succeeded'
            ]
            Get_Time_Display: [
              'Succeeded'
            ]
            Get_InvestigationLink: [
              'Succeeded'
            ]
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
              text: ' '
              attachments: [
                {
                  color: '@{outputs(\'Get_Severity_Color\')}'
                  blocks: [
                    {
                      type: 'header'
                      text: {
                        type: 'plain_text'
                        text: '@{concat(outputs(\'Get_Severity_Icon\'), \' \', outputs(\'Get_Type_Label\'))}'
                        emoji: true
                      }
                    }
                    {
                      type: 'section'
                      fields: [
                        {
                          type: 'mrkdwn'
                          text: '*Rule*\n@{outputs(\'Get_Rule_Label\')}'
                        }
                        {
                          type: 'mrkdwn'
                          text: '*Type*\n`@{outputs(\'Get_Type_Display\')}`'
                        }
                        {
                          type: 'mrkdwn'
                          text: '*Context*\n@{outputs(\'Get_Item_Display\')}'
                        }
                        {
                          type: 'mrkdwn'
                          text: '*Subject*\n@{outputs(\'Get_Subject\')}'
                        }
                        {
                          type: 'mrkdwn'
                          text: '*Resource*\n@{outputs(\'Get_Resource_Display\')}'
                        }
                        {
                          type: 'mrkdwn'
                          text: '*Time*\n@{outputs(\'Get_Time_Display\')}'
                        }
                        {
                          type: 'mrkdwn'
                          text: '*Severity*\n@{outputs(\'Get_Severity\')}'
                        }
                        {
                          type: 'mrkdwn'
                          text: '*Alert Link*\n@{if(equals(outputs(\'Get_InvestigationLink\'), \'N-A\'), \'N-A\', concat(\'<\', outputs(\'Get_InvestigationLink\'), \'|Open in Azure Monitor>\'))}'
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          }
          runAfter: {
            Build_Slack_Message: [
              'Succeeded'
            ]
            Get_Severity_Icon: [
              'Succeeded'
            ]
            Get_Severity_Color: [
              'Succeeded'
            ]
            Get_Rule_Display: [
              'Succeeded'
            ]
            Get_Rule_Label: [
              'Succeeded'
            ]
            Get_Type_Label: [
              'Succeeded'
            ]
            Get_Resource_Display: [
              'Succeeded'
            ]
            Get_Time_Display: [
              'Succeeded'
            ]
            Get_Item_Display: [
              'Succeeded'
            ]
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

output workflowResourceId string = slackAlertWorkflow.id
#disable-next-line outputs-should-not-contain-secrets
output manualTriggerCallbackUrl string = listCallbackUrl(resourceId('Microsoft.Logic/workflows/triggers', workflowName, 'manual'), '2019-05-01').value
