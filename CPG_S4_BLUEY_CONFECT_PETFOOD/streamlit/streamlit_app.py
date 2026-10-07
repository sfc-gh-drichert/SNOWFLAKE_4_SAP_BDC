"""
Confect PetFood — Supply Risk Command Center
Streamlit-in-Snowflake dashboard for supply chain risk intelligence.
"""

import streamlit as st
import pandas as pd
import altair as alt

st.set_page_config(page_title="Supply Risk Command Center", layout="wide")

# -- Snowflake connection (works in SiS and locally) --
import os
conn = st.connection(
    "snowflake",
    account=os.getenv("SNOWFLAKE_ACCOUNT"),
)

DB_SCHEMA = "CONFECT_PETFOOD_DEMO.SC_RISK_DEMO"


def run_query(sql: str) -> pd.DataFrame:
    return conn.query(sql)


# ── colour palette ──
RISK_COLORS = {
    "CRITICAL": "#d32f2f",
    "HIGH": "#f57c00",
    "MODERATE": "#fbc02d",
    "MEDIUM": "#fbc02d",
    "LOW": "#388e3c",
}
DIVISION_COLORS = {
    "CONFECTIONERY": "#7b1fa2",
    "PETCARE": "#1976d2",
    "FOOD": "#388e3c",
}

# ── sidebar navigation ──
PAGES = [
    "Supply Risk Command Center",
    "SAP BDC Zero Copy",
    "Blue Yonder Planning",
    "External Signals",
    "Risk Command Center",
]
page = st.sidebar.radio("Navigation", PAGES)

