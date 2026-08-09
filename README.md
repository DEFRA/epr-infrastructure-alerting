# Shared Alerting (Bicep)

This folder contains the shared alerting infrastructure for EPR. The deployment is driven from `main.bicep` and currently routes alert notifications through a single generic Action Group into a Logic App that handles Azure Monitor Common Alert Schema payloads and posts to Slack.

## Quick Start

1. Open `shared-infra/alerting` and review `main.bicep` and `params/dev.bicepparam`.
2. Update or add alert definitions in the JSON files under `data/`.
3. Validate the deployment:
  - `az deployment group validate --mode Incremental --resource-group <rg> --template-file main.bicep --parameters params/dev.bicepparam`
4. Run what-if to preview changes:
  - `az deployment group what-if --mode Incremental --resource-group <rg> --template-file main.bicep --parameters params/dev.bicepparam`
5. Deploy when changes look correct:
  - `az deployment group create --mode Incremental --resource-group <rg> --template-file main.bicep --parameters params/dev.bicepparam`

## Which File Do I Edit?

| Alert Type | Primary File(s) To Edit | Notes |
| --- | --- | --- |
| Health check metric alerts (Web Apps / Function Apps) | `data/platform/healthcheck-targets.json` and `data/team1/healthcheck-targets.json` | Add or update target entries; `main.bicep` loops these files into metric alert module deployments. |
| Key Vault secret/certificate lifecycle alerts | `data/keyvault-event-subscriptions.json` | Add event subscription definitions (event type, severity, name suffix) routed through MonitorAlert destination to the generic action group. |
| ACR vulnerability log query alerts | `data/acr-vulnerability-query-rules.json` | Add scheduled query rule objects (name suffix, severity, KQL query). |
| Generic notification routing (shared for all above) | `modules/actionGroup/generic.bicep` and `modules/logicApp/slack-commonAlertSchema.bicep` | Only edit when changing how alerts are delivered (for example receiver behavior or Slack message formatting). |
| Deployment parameters (environment-specific names) | `params/dev.bicepparam` | Update Key Vault and Log Analytics names/resource groups per environment. |

## Entry Point

- Template entry point: `main.bicep`
- Environment parameters: `params/dev.bicepparam`
- Pipeline entry point: `azure-pipelines.yaml`

## How The Templates Work

`main.bicep` orchestrates all resources and modules in this order:

1. References an existing Log Analytics workspace.
2. Deploys a generic Slack Logic App.
3. Deploys a generic Action Group wired to that Logic App callback URL.
4. Deploys a Key Vault Event Grid System Topic.
5. Deploys Event Grid subscriptions from JSON config and routes them to Azure Monitor alerts with the generic Action Group.
6. Deploys health check metric alerts from JSON config and routes them to the generic Action Group.
7. Deploys ACR vulnerability scheduled query alerts from JSON config and routes them to the generic Action Group.

## What Gets Created

### Notification and Routing

- Generic Slack Logic App
  - File: `modules/logicApp/slack-commonAlertSchema.bicep`
  - Purpose: receives Common Alert Schema payloads and posts formatted messages to Slack.

- Generic Action Group
  - File: `modules/actionGroup/generic.bicep`
  - Purpose: central alert action target used by alert rules.
  - Important: `useCommonAlertSchema` is enabled for Logic App and webhook receivers.

### Key Vault Event Alerts

- Key Vault System Topic
  - File: `modules/systemTopic.bicep`

- Event Subscriptions for secret/certificate lifecycle events
  - File: `modules/eventSubscription.bicep`
  - Data: `data/keyvault-event-subscriptions.json`

### Metric Alerts (Health Check)

- Health check metric alerts for web targets
  - Module implementation: `modules/metricAlert/healthCheck-webApp.bicep`
  - Data: `data/platform/healthcheck-targets.json` and `data/team1/healthcheck-targets.json`

### Log Alerts (ACR Vulnerabilities)

