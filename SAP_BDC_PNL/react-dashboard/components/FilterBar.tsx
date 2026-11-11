"use client"

import { DEMO_CONFIG, type Filters, type Brand, type Region, type FiscalYear } from "@/lib/demo-config"

interface FilterBarProps {
  filters: Filters
  onChange: (f: Filters) => void
}

export function FilterBar({ filters, onChange }: FilterBarProps) {
  const select =
    "rounded-md border border-border bg-background px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-ring"

  return (
    <div className="flex flex-wrap gap-3 items-center">
      {/* Year */}
      <div className="flex items-center gap-1.5">
        <label className="text-xs font-medium text-muted-foreground">Year</label>
        <select
          className={select}
          value={filters.year}
          onChange={(e) => onChange({ ...filters, year: parseInt(e.target.value) as FiscalYear })}
        >
          {DEMO_CONFIG.filters.years.map((y) => (
            <option key={y} value={y}>
              {DEMO_CONFIG.filters.yearLabels.get(y)}
            </option>
          ))}
        </select>
      </div>

      {/* Brand */}
      <div className="flex items-center gap-1.5">
        <label className="text-xs font-medium text-muted-foreground">Brand</label>
        <select
          className={select}
          value={filters.brand}
          onChange={(e) => onChange({ ...filters, brand: e.target.value as Brand })}
        >
          {DEMO_CONFIG.filters.brands.map((b) => (
            <option key={b} value={b}>{b}</option>
          ))}
        </select>
      </div>

      {/* Region */}
      <div className="flex items-center gap-1.5">
        <label className="text-xs font-medium text-muted-foreground">Region</label>
        <select
          className={select}
          value={filters.region}
          onChange={(e) => onChange({ ...filters, region: e.target.value as Region })}
        >
          {DEMO_CONFIG.filters.regions.map((r) => (
            <option key={r} value={r}>{r.replace(/_/g, " ")}</option>
          ))}
        </select>
      </div>
    </div>
  )
}
