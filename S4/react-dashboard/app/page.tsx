"use client"

import { useState, useEffect, useCallback } from "react"
import { FilterBar } from "@/components/FilterBar"
import { KPICards } from "@/components/KPICards"
import { PnLWaterfall } from "@/components/PnLWaterfall"
import { BrandMarginChart } from "@/components/BrandMarginChart"
import { CategoryTrends } from "@/components/CategoryTrends"
import { AgentChat } from "@/components/AgentChat"
import { DEMO_CONFIG, type Filters } from "@/lib/demo-config"

const DEFAULT_FILTERS: Filters = { year: 2025, brand: "All", region: "All" }

function qs(f: Filters) {
  return `year=${f.year}&brand=${encodeURIComponent(f.brand)}&region=${encodeURIComponent(f.region)}`
}

function useData<T>(endpoint: string, filterStr: string, initialValue: T) {
  const [data, setData] = useState<T>(initialValue)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let active = true
    setLoading(true)
    fetch(`${endpoint}?${filterStr}`)
      .then((r) => r.json())
      .then((d) => { if (active) { setData(d); setLoading(false) } })
      .catch(() => { if (active) setLoading(false) })
    return () => { active = false }
  }, [endpoint, filterStr])

  return { data, loading }
}

export default function DashboardPage() {
  const [filters, setFilters] = useState<Filters>(DEFAULT_FILTERS)
  const filterStr = qs(filters)
  const waterfallFilterStr = qs(filters)
  const brandFilterStr = `year=${filters.year}&region=${encodeURIComponent(filters.region)}`
  const trendFilterStr = `brand=${encodeURIComponent(filters.brand)}&region=${encodeURIComponent(filters.region)}`

  const kpi       = useData("/api/kpi",              filterStr,       null)
  const waterfall = useData("/api/waterfall",         waterfallFilterStr, null)
  const brands    = useData("/api/brand-margins",     brandFilterStr,  [])
  const trends    = useData("/api/category-trends",   trendFilterStr,  [])

  return (
    <main className="flex flex-col min-h-[calc(100vh-3.5rem)]">
      {/* Header bar */}
      <div className="border-b border-border px-4 py-3 flex flex-wrap items-center justify-between gap-3">
        <div>
          <span className="text-sm font-bold">{DEMO_CONFIG.company.name}</span>
          <span className="ml-2 text-xs text-muted-foreground">{DEMO_CONFIG.company.tagline}</span>
        </div>
        <FilterBar filters={filters} onChange={setFilters} />
      </div>

      {/* Body — charts left (60%), chat right (40%) */}
      <div className="flex flex-1 min-h-0 divide-x divide-border overflow-hidden">

        {/* ── Left panel: KPIs + charts ── */}
        <div className="flex-[3] overflow-y-auto p-4 space-y-6">
          {/* KPI cards */}
          <KPICards data={kpi.data} loading={kpi.loading} />

          {/* P&L Waterfall */}
          <div className="rounded-lg border border-border bg-card p-4">
            <PnLWaterfall data={waterfall.data} loading={waterfall.loading} />
          </div>

          {/* Bottom row: Brand margins + Category trends */}
          <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
            <div className="rounded-lg border border-border bg-card p-4">
              <BrandMarginChart data={brands.data as any} loading={brands.loading} />
            </div>
            <div className="rounded-lg border border-border bg-card p-4">
              <CategoryTrends data={trends.data as any} loading={trends.loading} />
            </div>
          </div>
        </div>

        {/* ── Right panel: Agent chat ── */}
        <div className="flex-[2] flex flex-col p-4 min-h-0 overflow-hidden">
          <AgentChat />
        </div>
      </div>
    </main>
  )
}
