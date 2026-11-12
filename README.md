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
| Key Vault secret/certificate lifecycle alerts | `data/platform/keyvault-event-subscriptions.json` | Add event subscription definitions (event type, severity, name suffix, optional secret/certificate name filters) routed through MonitorAlert destination to the generic action group. See [Key Vault Alerts: Specific Secrets And Team Routing](#key-vault-alerts-specific-secrets-and-team-routing-). |
| Key Vault secret/certificate routing to a team channel | `data/<team-folder>/keyvault-secret-routes.json` | Map secret/certificate names or prefixes to your team's channel, per environment. |
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
  - For Event Grid (Key Vault) alerts, adds the secret/certificate name, vault name and expiry from `data.alertContext.event` to the Slack message.

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
  - Optional Event Grid filters limit a subscription to specific secrets/certificates.

- Team routing for Key Vault alerts
  - Data: `data/<team-folder>/keyvault-secret-routes.json`
  - Applied by the processor Logic App using the secret/certificate name from the event.

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
  - Defines Key Vault event types, severities, name suffixes, and optional secret/certificate name filters.

- `data/<team-folder>/keyvault-secret-routes.json`
  - Maps Key Vault secret/certificate names or prefixes to a team channel, per environment.

- `data/platform/acr-vulnerability-query-rules.json`
  - Defines KQL query rules, severities, and naming for ACR vulnerability alerts.

- `data/team1/appinsights-query-rules.json`
  - Defines App Insights query rules, severities, naming, and custom channel metadata.

Custom property routing note 🧠:

- Query/metric alert definitions include `channel` in `customProperties`.
- Key Vault (Event Grid) alerts cannot carry custom properties, so they are routed by secret/certificate name using `keyvault-secret-routes.json`.
- The processor picks the channel in this order:
  1. `customProperties.channel` on the alert rule.
  2. A matching Key Vault secret/certificate route.
  3. `epr-alerts-platform-non-prod`. If that channel is not deployed in the environment, the router falls back to `channelInterfaceDefault`.

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

## Key Vault Alerts: Specific Secrets And Team Routing 🔐

By default every Key Vault event subscription fires for every secret or certificate in the vault, and the alert goes to the platform channel. There are two independent controls:

- **Filtering** decides *whether* an alert fires. It is configured on the event subscription and applies in every environment.
- **Routing** decides *which channel* an alert goes to. It is configured by each team and is environment-specific.

The secret/certificate name is the Event Grid event `subject` (also `data.ObjectName` in the alert payload).

### Filtering: alert on specific secrets/certificates only

Add any of these optional fields to an entry in `data/platform/keyvault-event-subscriptions.json`:

| Field | Event Grid filter | Effect |
| --- | --- | --- |
| `objectNames` | `StringIn` on `subject` | Only these exact names. |
| `objectNamePrefixes` | `StringBeginsWith` on `subject` | Only names starting with one of these prefixes. |
| `excludedObjectNames` | `StringNotIn` on `subject` | Every name except these. |
| `excludedObjectNamePrefixes` | `StringNotBeginsWith` on `subject` | Every name except those starting with one of these prefixes. |

Example: Boomi secrets and certificates (`boomi-*`) have their own Sev1 alerts, owned by the platform team. The vault-wide expiry alerts exclude them, so each Boomi event alerts once.

```json
{
  "nameSuffix": "BoomiNearExpiry",
  "description": "An Alert has been raised because a Boomi secret or certificate has 30 days left before expiry",
  "eventTypes": [
    "Microsoft.KeyVault.SecretNearExpiry",
    "Microsoft.KeyVault.CertificateNearExpiry"
  ],
  "severity": "Sev1",
  "objectNamePrefixes": ["boomi-"]
},
{
  "nameSuffix": "SecretNearExpiry",
  "description": "An Alert has been raised because a Key Vault secret has 30 days left before expiry",
  "eventTypes": ["Microsoft.KeyVault.SecretNearExpiry"],
  "severity": "Sev2",
  "excludedObjectNamePrefixes": ["boomi-"]
}
```

`BoomiExpired`, `SecretExpired`, `CertificateExpired` and `CertificateNearExpiry` follow the same pattern. The `SecretNewVersion` and `CertificateNewVersion` alerts stay vault-wide, because no Boomi-specific new-version alert exists.

Rules and limits ⚠️:

- Event Grid ANDs filters together. Use `objectNames` **or** `objectNamePrefixes` in one entry, not both, otherwise a name has to match both. The `excluded*` fields can be combined with either.
- Matching is case-insensitive. No wildcards or regex.
- At most 25 values in total across the filters of one entry.
- Filters only match on names. Key Vault tags are not in the event, so they cannot be used.
- The file is not environment-keyed. A name that does not exist in an environment's vault simply never matches.
- Adding a filtered entry does not change the existing unfiltered entries. If a secret matches both, two alerts fire. Use `excludedObjectNames` or `excludedObjectNamePrefixes` on the unfiltered entry to avoid this, as the Boomi example does.
- Entries without filter fields keep the current behaviour (whole vault).

### Routing: send a team's secrets/certificates to its channel

Add routes to `data/<team-folder>/keyvault-secret-routes.json`. Like the other team files, it is keyed by environment. A hypothetical example for submit-data:

```json
{
  "DEV1": [
    {
      "channel": "epr-alerts-submit-data-non-prod",
      "objectNames": ["example-submit-data-secret"],
      "objectNamePrefixes": ["submit-data-"]
    }
  ],
  "TST1": [],
  "PRE1": [],
  "PRD1": [
    {
      "channel": "epr-alerts-submit-data-prod",
      "objectNamePrefixes": ["submit-data-"]
    }
  ]
}
```

For a real example, see `data/platform/keyvault-secret-routes.json`. It routes `boomi-*` to the platform channel in each environment.

How a route is chosen:

- Matching is case-insensitive.
- Exact `objectNames` matches beat prefix matches. Among prefixes, the longest matching prefix wins.
- If nothing matches, the alert goes to the platform channel as before.
- Routing applies to every Key Vault event type (expired, near expiry, new version). Combine it with filtering if you only want some of them.

Rules ⚠️:

- `channel` must be in that environment's `channelInterfaces` (`params/*.bicepparam`). Otherwise the router falls back to the default channel.
- Each name or prefix should appear in only one team's file. If two teams claim the same exact name, which one wins is not defined.
- Empty prefixes are ignored, because they would match everything.
- Every environment key must exist, even if the value is an empty array.

## How To Add A New Alert Hooked To The Generic Action Group ➕

Use one of these patterns depending on alert type.

### Pattern A: Add Another Instance Of An Existing Alert Type (No New Bicep Module) 🧱

1. Update the relevant JSON file in `data/`.
2. Keep required fields aligned with existing objects.
3. Run validate/what-if/deploy.

Examples:
- New health check target: add an object in `data/platform/healthcheck-targets.json` or `data/team1/healthcheck-targets.json`.
- New Key Vault event: add an object in `data/platform/keyvault-event-subscriptions.json` (optionally filtered to specific secrets/certificates).
- Route Key Vault alerts for your secrets/certificates to your channel: add a route in `data/<team-folder>/keyvault-secret-routes.json`.
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

## Walkthrough: Add A Healthcheck Alert 👥

Ensure you have a `healthcheck-targets.json` file in the folder for your team:

- `data/<team-folder>/healthcheck-targets.json`

Steps:

1. Pick the correct environment array (`DEV1`, `TST1`, `PRE1`, `PRD1`).
2. Add a new object with `targetName`, `targetResourceGroup`, `description`, and `channel`.
3. Run validate/what-if from this README before raising a PR.

Example:

```json
{
  "DEV1": [
    {
      "targetName": "DEVRWDWEBWA1401",
      "targetResourceGroup": "DEVRWDWEBRG1401",
      "description": "Health check for DEVRWDWEBWA1401 dropped below 100% in the last 5 minutes",
      "channel": "epr-alerts-platform-non-prod"
    }
  ],
  "TST1": [],
  "PRE1": [],
  "PRD1": []
}
```

Notes:

- `main.bicep` already merges platform + non-platform team healthcheck files.
- Use `epr-alerts-platform-non-prod` for non-prod environments and `epr-alerts-platform-prod` for production.

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


