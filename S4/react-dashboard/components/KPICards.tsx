"use client"

import { DEMO_CONFIG } from "@/lib/demo-config"

interface KPIData {
  gross_rev_eur_m: number | null
  net_rev_eur_m: number | null
  ebit_eur_m: number | null
  ebit_margin_pct: number | null
}

interface KPICardsProps {
  data: KPIData | null
  loading: boolean
}

function fmt(n: number | null | undefined, decimals = 0): string {
  if (n == null) return "—"
  return new Intl.NumberFormat("en-US", {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(n)
}

function ebitColor(pct: number | null | undefined): string {
  if (pct == null) return "text-foreground"
  if (pct >= 5) return "text-emerald-600 dark:text-emerald-400"
  if (pct >= 3) return "text-amber-500"
  return "text-red-500"
}

export function KPICards({ data, loading }: KPICardsProps) {
  const sym = DEMO_CONFIG.company.currencySymbol

  const cards = [
    {
      label: "Gross Revenue",
      value: loading ? "…" : `${sym} ${fmt(data?.gross_rev_eur_m)}M`,
      sub: "Before trade discounts and returns",
    },
    {
      label: "Net Revenue",
      value: loading ? "…" : `${sym} ${fmt(data?.net_rev_eur_m)}M`,
      sub: "After trade spend and returns",
    },
    {
      label: "EBIT",
      value: loading ? "…" : `${sym} ${fmt(data?.ebit_eur_m)}M`,
      sub: "Earnings before interest and tax",
      valueClass: ebitColor(data?.ebit_margin_pct),
    },
    {
      label: "EBIT Margin",
      value: loading ? "…" : `${fmt(data?.ebit_margin_pct, 1)}%`,
      sub: "% of net revenue",
      valueClass: ebitColor(data?.ebit_margin_pct),
    },
  ]

  return (
    <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
      {cards.map((c) => (
        <div key={c.label} className="rounded-lg border border-border bg-card p-4">
          <p className="text-xs font-medium text-muted-foreground mb-1">{c.label}</p>
          <p className={`text-2xl font-bold tabular-nums tracking-tight ${c.valueClass ?? ""}`}>
            {c.value}
          </p>
          <p className="text-xs text-muted-foreground mt-1">{c.sub}</p>
        </div>
      ))}
    </div>
  )
}