# ===================================================================
# PAGE 1 — Landing
# ===================================================================
if page == "Supply Risk Command Center":
    st.title("Supply Risk Command Center")
    st.caption("Confect PetFood — Multi-source risk intelligence powered by Snowflake")

    # KPI metrics
    risk_df = run_query(f"""
        SELECT
            SUM(REVENUE_AT_RISK_USD)                         AS total_rev_risk,
            COUNT(CASE WHEN RISK_TIER IN ('CRITICAL','HIGH') THEN 1 END) AS high_critical_skus,
            COUNT(DISTINCT AT_RISK_SUPPLIERS) - 1            AS suppliers_at_risk
        FROM {DB_SCHEMA}.V_SUPPLY_RISK_SCORE
        WHERE RISK_TIER IN ('CRITICAL','HIGH','MODERATE')
    """)
    alerts_df = run_query(f"""
        SELECT COUNT(*) AS cnt FROM {DB_SCHEMA}.EXT_OUTBREAK_ALERTS WHERE STATUS = 'ACTIVE'
    """)

    c1, c2, c3, c4 = st.columns(4)
    rev_risk = risk_df["TOTAL_REV_RISK"].iloc[0] or 0
    c1.metric("Revenue at Risk", f"${rev_risk:,.0f}")
    c2.metric("High / Critical SKUs", int(risk_df["HIGH_CRITICAL_SKUS"].iloc[0] or 0))
    c3.metric("Active Disruptions", int(alerts_df["CNT"].iloc[0] or 0))
    c4.metric("Suppliers at Risk", int(risk_df["SUPPLIERS_AT_RISK"].iloc[0] or 0))

    st.divider()

    # Data-source cards
    st.subheader("Data Sources Fused in Snowflake")
    s1, s2, s3 = st.columns(3)

    with s1:
        counts = run_query(f"""
            SELECT
                (SELECT COUNT(*) FROM {DB_SCHEMA}.I_PRODUCT)     AS products,
                (SELECT COUNT(*) FROM {DB_SCHEMA}.I_SUPPLIER)    AS suppliers,
                (SELECT COUNT(*) FROM {DB_SCHEMA}.I_BILLOFMATERIALITEM) AS bom_items,
                (SELECT COUNT(*) FROM {DB_SCHEMA}.M_V_POH_AGGR)  AS pos,
                (SELECT SUM(NET_VALUE_USD) FROM {DB_SCHEMA}.M_V_POH_AGGR WHERE GR_DATE IS NULL) AS open_po_val
        """)
        st.markdown("#### SAP BDC")
        st.markdown(f"""
        - **{int(counts['PRODUCTS'].iloc[0])}** Products
        - **{int(counts['SUPPLIERS'].iloc[0])}** Suppliers
        - **{int(counts['BOM_ITEMS'].iloc[0])}** BOM Components
        - **{int(counts['POS'].iloc[0])}** Purchase Orders
        - **${counts['OPEN_PO_VAL'].iloc[0]:,.0f}** Open PO Value
        """)

    with s2:
        by_counts = run_query(f"""
            SELECT
                (SELECT COUNT(*) FROM {DB_SCHEMA}.BY_DEMAND_FORECAST)  AS forecasts,
                (SELECT COUNT(*) FROM {DB_SCHEMA}.BY_LOADS)            AS loads,
                (SELECT COUNT(*) FROM {DB_SCHEMA}.BY_CONSENSUS_PLAN)   AS plans,
                (SELECT COUNT(*) FROM {DB_SCHEMA}.BY_TENDER_EVENTS)    AS tenders
        """)
        st.markdown("#### Blue Yonder")
        st.markdown(f"""
        - **{int(by_counts['FORECASTS'].iloc[0])}** Forecast Records
        - **{int(by_counts['LOADS'].iloc[0])}** Shipment Loads
        - **{int(by_counts['PLANS'].iloc[0])}** Consensus Plans
        - **{int(by_counts['TENDERS'].iloc[0])}** Tender Events
        """)

    with s3:
        ext_counts = run_query(f"""
            SELECT
                (SELECT COUNT(DISTINCT COMMODITY) FROM {DB_SCHEMA}.EXT_COMMODITY_PRICES)  AS commodities,
                (SELECT COUNT(DISTINCT PORT_CODE) FROM {DB_SCHEMA}.EXT_PORT_CONGESTION)   AS ports,
                (SELECT COUNT(*) FROM {DB_SCHEMA}.EXT_OUTBREAK_ALERTS WHERE STATUS='ACTIVE') AS alerts,
                (SELECT COUNT(*) FROM {DB_SCHEMA}.EXT_NEWS_RISK_EVENTS)                   AS news_events
        """)
        st.markdown("#### External Signals")
        st.markdown(f"""
        - **{int(ext_counts['COMMODITIES'].iloc[0])}** Commodity Feeds
        - **{int(ext_counts['PORTS'].iloc[0])}** Ports Monitored
        - **{int(ext_counts['ALERTS'].iloc[0])}** Active Biosecurity Alerts
        - **{int(ext_counts['NEWS_EVENTS'].iloc[0])}** News Risk Events
        """)

    st.divider()

    # Fusion diagram
    st.subheader("Data Fusion Architecture")
    st.markdown("""
    ```
    ┌──────────────┐   ┌──────────────────┐   ┌────────────────────┐
    │  SAP S/4HANA │   │  Blue Yonder     │   │  External Signals  │
    │  via BDC     │   │  IBP + TMS       │   │  Market / Geo      │
    │              │   │                  │   │                    │
    │ • Products   │   │ • Demand Forecast│   │ • Commodity Prices │
    │ • Suppliers  │   │ • Consensus Plan │   │ • Port Congestion  │
    │ • BOMs       │   │ • Loads / Lanes  │   │ • Outbreak Alerts  │
    │ • POs        │   │ • Tender Events  │   │ • News & Risk      │
    │ • Stock      │   │                  │   │ • Vessel Tracker   │
    └──────┬───────┘   └────────┬─────────┘   └─────────┬──────────┘
           │                    │                        │
           └────────────────────┼────────────────────────┘
                                │
                    ┌───────────▼───────────┐
                    │      Snowflake        │
                    │   Iceberg Tables +    │
                    │   Analytic Views      │
                    │                       │
                    │  COMPOSITE RISK SCORE │
                    │  = Supplier   × 30%   │
                    │  + Transport  × 25%   │
                    │  + Coverage   × 25%   │
                    │  + External   × 10%   │
                    │  + Commodity  × 10%   │
                    └───────────────────────┘
    ```
    """)


