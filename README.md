# Shared Alerting (Bicep) 🚨

This repository contains the shared alerting infrastructure for EPR. The deployment is driven from `main.bicep` and routes Azure Monitor alerts through a generic Action Group into a Common Alert Schema processor Logic App, then through a channel router to channel-specific Slack channel interface Logic Apps.

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
| App Insights query alerts | `data/team1/appinsights-query-rules.json` | Add query definitions with `channel` and `runbookUrl` custom properties. |
| Notification processing and routing | `modules/logicApp/slack-commonAlertSchema.bicep`, `modules/logicApp/slack-router.bicep`, `modules/logicApp/slack-channelInterface.bicep`, `modules/actionGroup/generic.bicep` | Edit when changing alert payload formatting, routing, or Slack channel delivery behavior. |
| Deployment parameters (environment-specific names and channel mappings) | `params/dev1.bicepparam`, `params/tst1.bicepparam` | Update Key Vault and Log Analytics names/resource groups and `channelInterfaces` channel-name list per environment. |

## Entry Point 📍

- Template entry point: `main.bicep`
- Environment parameters: `params/dev1.bicepparam`, `params/tst1.bicepparam`
- Pipeline entry point: `pipelines/validate-and-deploy.yaml`

## How The Templates Work 🏗️

`main.bicep` orchestrates all resources and modules in this order:

1. References an existing Log Analytics workspace.
2. Deploys the Common Alert Schema processor Logic App (`slack-commonAlertSchema`).
3. Deploys Slack channel interface Logic Apps for each entry in `channelInterfaces`.
4. Deploys the channel router Logic App and wires interface callback URLs.
5. Deploys a generic Action Group wired to the processor Logic App callback URL.
6. Deploys a Key Vault Event Grid System Topic.
7. Deploys Event Grid subscriptions from JSON config and routes them to Azure Monitor alerts with the generic Action Group.
8. Deploys health check metric alerts from JSON config and routes them to the generic Action Group.
9. Deploys ACR and App Insights scheduled query alerts from JSON config and routes them to the generic Action Group.

## What Gets Created 📦

### Notification and Routing 🔁

- Common Alert Schema processor Logic App
  - File: `modules/logicApp/slack-commonAlertSchema.bicep`
  - Purpose: receives Common Alert Schema payloads, builds a router payload of shape `{ channelName, payload }`, and forwards to router.

- Channel router Logic App
  - File: `modules/logicApp/slack-router.bicep`
  - Purpose: routes payloads to channel interface Logic Apps based on `channelName` (defaults to `epr-alerts-platform-non-prod`).

- Channel interface Logic Apps
  - File: `modules/logicApp/slack-channelInterface.bicep`
  - Purpose: pass-through posting of already-formatted Slack payload to channel-specific webhook URL.

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
  - Defines App Insights query rules, severities, naming, and custom channel metadata.

Custom property routing note 🧠:

- Query/metric alert definitions include `channel` in `customProperties`.
- Processor/router logic uses this channel value for route selection.
- If `channel` is missing or empty, route defaults to `epr-alerts-platform-non-prod`.

Parameter-driven channel mapping 🗺️:

- `channelInterfaces` is an array parameter in `main.bicep`.
- Each entry is a Slack channel name string (for example `epr-alerts-platform-non-prod`).
- The corresponding Key Vault secret is derived as `slack-webhook-${channelName}`.
- Configure per environment in bicepparam files.

## Health Check Configuration By Environment 🏷️

Healthcheck targets are environment-keyed in JSON and selected in `main.bicep` using `${environmentType}${environmentNumber}` (for example `DEV1`, `TST1`).

Current data shape:

- `data/platform/healthcheck-targets.json` and `data/team1/healthcheck-targets.json` contain objects keyed by environment (`DEV1`, `TST1`, `PRE1`, `PRE2`, `PRD1`).
- Each environment key contains an array of target objects (`targetName`, `targetResourceGroup`, `description`, `channel`).

Important ⚠️:

- Ensure each environment key exists, even if the value is an empty array.
- Keep resource names and groups aligned with existing deployed resources to avoid accidental creates.

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

`pipelines/validate-and-deploy.yaml` uses template jobs in `pipelines/templates/`:

- `pipelines/templates/validate-and-whatif.yaml`
- `pipelines/templates/deploy-resources.yaml`

These run validate, what-if, and create against the target resource group/environment.

Current pipeline scope:

- Validate jobs are enabled for DEV1 and TST1.
- Deploy to DEV1 runs on PRs and merges/pushes to `main`.
- Deploy to TST1 runs on merges/pushes to `main` (not PRs).
- PRE/PRD stages are present but commented out in `pipelines/validate-and-deploy.yaml`.

## Troubleshooting Notes 🛠️

- If what-if fails with `NoRegisteredProviderFound` for `metricalerts` and an unsupported API version (for example `2026-01-01`), check the API version in alert modules/resources and use a supported version for your target subscription/region.
- Keep `main.bicep` as source of truth. Do not manually author compiled ARM JSON artifacts in this repo.


