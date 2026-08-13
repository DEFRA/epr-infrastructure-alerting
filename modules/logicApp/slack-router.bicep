param workflowName string
param location string
@secure()
param platformCallbackUrl string
@secure()
param team1CallbackUrl string
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
        platformCallbackUrl: {
          type: 'SecureString'
        }
        team1CallbackUrl: {
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
              properties: {
                team: {
                  type: 'string'
                }
                payload: {
                  type: 'object'
                }
              }
            }
          }
        }
      }
      actions: {
        Resolve_Team: {
          type: 'Compose'
          inputs: '@{toLower(trim(string(coalesce(triggerBody()?[\'team\'], \'\'))))}'
          runAfter: {}
        }
        Route_To_Team1_If_Match: {
          type: 'If'
          expression: '@equals(outputs(\'Resolve_Team\'), \'team1\')'
          actions: {
            Forward_To_Team1: {
              type: 'Http'
              inputs: {
                method: 'POST'
                uri: '@parameters(\'team1CallbackUrl\')'
                headers: {
                  'Content-Type': 'application/json'
                }
                body: '@coalesce(triggerBody()?[\'payload\'], json(\'{}\'))'
              }
              runAfter: {}
            }
          }
          else: {
            actions: {
              Forward_To_Platform: {
                type: 'Http'
                inputs: {
                  method: 'POST'
                  uri: '@parameters(\'platformCallbackUrl\')'
                  headers: {
                    'Content-Type': 'application/json'
                  }
                  body: '@coalesce(triggerBody()?[\'payload\'], json(\'{}\'))'
                }
                runAfter: {}
              }
            }
          }
          runAfter: {
            Resolve_Team: [
              'Succeeded'
            ]
          }
        }
      }
      outputs: {}
    }
    parameters: {
      platformCallbackUrl: {
        value: platformCallbackUrl
      }
      team1CallbackUrl: {
        value: team1CallbackUrl
      }
    }
  }
}

output workflowResourceId string = workflow.id
#disable-next-line outputs-should-not-contain-secrets
output manualTriggerCallbackUrl string = listCallbackUrl(resourceId('Microsoft.Logic/workflows/triggers', workflowName, 'manual'), '2019-05-01').value