# ===================================================================
# PAGE 2 — SAP BDC Zero Copy
# ===================================================================
elif page == "SAP BDC Zero Copy":
    st.title("SAP BDC Zero Copy")
    st.caption("Product, supplier, inventory and procurement data from SAP S/4HANA via BDC")

    # Metric row
    m = run_query(f"""
        SELECT
            (SELECT COUNT(*)            FROM {DB_SCHEMA}.I_PRODUCT)        AS products,
            (SELECT COUNT(*)            FROM {DB_SCHEMA}.I_SUPPLIER WHERE IS_ACTIVE=TRUE) AS suppliers,
            (SELECT COUNT(*)            FROM {DB_SCHEMA}.I_BILLOFMATERIALITEM)             AS bom_items,
            (SELECT COUNT(*)            FROM {DB_SCHEMA}.M_V_POH_AGGR)                     AS pos,
            (SELECT COALESCE(SUM(NET_VALUE_USD),0) FROM {DB_SCHEMA}.M_V_POH_AGGR WHERE GR_DATE IS NULL) AS open_po_val
    """)
    mc1, mc2, mc3, mc4, mc5 = st.columns(5)
    mc1.metric("Products", int(m["PRODUCTS"].iloc[0]))
    mc2.metric("Suppliers", int(m["SUPPLIERS"].iloc[0]))
    mc3.metric("BOM Components", int(m["BOM_ITEMS"].iloc[0]))
    mc4.metric("Purchase Orders", int(m["POS"].iloc[0]))
    mc5.metric("Open PO Value", f"${m['OPEN_PO_VAL'].iloc[0]:,.0f}")

    st.divider()
    tab1, tab2, tab3, tab4 = st.tabs(["Products", "Suppliers", "Inventory & Coverage", "Purchase Orders"])

    with tab1:
        prods = run_query(f"SELECT MATERIAL_ID, MATERIAL_DESC, DIVISION, BRAND, CATEGORY, CRITICALITY, UNIT_WHOLESALE_USD FROM {DB_SCHEMA}.I_PRODUCT ORDER BY DIVISION, BRAND")

        col_chart, col_tbl = st.columns([1, 2])
        with col_chart:
            div_counts = prods.groupby("DIVISION").size().reset_index(name="COUNT")
            pie = alt.Chart(div_counts).mark_arc(innerRadius=40).encode(
                theta=alt.Theta("COUNT:Q"),
                color=alt.Color("DIVISION:N", scale=alt.Scale(
                    domain=list(DIVISION_COLORS.keys()),
                    range=list(DIVISION_COLORS.values())
                )),
                tooltip=["DIVISION", "COUNT"],
            ).properties(title="Products by Division", height=280)
            st.altair_chart(pie, use_container_width=True)

        with col_tbl:
            brand_summary = prods.groupby(["DIVISION", "BRAND"]).agg(
                SKUs=("MATERIAL_ID", "count"),
                Avg_Price=("UNIT_WHOLESALE_USD", "mean"),
            ).reset_index().sort_values(["DIVISION", "BRAND"])
            brand_summary["Avg_Price"] = brand_summary["Avg_Price"].map("${:,.2f}".format)
            st.dataframe(brand_summary, use_container_width=True, hide_index=True)

    with tab2:
        suppliers = run_query(f"""
            SELECT SUPPLIER_ID, SUPPLIER_NAME, COUNTRY, REGION, SUPPLIER_TYPE,
                   CREDIT_RATING, IS_SOLE_SOURCE, CONTRACT_END
            FROM {DB_SCHEMA}.I_SUPPLIER WHERE IS_ACTIVE=TRUE
            ORDER BY CREDIT_RATING DESC, SUPPLIER_NAME
        """)
        st.dataframe(suppliers, use_container_width=True, hide_index=True)

    with tab3:
        inv = run_query(f"""
            SELECT s.MATERIAL_ID, p.MATERIAL_DESC, s.PLANT, pp.PLANT_NAME,
                   s.UNRESTRICTED_STOCK, s.DAYS_OF_SUPPLY, s.DAILY_CONSUMPTION,
                   pp.SAFETY_STOCK_DAYS,
                   (pp.SAFETY_STOCK_DAYS - s.DAYS_OF_SUPPLY) AS GAP_DAYS
            FROM {DB_SCHEMA}.PPH_DDL_STOCK_1 s
            JOIN {DB_SCHEMA}.I_PRODUCT p ON p.MATERIAL_ID = s.MATERIAL_ID
            JOIN {DB_SCHEMA}.I_PRODUCTPLANT pp ON pp.MATERIAL_ID = s.MATERIAL_ID AND pp.PLANT = s.PLANT
            ORDER BY GAP_DAYS DESC
        """)
        chart_data = inv[["MATERIAL_ID", "DAYS_OF_SUPPLY", "SAFETY_STOCK_DAYS"]].head(15).melt(
            id_vars="MATERIAL_ID", var_name="Metric", value_name="Days"
        )
        bar = alt.Chart(chart_data).mark_bar().encode(
            x=alt.X("MATERIAL_ID:N", sort="-y", title="Material"),
            y=alt.Y("Days:Q"),
            color=alt.Color("Metric:N", scale=alt.Scale(
                domain=["DAYS_OF_SUPPLY", "SAFETY_STOCK_DAYS"],
                range=["#1976d2", "#d32f2f"]
            )),
            xOffset="Metric:N",
            tooltip=["MATERIAL_ID", "Metric", "Days"],
        ).properties(title="Days of Supply vs Safety Stock (top 15 gap)", height=320)
        st.altair_chart(bar, use_container_width=True)
        st.dataframe(inv, use_container_width=True, hide_index=True)

    with tab4:
        pos = run_query(f"""
            SELECT PO_NUMBER, MATERIAL_ID, SUPPLIER_ID, PO_QTY, NET_VALUE_USD,
                   PO_STATUS, DELIVERY_DATE, GR_DATE
            FROM {DB_SCHEMA}.M_V_POH_AGGR
            ORDER BY DELIVERY_DATE DESC
        """)
        st.dataframe(pos, use_container_width=True, hide_index=True)