- Scheduled query rules for ACR vulnerability findings
  - Resource type: `Microsoft.Insights/scheduledQueryRules@2023-12-01`
  - Data: `data/acr-vulnerability-query-rules.json`

## Data-Driven Configuration

The deployment uses JSON data files for repeatable alert definitions:

- `data/platform/healthcheck-targets.json` and `data/team1/healthcheck-targets.json`
  - Defines target resource names/resource groups and description for health alerts.

- `data/keyvault-event-subscriptions.json`
  - Defines Key Vault event types, severities, and name suffixes.

- `data/acr-vulnerability-query-rules.json`
  - Defines KQL query rules, severities, and naming for ACR vulnerability alerts.

## Healthcheck Token Placeholders

Healthcheck target files support simple placeholder tokens, replaced in `main.bicep` before deployment:

- `{ENV}`: environment type (example: `DEV`)
- `{ENV_NO}`: environment number (example: `1`)

Example:

- `"targetName": "{ENV}RWDWEBWA{ENV_NO}401"`
- `"description": "Health check for {ENV}RWDWEBWA{ENV_NO}401 dropped below 100% in the last 5 minutes"`

Important:

- Keep naming patterns consistent with existing deployed resources to avoid accidental creates (for example `WEBWA` vs `WEBW`, `WEBFA` vs `WEBF`).
- If a value does not vary by environment (for example a fixed resource group), keep it as a literal string.

## How To Add A New Alert Hooked To The Generic Action Group

Use one of these patterns depending on alert type.

### Pattern A: Add Another Instance Of An Existing Alert Type (No New Bicep Module)

1. Update the relevant JSON file in `data/`.
2. Keep required fields aligned with existing objects.
3. Run validate/what-if/deploy.

Examples:
- New health check target: add an object in `data/platform/healthcheck-targets.json` or `data/team1/healthcheck-targets.json`.
- New Key Vault event: add an object in `data/keyvault-event-subscriptions.json`.
- New ACR query rule: add an object in `data/acr-vulnerability-query-rules.json`.

All of these are already wired in `main.bicep` to pass the generic Action Group resource ID.

### Pattern B: Add A Brand-New Alert Type

1. Create a new module under `modules/` (or inline resource in `main.bicep`).
2. Accept an `actionGroupIds`/`actionGroupId` parameter.
3. Wire alert actions to `genericActionGroup.outputs.actionGroupId`.
4. Add any new data file and loop in `main.bicep` if you want multiple instances.

Key wiring in `main.bicep`:

- For Metric Alerts (`Microsoft.Insights/metricAlerts`):
  - Set `properties.actions[].actionGroupId` to `genericActionGroup.outputs.actionGroupId`.

- For Scheduled Query Rules (`Microsoft.Insights/scheduledQueryRules`):
  - Set `properties.actions.actionGroups` to include `genericActionGroup.outputs.actionGroupId`.

- For Event Grid MonitorAlert destination:
  - Set `destination.properties.actionGroups` to include `genericActionGroup.outputs.actionGroupId`.

## Local Validation And Deployment

From `shared-infra/alerting`:

- Validate:
  - `az deployment group validate --mode Incremental --resource-group <rg> --template-file main.bicep --parameters params/dev.bicepparam`

- What-if:
  - `az deployment group what-if --mode Incremental --resource-group <rg> --template-file main.bicep --parameters params/dev.bicepparam`

- Deploy:
  - `az deployment group create --mode Incremental --resource-group <rg> --template-file main.bicep --parameters params/dev.bicepparam`

## CI/CD

`azure-pipelines.yaml` uses template jobs in `templates/`:

- `templates/validate-and-whatif.yaml`
- `templates/deploy-resources.yaml`

These run validate, what-if, and create against the target resource group/environment.

## Troubleshooting Notes

- If what-if fails with `NoRegisteredProviderFound` for `metricalerts` and an unsupported API version (for example `2026-01-01`), check the API version in alert modules/resources and use a supported version for your target subscription/region.
- Keep `main.bicep` as source of truth. `main.json` is a compiled artifact and should not be manually edited.
