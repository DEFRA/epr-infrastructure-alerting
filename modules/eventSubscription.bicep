param actionGroupResourceIds array
param eventSubscriptionDescription string = 'Key Vault secret lifecycle event received'
param eventSubscriptionName string
param includedEventTypes array
param monitorAlertSeverity string = 'Sev3'
param systemTopicName string

resource systemTopic 'Microsoft.EventGrid/systemTopics@2022-06-15' existing = {
  name: systemTopicName
}

resource eventSubscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2025-07-15-preview' = {
  name: eventSubscriptionName
  parent: systemTopic
  properties: {
    eventDeliverySchema: 'CloudEventSchemaV1_0'
    filter: {
      includedEventTypes: includedEventTypes
    }
    destination: {
      endpointType: 'MonitorAlert'
      properties: {
        severity: monitorAlertSeverity
        description: eventSubscriptionDescription
        actionGroups: actionGroupResourceIds
      }
    }
  }
}

output eventSubscriptionId string = eventSubscription.id
output eventSubscriptionName string = eventSubscription.name