# ===================================================================
# PAGE 3 — Blue Yonder Planning
# ===================================================================
elif page == "Blue Yonder Planning":
    st.title("Blue Yonder Planning")
    st.caption("Demand forecasts, consensus plans and transport execution from Blue Yonder IBP & TMS")

    tab_d, tab_t, tab_p = st.tabs(["Demand & Consensus Plan", "Transport Execution", "Plan Overview"])

    with tab_d:
        # KPI row
        peak_kpi = run_query(f"""
            SELECT
                COUNT(DISTINCT PEAK_EVENT)     AS peak_events,
                SUM(FORECAST_QTY)              AS peak_forecast_units,
                ROUND(AVG(SEASONAL_LIFT_PCT),1) AS avg_lift
            FROM {DB_SCHEMA}.BY_DEMAND_FORECAST
            WHERE IS_PEAK_WEEK = TRUE
        """)
        k1, k2, k3 = st.columns(3)
        k1.metric("Peak Events", int(peak_kpi["PEAK_EVENTS"].iloc[0]))
        k2.metric("Peak Forecast Units", f"{int(peak_kpi['PEAK_FORECAST_UNITS'].iloc[0]):,}")
        k3.metric("Avg Seasonal Lift", f"{peak_kpi['AVG_LIFT'].iloc[0]}%")

        st.divider()

        # Peak event selector
        events = run_query(f"SELECT DISTINCT PEAK_EVENT FROM {DB_SCHEMA}.BY_DEMAND_FORECAST WHERE PEAK_EVENT IS NOT NULL ORDER BY 1")
        selected_event = st.selectbox("Peak Event", ["ALL"] + events["PEAK_EVENT"].tolist())

        where_clause = ""
        if selected_event != "ALL":
            where_clause = f"AND (PEAK_EVENT = '{selected_event}' OR PEAK_EVENT IS NULL)"

        # Weekly forecast curve
        weekly = run_query(f"""
            SELECT WEEK_START,
                   SUM(FORECAST_QTY)  AS FORECAST,
                   SUM(BASELINE_QTY)  AS BASELINE
            FROM {DB_SCHEMA}.BY_DEMAND_FORECAST
            WHERE 1=1 {where_clause}
            GROUP BY WEEK_START ORDER BY WEEK_START
        """)
        melted = weekly.melt(id_vars="WEEK_START", var_name="Series", value_name="Quantity")
        line = alt.Chart(melted).mark_line(point=True).encode(
            x=alt.X("WEEK_START:T", title="Week"),
            y=alt.Y("Quantity:Q", title="Units"),
            color=alt.Color("Series:N", scale=alt.Scale(
                domain=["FORECAST", "BASELINE"],
                range=["#1976d2", "#9e9e9e"]
            )),
            tooltip=["WEEK_START:T", "Series:N", "Quantity:Q"],
        ).properties(title="Weekly Demand: Forecast vs Baseline", height=360)
        st.altair_chart(line, use_container_width=True)

        # Baseline vs Forecast by material (peak weeks)
        mat_compare = run_query(f"""
            SELECT MATERIAL_ID,
                   SUM(BASELINE_QTY) AS BASELINE, SUM(FORECAST_QTY) AS FORECAST
            FROM {DB_SCHEMA}.BY_DEMAND_FORECAST
            WHERE IS_PEAK_WEEK = TRUE {where_clause}
            GROUP BY MATERIAL_ID ORDER BY FORECAST DESC
        """)
        if not mat_compare.empty:
            mc_melt = mat_compare.melt(id_vars="MATERIAL_ID", var_name="Type", value_name="Qty")
            bar_comp = alt.Chart(mc_melt).mark_bar().encode(
                x=alt.X("MATERIAL_ID:N", sort="-y", title="Material"),
                y=alt.Y("Qty:Q", title="Units"),
                color=alt.Color("Type:N", scale=alt.Scale(
                    domain=["BASELINE", "FORECAST"],
                    range=["#9e9e9e", "#1976d2"]
                )),
                xOffset="Type:N",
                tooltip=["MATERIAL_ID", "Type", "Qty"],
            ).properties(title="Peak Weeks: Baseline vs Forecast by Material", height=320)
            st.altair_chart(bar_comp, use_container_width=True)

    with tab_t:
        st.subheader("Load Status Breakdown")
        loads = run_query(f"""
            SELECT LOAD_STATUS, COUNT(*) AS CNT
            FROM {DB_SCHEMA}.BY_LOADS
            GROUP BY LOAD_STATUS ORDER BY CNT DESC
        """)
        load_bar = alt.Chart(loads).mark_bar().encode(
            x=alt.X("LOAD_STATUS:N", sort="-y"),
            y=alt.Y("CNT:Q", title="Loads"),
            color=alt.Color("LOAD_STATUS:N", legend=None),
            tooltip=["LOAD_STATUS", "CNT"],
        ).properties(height=280)
        st.altair_chart(load_bar, use_container_width=True)

        st.subheader("Tender Response Breakdown")
        tenders = run_query(f"""
            SELECT RESPONSE_TYPE, COUNT(*) AS CNT
            FROM {DB_SCHEMA}.BY_TENDER_EVENTS
            GROUP BY RESPONSE_TYPE ORDER BY CNT DESC
        """)
        tender_bar = alt.Chart(tenders).mark_bar().encode(
            x=alt.X("RESPONSE_TYPE:N", sort="-y"),
            y=alt.Y("CNT:Q", title="Events"),
            color=alt.Color("RESPONSE_TYPE:N", legend=None),
            tooltip=["RESPONSE_TYPE", "CNT"],
        ).properties(height=280)
        st.altair_chart(tender_bar, use_container_width=True)

        st.subheader("All Loads")
        all_loads = run_query(f"""
            SELECT LOAD_ID, LANE_ID, RELATED_PO, CARRIER_ID,
                   SHIP_DATE, DELIVERY_DATE, LOAD_STATUS, ON_TIME_FLAG
            FROM {DB_SCHEMA}.BY_LOADS ORDER BY SHIP_DATE DESC
        """)
        st.dataframe(all_loads, use_container_width=True, hide_index=True)

    with tab_p:
        st.subheader("Consensus Plans (S&OP)")
        plans = run_query(f"""
            SELECT cp.MATERIAL_ID, p.MATERIAL_DESC, p.DIVISION, p.BRAND,
                   cp.PLAN_VERSION, cp.COMMITTED_QTY, cp.REVENUE_PLAN_USD, cp.PLAN_CONFIDENCE
            FROM {DB_SCHEMA}.BY_CONSENSUS_PLAN cp
            JOIN {DB_SCHEMA}.I_PRODUCT p ON p.MATERIAL_ID = cp.MATERIAL_ID
            ORDER BY cp.REVENUE_PLAN_USD DESC
        """)
        st.dataframe(plans, use_container_width=True, hide_index=True)


