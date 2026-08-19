# Shared Alerting (Bicep) 🚨

This repository contains the shared alerting infrastructure for EPR. The deployment is driven from `main.bicep` and routes Azure Monitor alerts through a generic Action Group into a Common Alert Schema processor Logic App, then through a team router to team-specific Slack channel interface Logic Apps.

## Quick Start 🚀

1. From the repository root, review `main.bicep` and `params/dev1.bicepparam`.
2. Update or add alert definitions in the JSON files under `data/`.
3. Validate the deployment:
  - `az deployment group validate --mode Incremental --resource-group <rg> --template-file main.bicep --parameters params/dev1.bicepparam`
4. Run what-if to preview changes:
  - `az deployment group what-if --mode Incremental --resource-group <rg> --template-file main.bicep --parameters params/dev1.bicepparam`
5. Deploy when changes look correct:
  - `az deployment group create --mode Incremental --resource-group <rg> --template-file main.bicep --parameters params/dev1.bicepparam`

## Which File Do I Edit? 🧭

| Alert Type | Primary File(s) To Edit | Notes |
| --- | --- | --- |
| Health check metric alerts (Web Apps / Function Apps) | `data/platform/healthcheck-targets.json` and `data/team1/healthcheck-targets.json` | Add or update target entries; `main.bicep` loops these files into metric alert module deployments. |
| Key Vault secret/certificate lifecycle alerts | `data/platform/keyvault-event-subscriptions.json` | Add event subscription definitions (event type, severity, name suffix) routed through MonitorAlert destination to the generic action group. |
| ACR vulnerability log query alerts | `data/platform/acr-vulnerability-query-rules.json` | Add scheduled query rule objects (name suffix, severity, KQL query). |
| App Insights query alerts | `data/team1/appinsights-query-rules.json` | Add query definitions with `team` and `runbookUrl` custom properties. |
| Notification processing and routing | `modules/logicApp/slack-commonAlertSchema.bicep`, `modules/logicApp/slack-router.bicep`, `modules/logicApp/slack-channelInterface.bicep`, `modules/actionGroup/generic.bicep` | Edit when changing alert payload formatting, routing, or Slack channel delivery behavior. |
| Deployment parameters (environment-specific names and channel mappings) | `params/dev1.bicepparam`, `params/tst1.bicepparam` | Update Key Vault and Log Analytics names/resource groups and `channelInterfaces` secret-name mappings per environment. |

## Entry Point 📍

- Template entry point: `main.bicep`
- Environment parameters: `params/dev1.bicepparam`, `params/tst1.bicepparam`
- Pipeline entry point: `azure-pipelines.yaml`

## How The Templates Work 🏗️

`main.bicep` orchestrates all resources and modules in this order:

1. References an existing Log Analytics workspace.
2. Deploys the Common Alert Schema processor Logic App (`slack-commonAlertSchema`).
3. Deploys Slack channel interface Logic Apps for platform and team1.
4. Deploys the team router Logic App and wires interface callback URLs.
5. Deploys a generic Action Group wired to the processor Logic App callback URL.
6. Deploys a Key Vault Event Grid System Topic.
7. Deploys Event Grid subscriptions from JSON config and routes them to Azure Monitor alerts with the generic Action Group.
8. Deploys health check metric alerts from JSON config and routes them to the generic Action Group.
9. Deploys ACR and App Insights scheduled query alerts from JSON config and routes them to the generic Action Group.

## What Gets Created 📦

### Notification and Routing 🔁

- Common Alert Schema processor Logic App
  - File: `modules/logicApp/slack-commonAlertSchema.bicep`
  - Purpose: receives Common Alert Schema payloads, builds a router payload of shape `{ team, payload }`, and forwards to router.

- Team router Logic App
  - File: `modules/logicApp/slack-router.bicep`
  - Purpose: routes payloads to channel interface Logic Apps based on team (defaults to platform).

- Channel interface Logic Apps
  - File: `modules/logicApp/slack-channelInterface.bicep`
  - Purpose: pass-through posting of already-formatted Slack payload to team-specific webhook URL.

- Generic Action Group
  - File: `modules/actionGroup/generic.bicep`
  - Purpose: central alert action target used by alert rules; invokes the Common Alert Schema processor.
  - Important: `useCommonAlertSchema` is enabled for Logic App and webhook receivers. ⚠️

### Key Vault Event Alerts 🔐

- Key Vault System Topic
  - File: `modules/systemTopic.bicep`

- Event Subscriptions for secret/certificate lifecycle events
  - File: `modules/eventSubscription.bicep`
  - Data: `data/platform/keyvault-event-subscriptions.json`

### Metric Alerts (Health Check) ❤️

