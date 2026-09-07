param workflowName string
param location string
@secure()
param defaultCallbackUrl string
param teamRoutes array
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
        defaultCallbackUrl: {
          type: 'SecureString'
        }
        teamRoutes: {
          type: 'Array'
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
        Initialize_CallbackUrl: {
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'callbackUrl'
                type: 'string'
                value: '@parameters(\'defaultCallbackUrl\')'
              }
            ]
          }
          runAfter: {
            Resolve_Team: [
              'Succeeded'
            ]
          }
        }
        Resolve_CallbackUrl: {
          type: 'Foreach'
          foreach: '@parameters(\'teamRoutes\')'
          actions: {
            Set_CallbackUrl_If_Match: {
              type: 'If'
              expression: '@equals(toLower(string(coalesce(item()?[\'team\'], \'\'))), outputs(\'Resolve_Team\'))'
              actions: {
                Set_CallbackUrl: {
                  type: 'SetVariable'
                  inputs: {
                    name: 'callbackUrl'
                    value: '@item()?[\'callbackUrl\']'
                  }
                  runAfter: {}
                }
              }
              else: {
                actions: {}
              }
              runAfter: {}
            }
          }
          runAfter: {
            Initialize_CallbackUrl: [
              'Succeeded'
            ]
          }
        }
        Route_To_Channel: {
          type: 'Http'
          inputs: {
            method: 'POST'
            uri: '@variables(\'callbackUrl\')'
            headers: {
              'Content-Type': 'application/json'
            }
            body: '@coalesce(triggerBody()?[\'payload\'], json(\'{}\'))'
          }
          runAfter: {
            Resolve_CallbackUrl: [
              'Succeeded'
            ]
          }
        }
      }
      outputs: {}
    }
    parameters: {
      defaultCallbackUrl: {
        value: defaultCallbackUrl
      }
      teamRoutes: {
        value: teamRoutes
      }
    }
  }
}

output workflowResourceId string = workflow.id
#disable-next-line outputs-should-not-contain-secrets
output manualTriggerCallbackUrl string = listCallbackUrl(resourceId('Microsoft.Logic/workflows/triggers', workflowName, 'manual'), '2019-05-01').value
