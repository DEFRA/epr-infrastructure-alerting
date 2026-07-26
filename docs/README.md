# Alerting Architecture (LikeC4)

This folder contains a starter LikeC4 model for the current alerting implementation in `shared-infra/alerting`.

## What It Models

- Platform-owned Azure DevOps pipeline for validate, what-if, and deploy.
- Team-owned notification configuration (`teams`, `slackWebhookUrls`) in params.
- Runtime alert delivery path:
  - Azure Monitor Alert
  - Action Group
  - Logic App
  - Slack webhook
  - Slack channel
- Optional extra receivers on the same Action Group:
  - Email receivers
  - Webhook receivers

## Files

- `alerting-model.c4`: LikeC4 model and views.
- `package.json`: Local scripts for running LikeC4.

## Run Locally

From this folder:

```bash
npm run dev
```

Open:

```text
http://localhost:5173/
```

Optional commands:

```bash
npm run validate
npm run build
npm run preview
```

## Suggested Next Steps

1. Add one element per real team from params files.
2. Add environment-specific views (DEV/TST/PRE/PRD).
3. Add references to team-owned monitor definition repositories when available.
4. Include runbook-link and custom-message design once implemented.
