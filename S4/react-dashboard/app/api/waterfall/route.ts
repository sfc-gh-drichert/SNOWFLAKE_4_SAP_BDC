import { querySnowflakeLongRunning } from "@/lib/snowflake"
import { DEMO_CONFIG } from "@/lib/demo-config"

export const dynamic = "force-dynamic"

const TABLE = `${DEMO_CONFIG.snowflake.database}.${DEMO_CONFIG.snowflake.schema}.${DEMO_CONFIG.snowflake.table}`

const SQL = `
WITH pnl AS (
  SELECT
    SUM(IFF(PNL_CATEGORY = 'REVENUE',    HSL, 0))    AS gross_rev,
    SUM(IFF(PNL_CATEGORY = 'TRADE_SPEND', -HSL, 0))  AS trade_spend,
    SUM(IFF(PNL_CATEGORY = 'RETURNS',    -HSL, 0))   AS returns_d,
    SUM(IFF(PNL_CATEGORY = 'COGS',       -HSL, 0))   AS cogs,
    SUM(IFF(PNL_CATEGORY = 'LOGISTICS',  -HSL, 0))   AS logistics,
    SUM(IFF(PNL_CATEGORY = 'BRAND_ADP',  -HSL, 0))   AS brand_adp,
    SUM(IFF(PNL_CATEGORY = 'SALES',      -HSL, 0))   AS sales,
    SUM(IFF(PNL_CATEGORY = 'RD',         -HSL, 0))   AS rd,
    SUM(IFF(PNL_CATEGORY = 'GA',         -HSL, 0))   AS ga
  FROM ${TABLE}
  WHERE (? = 0 OR FISCALYEAR = ?)
    AND (? = 'All' OR BRAND = ?)
    AND (? = 'All' OR REGION = ?)
)
SELECT
  ROUND(gross_rev  / 1e6, 0)                                                                     AS gross_rev,
  ROUND(trade_spend / 1e6, 0)                                                                    AS trade_spend,
  ROUND(returns_d / 1e6, 0)                                                                      AS returns_d,
  ROUND((gross_rev - trade_spend - returns_d) / 1e6, 0)                                          AS net_rev,
  ROUND(cogs / 1e6, 0)                                                                           AS cogs,
  ROUND(logistics / 1e6, 0)                                                                      AS logistics,
  ROUND((gross_rev - trade_spend - returns_d - cogs - logistics) / 1e6, 0)                       AS gross_profit,
  ROUND(brand_adp / 1e6, 0)                                                                      AS brand_adp,
  ROUND(sales / 1e6, 0)                                                                          AS sales,
  ROUND((gross_rev - trade_spend - returns_d - cogs - logistics - brand_adp - sales) / 1e6, 0)   AS db1,
  ROUND(rd / 1e6, 0)                                                                             AS rd,
  ROUND(ga / 1e6, 0)                                                                             AS ga,
  ROUND((gross_rev - trade_spend - returns_d - cogs - logistics - brand_adp - sales - rd - ga) / 1e6, 0) AS ebit,
  ROUND((gross_rev - trade_spend - returns_d - cogs - logistics - brand_adp - sales - rd - ga)
        / NULLIF(gross_rev - trade_spend - returns_d, 0) * 100, 1)                               AS ebit_margin_pct
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
    console.error(new Date().toISOString(), "[waterfall]", e)
    return Response.json({ error: e instanceof Error ? e.message : "Waterfall query failed" }, { status: 500 })
  }
}
