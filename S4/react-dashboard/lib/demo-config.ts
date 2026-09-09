/**
 * demo-config.ts — Customer-specific configuration.
 *
 * TO REBRAND FOR A NEW CUSTOMER:
 *   1. Change company.name, shortName, tagline, primaryColor, accentColor, currency
 *   2. Change snowflake.agentFqn to point at the new account's agent
 *   3. Update starterQuestions to match the new dataset
 *
 * All other code reads from this file — nothing else needs to change.
 */

export const DEMO_CONFIG = {
  company: {
    name:           "BSH Group",
    shortName:      "BSH",
    tagline:        "Europe's largest home appliance manufacturer",
    primaryColor:   "#003087",   // BSH dark blue — change for new customer
    accentColor:    "#E30613",   // BSH red
    currency:       "EUR",
    currencySymbol: "€",
  },

  snowflake: {
    /** Fully-qualified agent name — override with NEXT_PUBLIC_SF_AGENT env var */
    agentFqn: process.env.NEXT_PUBLIC_SF_AGENT ?? "S4.FIN.BSH_PNL_AGENT",
    /** Database holding the PnL fact table */
    database: process.env.NEXT_PUBLIC_SF_DATABASE ?? "S4",
    schema:   "FIN",
    table:    "S3_FINANCE_PNL",
  },

  filters: {
    years:   [0, 2023, 2024, 2025, 2026] as const,  // 0 = All years
    yearLabels: new Map([
      [0,    "All years"],
      [2023, "2023"],
      [2024, "2024"],
      [2025, "2025"],
      [2026, "2026 (partial)"],
    ]),
    brands:  ["All", "Bosch", "Siemens", "Gaggenau", "NEFF", "Thermador"] as const,
    regions: ["All", "DACH", "W_EUROPE", "E_EUROPE", "N_AMERICA", "APAC", "EMERGING"] as const,
  },

  /** Starter question chips shown below the agent chat input */
  starterQuestions: [
    "Show me the full P&L waterfall for 2025.",
    "Which brand has the highest EBIT margin?",
    "Is the Cooking category recovering in 2025 and 2026?",
    "Why is Gaggenau so much more profitable than Bosch?",
    "Compare EBIT by region — which region leads?",
  ],
} as const

export type Brand   = (typeof DEMO_CONFIG.filters.brands)[number]
export type Region  = (typeof DEMO_CONFIG.filters.regions)[number]
export type FiscalYear = (typeof DEMO_CONFIG.filters.years)[number]

export interface Filters {
  year:   FiscalYear
  brand:  Brand
  region: Region
}
