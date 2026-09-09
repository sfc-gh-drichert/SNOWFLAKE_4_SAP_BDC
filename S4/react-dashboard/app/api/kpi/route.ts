import { querySnowflakeLongRunning } from "@/lib/snowflake"
import { DEMO_CONFIG } from "@/lib/demo-config"

export const dynamic = "force-dynamic"

const TABLE = `${DEMO_CONFIG.snowflake.database}.${DEMO_CONFIG.snowflake.schema}.${DEMO_CONFIG.snowflake.table}`

const SQL = `
WITH pnl AS (
  SELECT
    SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0))                                         AS gross_rev,
    SUM(IFF(PNL_CATEGORY IN ('TRADE_SPEND','RETURNS'), -HSL, 0))                        AS deductions,
    SUM(IFF(PNL_CATEGORY IN ('COGS','LOGISTICS','BRAND_ADP','SALES','RD','GA'), -HSL, 0)) AS total_costs
  FROM ${TABLE}
  WHERE (? = 0 OR FISCALYEAR = ?)
    AND (? = 'All' OR BRAND = ?)
    AND (? = 'All' OR REGION = ?)
)
SELECT
  ROUND(gross_rev / 1e6, 0)                                                       AS gross_rev_eur_m,
  ROUND((gross_rev - deductions) / 1e6, 0)                                        AS net_rev_eur_m,
  ROUND((gross_rev - deductions - total_costs) / 1e6, 0)                          AS ebit_eur_m,
  ROUND((gross_rev - deductions - total_costs) / NULLIF(gross_rev - deductions, 0) * 100, 1) AS ebit_margin_pct
FROM pnl
`

export async function GET(req: Request) {
  try {
    const url = new URL(req.url)
    const year   = parseInt(url.searchParams.get("year")   ?? "0")
    const brand  = url.searchParams.get("brand")  ?? "All"
    const region = url.searchParams.get("region") ?? "All"

    const rows = await querySnowflakeLongRunning(SQL, {
      binds: [year, year, brand, brand, region, region],
      callersRights: true,
    })
    return Response.json(rows[0] ?? null)
  } catch (e) {
    console.error(new Date().toISOString(), "[kpi]", e)
    return Response.json({ error: e instanceof Error ? e.message : "KPI query failed" }, { status: 500 })
  }
}
