"use client"

import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from "recharts"

interface TrendRow {
  FISCALYEAR: number
  CATEGORY: string
  revenue_eur_m: number
}

interface Props {
  data: TrendRow[]
  loading: boolean
}

const CATEGORY_COLORS: Record<string, string> = {
  COOKING:           "#f59e0b",
  COOLING:           "#3b82f6",
  DISH_CARE:         "#10b981",
  LAUNDRY_CARE:      "#8b5cf6",
  CONSUMER_PRODUCTS: "#ec4899",
}

function pivotByYear(rows: TrendRow[]) {
  const categories = [...new Set(rows.map((r) => r.CATEGORY))].sort()
  const years = [...new Set(rows.map((r) => r.FISCALYEAR))].sort()

  return years.map((year) => {
    const point: Record<string, number | string> = { year: String(year) }
    for (const cat of categories) {
      const row = rows.find((r) => r.FISCALYEAR === year && r.CATEGORY === cat)
      point[cat] = row?.revenue_eur_m ?? 0
    }
    return point
  })
}

export function CategoryTrends({ data, loading }: Props) {
  if (loading) return <div className="h-64 flex items-center justify-center text-muted-foreground text-sm">Loading…</div>
  if (!data.length) return <div className="h-64 flex items-center justify-center text-muted-foreground text-sm">No data</div>

  const categories = [...new Set(data.map((r) => r.CATEGORY))].sort()
  const pivoted = pivotByYear(data)

  return (
    <div>
      <h2 className="text-sm font-semibold mb-3">Category Revenue Trends (2023–2026)</h2>
      <ResponsiveContainer width="100%" height={240}>
        <LineChart data={pivoted} margin={{ top: 4, right: 16, left: 16, bottom: 4 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
          <XAxis dataKey="year" tick={{ fontSize: 11 }} />
          <YAxis
            tickFormatter={(v) => `€${(v / 1000).toFixed(0)}B`}
            tick={{ fontSize: 11 }}
            width={48}
          />
          <Tooltip
            formatter={(v: number, name: string) => [
              `€ ${new Intl.NumberFormat("en-US").format(Math.round(v))}M`,
              name.replace(/_/g, " "),
            ]}
            contentStyle={{ border: "1px solid var(--border)", borderRadius: 6, fontSize: 12 }}
          />
          <Legend
            formatter={(value) => value.replace(/_/g, " ")}
            wrapperStyle={{ fontSize: 11 }}
          />
          {categories.map((cat) => (
            <Line
              key={cat}
              type="monotone"
              dataKey={cat}
              stroke={CATEGORY_COLORS[cat] ?? "#94a3b8"}
              strokeWidth={2}
              dot={{ r: 3 }}
              activeDot={{ r: 5 }}
            />
          ))}
        </LineChart>
      </ResponsiveContainer>
    </div>
  )
}