# ===================================================================
# PAGE 4 — External Signals
# ===================================================================
elif page == "External Signals":
    st.title("External Signals")
    st.caption("Real-time market, geopolitical and biosecurity intelligence")

    # Active biosecurity alerts
    alerts = run_query(f"""
        SELECT ALERT_ID, DISEASE_NAME, COUNTRY, REGION, RISK_LEVEL, STATUS,
               AFFECTED_SPECIES, DISCOVERY_DATE, LAST_UPDATED
        FROM {DB_SCHEMA}.EXT_OUTBREAK_ALERTS
        WHERE STATUS = 'ACTIVE'
        ORDER BY RISK_LEVEL DESC
    """)
    if not alerts.empty:
        st.subheader(f"Active Biosecurity Alerts ({len(alerts)})")
        for _, row in alerts.iterrows():
            color = RISK_COLORS.get(row["RISK_LEVEL"], "#757575")
            st.markdown(
                f"""<div style="border-left: 4px solid {color}; padding: 8px 12px; margin-bottom: 8px; background: rgba(0,0,0,0.03); border-radius: 4px;">
                <strong>{row['DISEASE_NAME']}</strong> — {row['COUNTRY']}, {row['REGION']}<br/>
                <span style="color:{color}; font-weight:bold;">⚠ {row['RISK_LEVEL']}</span> &nbsp;|&nbsp;
                Species: {row['AFFECTED_SPECIES']} &nbsp;|&nbsp; Since: {row['DISCOVERY_DATE']}
                </div>""",
                unsafe_allow_html=True,
            )
    else:
        st.success("No active biosecurity alerts.")

    st.divider()
    tab_c, tab_n, tab_pv = st.tabs(["Commodity Prices", "News & Risk Events", "Ports & Vessels"])

    with tab_c:
        commodities = run_query(f"SELECT DISTINCT COMMODITY FROM {DB_SCHEMA}.EXT_COMMODITY_PRICES ORDER BY 1")
        selected_commodities = st.multiselect(
            "Commodities", commodities["COMMODITY"].tolist(),
            default=commodities["COMMODITY"].tolist()[:3],
        )
        if selected_commodities:
            in_list = ",".join([f"'{c}'" for c in selected_commodities])
            prices = run_query(f"""
                SELECT PRICE_DATE, COMMODITY, SPOT_PRICE, SUPPLY_TIGHTNESS, YOY_CHANGE_PCT
                FROM {DB_SCHEMA}.EXT_COMMODITY_PRICES
                WHERE COMMODITY IN ({in_list})
                ORDER BY PRICE_DATE
            """)
            price_line = alt.Chart(prices).mark_line().encode(
                x=alt.X("PRICE_DATE:T", title="Date"),
                y=alt.Y("SPOT_PRICE:Q", title="Spot Price"),
                color="COMMODITY:N",
                tooltip=["PRICE_DATE:T", "COMMODITY:N", "SPOT_PRICE:Q", "SUPPLY_TIGHTNESS:N"],
            ).properties(title="Commodity Spot Prices (90 days)", height=350)
            st.altair_chart(price_line, use_container_width=True)

            latest = run_query(f"""
                SELECT COMMODITY, SPOT_PRICE, PRICE_UNIT, SUPPLY_TIGHTNESS, YOY_CHANGE_PCT
                FROM {DB_SCHEMA}.EXT_COMMODITY_PRICES
                WHERE PRICE_DATE = (SELECT MAX(PRICE_DATE) FROM {DB_SCHEMA}.EXT_COMMODITY_PRICES)
                  AND COMMODITY IN ({in_list})
                ORDER BY COMMODITY
            """)
            st.dataframe(latest, use_container_width=True, hide_index=True)

    with tab_n:
        news = run_query(f"""
            SELECT EVENT_DATE, HEADLINE, RISK_CATEGORY, SEVERITY, SOURCE,
                   RELATED_SUPPLIER, RELATED_COMMODITY
            FROM {DB_SCHEMA}.EXT_NEWS_RISK_EVENTS
            ORDER BY EVENT_DATE DESC
        """)
        st.dataframe(news, use_container_width=True, hide_index=True)

    with tab_pv:
        col_port, col_vessel = st.columns(2)
        with col_port:
            st.subheader("Port Congestion (latest)")
            ports = run_query(f"""
                SELECT PORT_CODE, PORT_NAME, COUNTRY, CONGESTION_SCORE,
                       AVG_WAIT_HOURS, VESSELS_AT_ANCHOR, ALERT_LEVEL
                FROM {DB_SCHEMA}.EXT_PORT_CONGESTION
                WHERE REPORT_DATE = (SELECT MAX(REPORT_DATE) FROM {DB_SCHEMA}.EXT_PORT_CONGESTION)
                ORDER BY CONGESTION_SCORE DESC
            """)
            st.dataframe(ports, use_container_width=True, hide_index=True)

        with col_vessel:
            st.subheader("Vessel Tracker")
            vessels = run_query(f"""
                SELECT VESSEL_NAME, VESSEL_TYPE, CARGO_TYPE,
                       DEPARTURE_PORT, DESTINATION_PORT,
                       ORIGINAL_ETA, REVISED_ETA, DELAY_DAYS, CURRENT_STATUS
                FROM {DB_SCHEMA}.EXT_VESSEL_TRACKER
                ORDER BY DELAY_DAYS DESC
            """)
            st.dataframe(vessels, use_container_width=True, hide_index=True)


