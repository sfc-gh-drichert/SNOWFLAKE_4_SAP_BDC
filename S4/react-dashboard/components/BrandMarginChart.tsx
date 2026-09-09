"use client"

import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Cell,
  ResponsiveContainer,
  LabelList,
} from "recharts"

interface BrandRow {
  BRAND: string
  gross_rev_eur_m: number
  deductions_eur_m: number
  costs_eur_m: number
  ebit_eur_m: number
  ebit_margin_pct: number
}

interface Props {
  data: BrandRow[]
  loading: boolean
}

function marginColor(pct: number): string {
  if (pct >= 10) return "#10b981"
  if (pct >= 5)  return "#6366f1"
  if (pct >= 0)  return "#f59e0b"
  return "#ef4444"
}

export function BrandMarginChart({ data, loading }: Props) {
  if (loading) return <div className="h-64 flex items-center justify-center text-muted-foreground text-sm">Loading…</div>
  if (!data.length) return <div className="h-64 flex items-center justify-center text-muted-foreground text-sm">No data</div>

  return (
    <div>
      <h2 className="text-sm font-semibold mb-3">EBIT Margin by Brand</h2>
      <ResponsiveContainer width="100%" height={220}>
        <BarChart
          data={data}
          layout="vertical"
          margin={{ top: 4, right: 60, left: 16, bottom: 4 }}
        >
          <CartesianGrid strokeDasharray="3 3" horizontal={false} stroke="var(--border)" />
          <XAxis
            type="number"
            domain={[0, "dataMax + 2"]}
            tickFormatter={(v) => `${v}%`}
            tick={{ fontSize: 11 }}
          />
          <YAxis dataKey="BRAND" type="category" tick={{ fontSize: 12 }} width={72} />
          <Tooltip
            formatter={(v: number) => [`${v.toFixed(1)}%`, "EBIT Margin"]}
            contentStyle={{ border: "1px solid var(--border)", borderRadius: 6, fontSize: 12 }}
          />
          <Bar dataKey="ebit_margin_pct" radius={[0, 3, 3, 0]}>
            <LabelList
              dataKey="ebit_margin_pct"
              position="right"
              formatter={(v: number) => `${v.toFixed(1)}%`}
              style={{ fontSize: 11, fill: "var(--muted-foreground)" }}
            />
            {data.map((row, i) => (
              <Cell key={i} fill={marginColor(row.ebit_margin_pct)} />
            ))}
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </div>
  )
}