- Health check metric alerts for web targets
  - Module implementation: `modules/metricAlert/healthCheck-webApp.bicep`
  - Data: `data/platform/healthcheck-targets.json` and `data/team1/healthcheck-targets.json`

### Log Alerts (ACR Vulnerabilities) 🛡️

- Scheduled query rules for ACR vulnerability findings
  - Resource type: `Microsoft.Insights/scheduledQueryRules@2023-12-01`
  - Data: `data/platform/acr-vulnerability-query-rules.json`

- Scheduled query rules for App Insights traces
  - Resource type: `Microsoft.Insights/scheduledQueryRules@2023-12-01`
  - Data: `data/team1/appinsights-query-rules.json`

## Data-Driven Configuration 🧩

The deployment uses JSON data files for repeatable alert definitions:

- `data/platform/healthcheck-targets.json` and `data/team1/healthcheck-targets.json`
  - Defines target resource names/resource groups and description for health alerts.

- `data/platform/keyvault-event-subscriptions.json`
  - Defines Key Vault event types, severities, and name suffixes.

- `data/platform/acr-vulnerability-query-rules.json`
  - Defines KQL query rules, severities, and naming for ACR vulnerability alerts.

- `data/team1/appinsights-query-rules.json`
  - Defines App Insights query rules, severities, naming, and custom team metadata.

Custom property routing note 🧠:

- Query/metric alert definitions can include `team` in `customProperties`.
- Processor/router logic uses this team value for route selection.
- If `team` is missing or empty, route defaults to `platform`.

Parameter-driven channel mapping 🗺️:

- `channelInterfaces` is an object parameter in `main.bicep`.
- Keys are team route names (for example `platform`, `team1`).
- Values are Key Vault secret names containing Slack webhook URLs.
- Configure per environment in bicepparam files.

## Health Check Token Placeholders 🏷️

Healthcheck target files support simple placeholder tokens, replaced in `main.bicep` before deployment:

- `{ENV}`: environment type (example: `DEV`)
- `{ENV_NO}`: environment number (example: `1`)

Example:

- `"targetName": "{ENV}RWDWEBWA{ENV_NO}401"`
- `"description": "Health check for {ENV}RWDWEBWA{ENV_NO}401 dropped below 100% in the last 5 minutes"`

Important ⚠️:

- Keep naming patterns consistent with existing deployed resources to avoid accidental creates (for example `WEBWA` vs `WEBW`, `WEBFA` vs `WEBF`).
- If a value does not vary by environment (for example a fixed resource group), keep it as a literal string.

## How To Add A New Alert Hooked To The Generic Action Group ➕

Use one of these patterns depending on alert type.

### Pattern A: Add Another Instance Of An Existing Alert Type (No New Bicep Module) 🧱

1. Update the relevant JSON file in `data/`.
2. Keep required fields aligned with existing objects.
3. Run validate/what-if/deploy.

Examples:
- New health check target: add an object in `data/platform/healthcheck-targets.json` or `data/team1/healthcheck-targets.json`.
- New Key Vault event: add an object in `data/platform/keyvault-event-subscriptions.json`.
- New ACR query rule: add an object in `data/platform/acr-vulnerability-query-rules.json`.
- New App Insights query rule: add an object in `data/team1/appinsights-query-rules.json`.

All of these are already wired in `main.bicep` to pass the generic Action Group resource ID.

### Pattern B: Add A Brand-New Alert Type 🆕

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

## Local Validation And Deployment ✅

From the repository root:

- Validate:
  - `az deployment group validate --mode Incremental --resource-group <rg> --template-file main.bicep --parameters params/dev1.bicepparam`

- What-if:
  - `az deployment group what-if --mode Incremental --resource-group <rg> --template-file main.bicep --parameters params/dev1.bicepparam`

- Deploy:
  - `az deployment group create --mode Incremental --resource-group <rg> --template-file main.bicep --parameters params/dev1.bicepparam`

## CI/CD 🔄

`azure-pipelines.yaml` uses template jobs in `templates/`:

- `templates/validate-and-whatif.yaml`
- `templates/deploy-resources.yaml`

These run validate, what-if, and create against the target resource group/environment.

Current pipeline scope:

- DEV1 validate/deploy stages are enabled.
- Additional environment stages are present but commented out in `azure-pipelines.yaml`.

## Troubleshooting Notes 🛠️

- If what-if fails with `NoRegisteredProviderFound` for `metricalerts` and an unsupported API version (for example `2026-01-01`), check the API version in alert modules/resources and use a supported version for your target subscription/region.
- Keep `main.bicep` as source of truth. Do not manually author compiled ARM JSON artifacts in this repo.
