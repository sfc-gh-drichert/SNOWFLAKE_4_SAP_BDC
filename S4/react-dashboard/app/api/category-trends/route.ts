import { querySnowflakeLongRunning } from "@/lib/snowflake"
import { DEMO_CONFIG } from "@/lib/demo-config"

export const dynamic = "force-dynamic"

const TABLE = `${DEMO_CONFIG.snowflake.database}.${DEMO_CONFIG.snowflake.schema}.${DEMO_CONFIG.snowflake.table}`

const SQL = `
SELECT
  FISCALYEAR,
  CATEGORY,
  ROUND(SUM(IFF(PNL_CATEGORY = 'REVENUE', HSL, 0)) / 1e6, 0) AS revenue_eur_m
FROM ${TABLE}
WHERE (? = 'All' OR BRAND = UPPER(?))
  AND (? = 'All' OR REGION = ?)
GROUP BY 1, 2
ORDER BY 1, 2
`

export async function GET(req: Request) {
  try {
    const url = new URL(req.url)
    const brand  = url.searchParams.get("brand")  ?? "All"
    const region = url.searchParams.get("region") ?? "All"

    const rows = await querySnowflakeLongRunning(SQL, {
      binds: [brand, brand, region, region],
      callersRights: true,
    })
    return Response.json(rows)
  } catch (e) {
    console.error(new Date().toISOString(), "[category-trends]", e)
    return Response.json({ error: e instanceof Error ? e.message : "Category trends query failed" }, { status: 500 })
  }
}
