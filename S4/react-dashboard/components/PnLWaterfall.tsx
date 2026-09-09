"use client"

import {
  ComposedChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Cell,
  ResponsiveContainer,
} from "recharts"
import { DEMO_CONFIG } from "@/lib/demo-config"

interface WaterfallData {
  gross_rev: number
  trade_spend: number
  returns_d: number
  net_rev: number
  cogs: number
  logistics: number
  gross_profit: number
  brand_adp: number
  sales: number
  db1: number
  rd: number
  ga: number
  ebit: number
  ebit_margin_pct: number
}

interface Props {
  data: WaterfallData | null
  loading: boolean
}

/** Build Recharts waterfall rows: invisible spacer + visible delta */
function buildWaterfallRows(d: WaterfallData) {
  const sym = DEMO_CONFIG.company.currencySymbol
  const rows: { name: string; spacer: number; value: number; type: "positive" | "negative" | "subtotal" }[] = []

  const add = (name: string, spacer: number, value: number, type: "positive" | "negative" | "subtotal") =>
    rows.push({ name, spacer, value, type })

  add("Gross Revenue", 0, d.gross_rev, "subtotal")
  add("Trade Spend",   d.net_rev + d.returns_d, d.trade_spend, "negative")
  add("Returns",       d.net_rev, d.returns_d, "negative")
  add("Net Revenue",   0, d.net_rev, "subtotal")
  add("COGS",          d.gross_profit + d.logistics, d.cogs, "negative")
  add("Logistics",     d.gross_profit, d.logistics, "negative")
  add("Gross Profit",  0, d.gross_profit, "subtotal")
  add("Brand A&P",     d.db1 + d.sales, d.brand_adp, "negative")
  add("Sales",         d.db1, d.sales, "negative")
  add("DB1",           0, d.db1, "subtotal")
  add("R&D",           d.ebit + d.ga, d.rd, "negative")
  add("G&A",           d.ebit, d.ga, "negative")
  add("EBIT",          0, d.ebit, "positive")

  return rows
}

const COLORS = {
  positive:  "#10b981", // emerald
  negative:  "#ef4444", // red
  subtotal:  "#6366f1", // indigo
  spacer:    "transparent",
}

function fmtM(v: number) {
  return `€ ${new Intl.NumberFormat("en-US").format(Math.round(v))}M`
}

export function PnLWaterfall({ data, loading }: Props) {
  if (loading) return <div className="h-96 flex items-center justify-center text-muted-foreground text-sm">Loading…</div>
  if (!data) return <div className="h-96 flex items-center justify-center text-muted-foreground text-sm">No data</div>

  const rows = buildWaterfallRows(data)

  return (
    <div>
      <div className="flex items-center justify-between mb-3">
        <h2 className="text-sm font-semibold">P&amp;L Waterfall</h2>
        <div className="flex gap-4 text-xs text-muted-foreground">
          <span className="flex items-center gap-1"><span className="inline-block w-2 h-2 rounded-sm bg-indigo-500" /> Subtotal</span>
          <span className="flex items-center gap-1"><span className="inline-block w-2 h-2 rounded-sm bg-red-500" /> Cost</span>
          <span className="flex items-center gap-1"><span className="inline-block w-2 h-2 rounded-sm bg-emerald-500" /> EBIT</span>
        </div>
      </div>
      <ResponsiveContainer width="100%" height={380}>
        <ComposedChart data={rows} layout="horizontal" margin={{ top: 4, right: 16, left: 16, bottom: 60 }}>
          <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="var(--border)" />
          <XAxis
            dataKey="name"
            tick={{ fontSize: 11 }}
            angle={-35}
            textAnchor="end"
            interval={0}
          />
          <YAxis
            tickFormatter={(v) => `€${(v / 1000).toFixed(0)}B`}
            tick={{ fontSize: 11 }}
            width={52}
          />
          <Tooltip
            formatter={(value: number, _name: string, entry: any) => {
              if (entry.dataKey === "spacer") return null
              return [fmtM(value), "EUR M"]
            }}
            labelStyle={{ fontWeight: 600 }}
            contentStyle={{ border: "1px solid var(--border)", borderRadius: 6, fontSize: 12 }}
          />
          {/* Invisible spacer bar */}
          <Bar dataKey="spacer" stackId="wf" fill="transparent" isAnimationActive={false} />
          {/* Visible value bar */}
          <Bar dataKey="value" stackId="wf" radius={[2, 2, 0, 0]} isAnimationActive={false}>
            {rows.map((row, i) => (
              <Cell key={i} fill={COLORS[row.type]} />
            ))}
          </Bar>
        </ComposedChart>
      </ResponsiveContainer>
    </div>
  )
}
