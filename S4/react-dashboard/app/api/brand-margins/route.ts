import { querySnowflakeLongRunning } from "@/lib/snowflake"
import { DEMO_CONFIG } from "@/lib/demo-config"

export const dynamic = "force-dynamic"

const TABLE = `${DEMO_CONFIG.snowflake.database}.${DEMO_CONFIG.snowflake.schema}.${DEMO_CONFIG.snowflake.table}`

const SQL = `
SELECT
  BRAND,
  ROUND(SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0)) / 1e6, 0)                                            AS gross_rev_eur_m,
  ROUND(SUM(IFF(PNL_CATEGORY IN ('TRADE_SPEND','RETURNS'), -HSL, 0)) / 1e6, 0)                          AS deductions_eur_m,
  ROUND(SUM(IFF(PNL_CATEGORY IN ('COGS','LOGISTICS','BRAND_ADP','SALES','RD','GA'), -HSL, 0)) / 1e6, 0) AS costs_eur_m,
  ROUND(
    (SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0))
     - SUM(IFF(PNL_CATEGORY IN ('TRADE_SPEND','RETURNS'), -HSL, 0))
     - SUM(IFF(PNL_CATEGORY IN ('COGS','LOGISTICS','BRAND_ADP','SALES','RD','GA'), -HSL, 0))) / 1e6, 0) AS ebit_eur_m,
  ROUND(
    (SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0))
     - SUM(IFF(PNL_CATEGORY IN ('TRADE_SPEND','RETURNS'), -HSL, 0))
     - SUM(IFF(PNL_CATEGORY IN ('COGS','LOGISTICS','BRAND_ADP','SALES','RD','GA'), -HSL, 0)))
    / NULLIF(
        SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0))
        - SUM(IFF(PNL_CATEGORY IN ('TRADE_SPEND','RETURNS'), -HSL, 0)), 0) * 100, 1) AS ebit_margin_pct
FROM ${TABLE}
WHERE (? = 0 OR FISCALYEAR = ?)
  AND (? = 'All' OR REGION = ?)
GROUP BY 1
ORDER BY ebit_margin_pct DESC
`

export async function GET(req: Request) {
  try {
    const url = new URL(req.url)
    const year   = parseInt(url.searchParams.get("year")   ?? "0")
    const region = url.searchParams.get("region") ?? "All"

    const rows = await querySnowflakeLongRunning(SQL, {
      binds: [year, year, region, region],
      callersRights: true,
    })
    return Response.json(rows)
  } catch (e) {
    console.error(new Date().toISOString(), "[brand-margins]", e)
    return Response.json({ error: e instanceof Error ? e.message : "Brand margins query failed" }, { status: 500 })
  }
}