# ===================================================================
# PAGE 5 — Risk Command Center
# ===================================================================
elif page == "Risk Command Center":
    st.title("Risk Command Center")
    st.caption("Composite risk scoring across all data layers")

    risk = run_query(f"""
        SELECT MATERIAL_ID, MATERIAL_DESC, DIVISION, BRAND, PLANT, PEAK_EVENT,
               COMPOSITE_RISK_SCORE, RISK_TIER,
               AT_RISK_SUPPLIERS, BIOSECURITY_ALERT,
               SUPPLY_SHORTFALL_QTY, REVENUE_AT_RISK_USD,
               DAYS_OF_SUPPLY, SAFETY_STOCK_DAYS,
               DISRUPTED_LOAD_COUNT, COMMODITY_YOY_CHANGE_PCT
        FROM {DB_SCHEMA}.V_SUPPLY_RISK_SCORE
        ORDER BY COMPOSITE_RISK_SCORE DESC
    """)

    # Risk leaderboard
    st.subheader("Risk Leaderboard")
    top20 = risk.head(20).copy()
    top20["label"] = top20["MATERIAL_ID"] + " — " + top20["MATERIAL_DESC"].str[:30]
    leaderboard = alt.Chart(top20).mark_bar().encode(
        y=alt.Y("label:N", sort="-x", title=""),
        x=alt.X("COMPOSITE_RISK_SCORE:Q", title="Composite Risk Score"),
        color=alt.Color("RISK_TIER:N", scale=alt.Scale(
            domain=list(RISK_COLORS.keys()),
            range=list(RISK_COLORS.values())
        )),
        tooltip=["MATERIAL_ID", "MATERIAL_DESC", "COMPOSITE_RISK_SCORE", "RISK_TIER"],
    ).properties(height=max(400, len(top20) * 24))
    st.altair_chart(leaderboard, use_container_width=True)

    st.divider()
    col_tier, col_div = st.columns(2)

    with col_tier:
        st.subheader("Risk Tier Distribution")
        tier_dist = risk.groupby("RISK_TIER").size().reset_index(name="COUNT")
        donut = alt.Chart(tier_dist).mark_arc(innerRadius=50).encode(
            theta=alt.Theta("COUNT:Q"),
            color=alt.Color("RISK_TIER:N", scale=alt.Scale(
                domain=list(RISK_COLORS.keys()),
                range=list(RISK_COLORS.values())
            )),
            tooltip=["RISK_TIER", "COUNT"],
        ).properties(height=300)
        st.altair_chart(donut, use_container_width=True)

    with col_div:
        st.subheader("Revenue at Risk by Division")
        div_risk = risk.groupby("DIVISION")["REVENUE_AT_RISK_USD"].sum().reset_index()
        div_risk = div_risk.sort_values("REVENUE_AT_RISK_USD", ascending=True)
        hbar = alt.Chart(div_risk).mark_bar().encode(
            y=alt.Y("DIVISION:N", sort="-x", title=""),
            x=alt.X("REVENUE_AT_RISK_USD:Q", title="Revenue at Risk ($)"),
            color=alt.Color("DIVISION:N", scale=alt.Scale(
                domain=list(DIVISION_COLORS.keys()),
                range=list(DIVISION_COLORS.values())
            ), legend=None),
            tooltip=["DIVISION", alt.Tooltip("REVENUE_AT_RISK_USD:Q", format="$,.0f")],
        ).properties(height=200)
        st.altair_chart(hbar, use_container_width=True)

    # Drill-down
    st.divider()
    st.subheader("Material Drill-Down")
    material_options = risk["MATERIAL_ID"].tolist()
    selected_material = st.selectbox("Select Material", material_options)

    if selected_material:
        row = risk[risk["MATERIAL_ID"] == selected_material].iloc[0]
        d1, d2, d3, d4, d5 = st.columns(5)
        d1.metric("Composite Score", f"{row['COMPOSITE_RISK_SCORE']:.1f}")
        d2.metric("Risk Tier", row["RISK_TIER"])
        d3.metric("Revenue at Risk", f"${row['REVENUE_AT_RISK_USD']:,.0f}")
        d4.metric("Days of Supply", int(row["DAYS_OF_SUPPLY"]))
        d5.metric("Safety Target", int(row["SAFETY_STOCK_DAYS"]))

        st.markdown(f"""
        | Field | Value |
        |-------|-------|
        | **Material** | {row['MATERIAL_ID']} — {row['MATERIAL_DESC']} |
        | **Division / Brand** | {row['DIVISION']} / {row['BRAND']} |
        | **Plant** | {row['PLANT']} |
        | **Peak Event** | {row['PEAK_EVENT'] or 'N/A'} |
        | **At-Risk Suppliers** | {row['AT_RISK_SUPPLIERS']} |
        | **Biosecurity Alert** | {row['BIOSECURITY_ALERT']} |
        | **Supply Shortfall** | {int(row['SUPPLY_SHORTFALL_QTY']):,} units |
        | **Disrupted Loads** | {int(row['DISRUPTED_LOAD_COUNT'])} |
        | **Commodity YoY Change** | {row['COMMODITY_YOY_CHANGE_PCT']:.1f}% |
        """)
