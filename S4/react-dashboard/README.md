# P&L Analytics Dashboard

Snowflake App Runtime (SAR) app: a two-panel financial dashboard over SAP-sourced PnL data, with a streaming Cortex Agent chat panel.

## What it does

| Panel | Content |
|-------|---------|
| Left (60%) | KPI cards, P&L waterfall chart, EBIT margin by brand, category revenue trends 2023–2026 |
| Right (40%) | Streaming Cortex Agent chat (`BSH_PNL_AGENT`) with generated-SQL display |

Filters (Year / Brand / Region) drive all four chart panels independently.
All SQL queries run with **caller's rights** so the Row Access Policy on `S3_FINANCE_PNL` is enforced — each user's role sees only their authorised regions.

## Rebranding for a new customer

Edit **one file**: [`lib/demo-config.ts`](lib/demo-config.ts)

```typescript
company: {
  name:         "ACME Corp",
  shortName:    "ACME",
  primaryColor: "#FF6600",
  currency:     "USD",
  ...
},
snowflake: {
  agentFqn: "MY_DB.MY_SCHEMA.ACME_PNL_AGENT",
  ...
},
```

Override the brand color in [`app/globals.css`](app/globals.css) → `--brand-primary`.

## Local development

```bash
npm install
npm run dev
```

The app auto-falls back to your `~/.snowflake/config.toml` default connection for local dev.

## Deploy

> **Build first, then deploy.** The SAR builder receives pre-built output and packages it — no network egress is required inside the builder container.

**Local** (requires `snow` CLI):

```bash
cd S4/react-dashboard
npm install
npm run build
cp -r .next/static .next/standalone/.next/static
cp -r public .next/standalone/public

snow app deploy --target dev              # or: make dashboard-install TARGET=dev
```

**GitHub Actions** — trigger the workflow with `action: react-dashboard-only`:
- `npm ci` + `npm run build` run on the GitHub Actions runner (internet available)
- The pre-built output is uploaded and deployed — no EAI required
- Set `deploy_target: customer` (or another target defined in `app.yml`)

## Adding a new deployment target

In [`app.yml`](app.yml), add a named target under `targets:`:

```yaml
targets:
  dev: {}
  customer: {}
  new_account:
    database: MY_DB
    query_warehouse: MY_WH
```

Then deploy with `snow app deploy --target new_account`.

## Data sources

| Object | Purpose |
|--------|---------|
| `S4.FIN.S3_FINANCE_PNL` | PnL fact table (ACDOCA/CO-PA structure, 100K rows, Jan 2023–Sep 2026) |
| `S4.FIN.BSH_PNL_ANALYTICS_SV` | Semantic View used by Cortex Analyst |
| `S4.FIN.BSH_PNL_AGENT` | Cortex Agent (PnL_Analyst + BSH_Docs_Search tools) |
