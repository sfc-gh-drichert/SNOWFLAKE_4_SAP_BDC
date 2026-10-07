"""
Confect PetFood — Supply Risk Command Center
Streamlit-in-Snowflake dashboard for supply chain risk intelligence.
"""

import streamlit as st
import pandas as pd
import altair as alt

st.set_page_config(page_title="Supply Risk Command Center", layout="wide")

# -- Snowflake connection (container runtime) --
conn = st.connection("snowflake")

DB_SCHEMA = "CONFECT_PETFOOD_DEMO.SC_RISK_DEMO"


def run_query(sql: str) -> pd.DataFrame:
    return conn.query(sql)


# ── styling ──
RISK_COLORS = {"CRITICAL": "#d32f2f", "HIGH": "#f57c00", "MODERATE": "#fbc02d", "MEDIUM": "#fbc02d", "LOW": "#388e3c"}
DIVISION_COLORS = {"CONFECTIONERY": "#7b1fa2", "PETCARE": "#1976d2", "FOOD": "#388e3c"}
SOURCE_COLORS = {"SAP BDC": "#1565c0", "Blue Yonder": "#00897b", "External Signals": "#e65100"}


def kpi_card(label, value, color="#29B5E8"):
    st.markdown(f"""<div style="background:linear-gradient(135deg,{color}22,{color}08);
        border-left:4px solid {color};border-radius:8px;padding:16px 20px;margin-bottom:8px;">
        <div style="font-size:0.85rem;color:#888;margin-bottom:4px;">{label}</div>
        <div style="font-size:1.8rem;font-weight:700;color:{color};">{value}</div>
        </div>""", unsafe_allow_html=True)


def source_card(title, color, items):
    import re
    def md_bold_to_html(s): return re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', s)
    bullet_html = "".join(f"<div style='padding:3px 0;font-size:0.9rem;'>{md_bold_to_html(i)}</div>" for i in items)
    st.markdown(f"""<div style="border:1px solid {color}44;border-top:4px solid {color};
        border-radius:8px;padding:20px;background:{color}06;height:100%;">
        <div style="font-size:1.1rem;font-weight:700;color:{color};margin-bottom:12px;">{title}</div>
        {bullet_html}</div>""", unsafe_allow_html=True)


# ── sidebar ──
st.sidebar.title("Navigation")
PAGES = ["Overview", "SAP BDC Zero Copy", "Blue Yonder Planning", "External Signals", "Risk Command Center"]
page = st.sidebar.radio("", PAGES, label_visibility="collapsed")

# ===================================================================
# PAGE 1 — Overview (Landing)
# ===================================================================
if page == "Overview":
    st.markdown("## Supply Risk Command Center")
    st.caption("Confect PetFood | Multi-source risk intelligence powered by Snowflake")

    risk_df = run_query(f"""
        SELECT SUM(REVENUE_AT_RISK_USD) AS total_rev_risk,
               COUNT(CASE WHEN RISK_TIER IN ('CRITICAL','HIGH') THEN 1 END) AS high_critical_skus,
               COUNT(DISTINCT AT_RISK_SUPPLIERS) - 1 AS suppliers_at_risk
        FROM {DB_SCHEMA}.V_SUPPLY_RISK_SCORE WHERE RISK_TIER IN ('CRITICAL','HIGH','MODERATE')
    """)
    alerts_cnt = run_query(f"SELECT COUNT(*) AS cnt FROM {DB_SCHEMA}.EXT_OUTBREAK_ALERTS WHERE STATUS='ACTIVE'")

    c1, c2, c3, c4 = st.columns(4)
    with c1: kpi_card("Revenue at Risk", f"${(risk_df['TOTAL_REV_RISK'].iloc[0] or 0):,.0f}", "#d32f2f")
    with c2: kpi_card("High / Critical SKUs", int(risk_df["HIGH_CRITICAL_SKUS"].iloc[0] or 0), "#f57c00")
    with c3: kpi_card("Active Disruptions", int(alerts_cnt["CNT"].iloc[0] or 0), "#7b1fa2")
    with c4: kpi_card("Suppliers at Risk", int(risk_df["SUPPLIERS_AT_RISK"].iloc[0] or 0), "#1565c0")

    st.markdown("")

    # Source cards
    st.markdown("### Data Sources")
    counts = run_query(f"""SELECT
        (SELECT COUNT(*) FROM {DB_SCHEMA}.I_PRODUCT) AS products,
        (SELECT COUNT(*) FROM {DB_SCHEMA}.I_SUPPLIER) AS suppliers,
        (SELECT COUNT(*) FROM {DB_SCHEMA}.I_BILLOFMATERIALITEM) AS bom_items,
        (SELECT COUNT(*) FROM {DB_SCHEMA}.M_V_POH_AGGR) AS pos,
        (SELECT COALESCE(SUM(NET_VALUE_USD),0) FROM {DB_SCHEMA}.M_V_POH_AGGR WHERE GR_DATE IS NULL) AS open_po_val,
        (SELECT COUNT(*) FROM {DB_SCHEMA}.BY_DEMAND_FORECAST) AS forecasts,
        (SELECT COUNT(*) FROM {DB_SCHEMA}.BY_LOADS) AS loads,
        (SELECT COUNT(*) FROM {DB_SCHEMA}.BY_CONSENSUS_PLAN) AS plans,
        (SELECT COUNT(*) FROM {DB_SCHEMA}.BY_TENDER_EVENTS) AS tenders,
        (SELECT COUNT(DISTINCT COMMODITY) FROM {DB_SCHEMA}.EXT_COMMODITY_PRICES) AS commodities,
        (SELECT COUNT(DISTINCT PORT_CODE) FROM {DB_SCHEMA}.EXT_PORT_CONGESTION) AS ports,
        (SELECT COUNT(*) FROM {DB_SCHEMA}.EXT_OUTBREAK_ALERTS WHERE STATUS='ACTIVE') AS alerts,
        (SELECT COUNT(*) FROM {DB_SCHEMA}.EXT_NEWS_RISK_EVENTS) AS news_events
    """)
    s1, s2, s3 = st.columns(3)
    with s1:
        source_card("SAP S/4HANA via BDC", SOURCE_COLORS["SAP BDC"], [
            f"**{int(counts['PRODUCTS'].iloc[0])}** Products",
            f"**{int(counts['SUPPLIERS'].iloc[0])}** Suppliers",
            f"**{int(counts['BOM_ITEMS'].iloc[0])}** BOM Components",
            f"**{int(counts['POS'].iloc[0])}** Purchase Orders",
            f"**${counts['OPEN_PO_VAL'].iloc[0]:,.0f}** Open PO Value",
        ])
    with s2:
        source_card("Blue Yonder IBP + TMS", SOURCE_COLORS["Blue Yonder"], [
            f"**{int(counts['FORECASTS'].iloc[0])}** Forecast Records",
            f"**{int(counts['LOADS'].iloc[0])}** Shipment Loads",
            f"**{int(counts['PLANS'].iloc[0])}** Consensus Plans",
            f"**{int(counts['TENDERS'].iloc[0])}** Tender Events",
        ])
    with s3:
        source_card("External Market Signals", SOURCE_COLORS["External Signals"], [
            f"**{int(counts['COMMODITIES'].iloc[0])}** Commodity Feeds",
            f"**{int(counts['PORTS'].iloc[0])}** Ports Monitored",
            f"**{int(counts['ALERTS'].iloc[0])}** Active Biosecurity Alerts",
            f"**{int(counts['NEWS_EVENTS'].iloc[0])}** News Risk Events",
        ])

    st.markdown("")

    # Fusion architecture — styled columns instead of ASCII art
    st.markdown("### Data Fusion")
    f1, f2, f3 = st.columns(3)
    with f1:
        with st.container(border=True):
            st.markdown("**SAP BDC** &rarr; Products, Suppliers, BOMs, POs, Stock")
    with f2:
        with st.container(border=True):
            st.markdown("**Blue Yonder** &rarr; Demand Forecast, Consensus Plan, Loads, Tenders")
    with f3:
        with st.container(border=True):
            st.markdown("**External** &rarr; Commodity Prices, Ports, Outbreaks, News, Vessels")

    st.markdown("""<div style="text-align:center;padding:8px 0;font-size:1.5rem;color:#29B5E8;">
        &darr;&darr;&darr;</div>""", unsafe_allow_html=True)

    with st.container(border=True):
        fc1, fc2 = st.columns([1, 2])
        with fc1:
            st.markdown("#### Snowflake Intelligence Layer")
            st.markdown("17 Iceberg Tables + 3 Analytic Views")
        with fc2:
            st.markdown("**Composite Risk Score** = Supplier (30%) + Transport (25%) + Coverage (25%) + External (10%) + Commodity (10%)")


# ===================================================================
# PAGE 2 — SAP BDC Zero Copy
# ===================================================================
elif page == "SAP BDC Zero Copy":
    st.markdown("## SAP BDC Zero Copy")
    st.caption("Product, supplier, inventory and procurement data from SAP S/4HANA via BDC")

    m = run_query(f"""SELECT
        (SELECT COUNT(*) FROM {DB_SCHEMA}.I_PRODUCT) AS products,
        (SELECT COUNT(*) FROM {DB_SCHEMA}.I_SUPPLIER WHERE IS_ACTIVE=TRUE) AS suppliers,
        (SELECT COUNT(*) FROM {DB_SCHEMA}.I_BILLOFMATERIALITEM) AS bom_items,
        (SELECT COUNT(*) FROM {DB_SCHEMA}.M_V_POH_AGGR) AS pos,
        (SELECT COALESCE(SUM(NET_VALUE_USD),0) FROM {DB_SCHEMA}.M_V_POH_AGGR WHERE GR_DATE IS NULL) AS open_po_val
    """)
    mc1, mc2, mc3, mc4, mc5 = st.columns(5)
    with mc1: kpi_card("Products", int(m["PRODUCTS"].iloc[0]), "#1565c0")
    with mc2: kpi_card("Suppliers", int(m["SUPPLIERS"].iloc[0]), "#00897b")
    with mc3: kpi_card("BOM Components", int(m["BOM_ITEMS"].iloc[0]), "#5e35b1")
    with mc4: kpi_card("Purchase Orders", int(m["POS"].iloc[0]), "#ef6c00")
    with mc5: kpi_card("Open PO Value", f"${m['OPEN_PO_VAL'].iloc[0]:,.0f}", "#c62828")

    st.divider()
    tab1, tab2, tab3, tab4 = st.tabs(["Products", "Suppliers", "Inventory & Coverage", "Purchase Orders"])

    with tab1:
        prods = run_query(f"SELECT MATERIAL_ID, MATERIAL_DESC, DIVISION, BRAND, CATEGORY, CRITICALITY, UNIT_WHOLESALE_USD FROM {DB_SCHEMA}.I_PRODUCT ORDER BY DIVISION, BRAND")
        col_chart, col_tbl = st.columns([1, 2])
        with col_chart:
            div_counts = prods.groupby("DIVISION").size().reset_index(name="COUNT")
            pie = alt.Chart(div_counts).mark_arc(innerRadius=40).encode(
                theta=alt.Theta("COUNT:Q"),
                color=alt.Color("DIVISION:N", scale=alt.Scale(domain=list(DIVISION_COLORS.keys()), range=list(DIVISION_COLORS.values()))),
                tooltip=["DIVISION", "COUNT"],
            ).properties(title="Products by Division", height=280)
            st.altair_chart(pie, use_container_width=True)
        with col_tbl:
            brand_summary = prods.groupby(["DIVISION", "BRAND"]).agg(SKUs=("MATERIAL_ID", "count"), Avg_Price=("UNIT_WHOLESALE_USD", "mean")).reset_index().sort_values(["DIVISION", "BRAND"])
            brand_summary["Avg_Price"] = brand_summary["Avg_Price"].map("${:,.2f}".format)
            st.dataframe(brand_summary, use_container_width=True, hide_index=True)

    with tab2:
        suppliers = run_query(f"""SELECT SUPPLIER_ID, SUPPLIER_NAME, COUNTRY, REGION, SUPPLIER_TYPE, CREDIT_RATING, IS_SOLE_SOURCE, CONTRACT_END
            FROM {DB_SCHEMA}.I_SUPPLIER WHERE IS_ACTIVE=TRUE ORDER BY CREDIT_RATING DESC, SUPPLIER_NAME""")
        st.dataframe(suppliers, use_container_width=True, hide_index=True)

    with tab3:
        inv = run_query(f"""SELECT s.MATERIAL_ID, p.MATERIAL_DESC, s.PLANT, pp.PLANT_NAME,
               s.UNRESTRICTED_STOCK, s.DAYS_OF_SUPPLY, s.DAILY_CONSUMPTION, pp.SAFETY_STOCK_DAYS,
               (pp.SAFETY_STOCK_DAYS - s.DAYS_OF_SUPPLY) AS GAP_DAYS
            FROM {DB_SCHEMA}.PPH_DDL_STOCK_1 s
            JOIN {DB_SCHEMA}.I_PRODUCT p ON p.MATERIAL_ID = s.MATERIAL_ID
            JOIN {DB_SCHEMA}.I_PRODUCTPLANT pp ON pp.MATERIAL_ID = s.MATERIAL_ID AND pp.PLANT = s.PLANT
            ORDER BY GAP_DAYS DESC""")
        chart_data = inv[["MATERIAL_ID", "DAYS_OF_SUPPLY", "SAFETY_STOCK_DAYS"]].head(15).melt(id_vars="MATERIAL_ID", var_name="Metric", value_name="Days")
        bar = alt.Chart(chart_data).mark_bar().encode(
            x=alt.X("MATERIAL_ID:N", sort="-y", title="Material"), y=alt.Y("Days:Q"),
            color=alt.Color("Metric:N", scale=alt.Scale(domain=["DAYS_OF_SUPPLY", "SAFETY_STOCK_DAYS"], range=["#1976d2", "#d32f2f"])),
            xOffset="Metric:N", tooltip=["MATERIAL_ID", "Metric", "Days"],
        ).properties(title="Days of Supply vs Safety Stock Target", height=320)
        st.altair_chart(bar, use_container_width=True)
        st.dataframe(inv, use_container_width=True, hide_index=True)

    with tab4:
        pos = run_query(f"""SELECT PO_NUMBER, MATERIAL_ID, SUPPLIER_ID, ORDER_QTY, NET_VALUE_USD, PO_STATUS, DELIVERY_DATE, GR_DATE
            FROM {DB_SCHEMA}.M_V_POH_AGGR ORDER BY DELIVERY_DATE DESC""")
        st.dataframe(pos, use_container_width=True, hide_index=True)


# ===================================================================
# PAGE 3 — Blue Yonder Planning
# ===================================================================
elif page == "Blue Yonder Planning":
    st.markdown("## Blue Yonder Planning")
    st.caption("Demand forecasts, consensus plans and transport execution from Blue Yonder IBP & TMS")

    tab_d, tab_t, tab_p = st.tabs(["Demand & Consensus Plan", "Transport Execution", "Plan Override"])

    with tab_d:
        peak_kpi = run_query(f"""SELECT COUNT(DISTINCT PEAK_EVENT) AS peak_events,
            SUM(FORECAST_QTY) AS peak_forecast_units, ROUND(AVG(SEASONAL_LIFT_PCT),1) AS avg_lift
            FROM {DB_SCHEMA}.BY_DEMAND_FORECAST WHERE IS_PEAK_WEEK = TRUE""")
        k1, k2, k3 = st.columns(3)
        with k1: kpi_card("Peak Events", int(peak_kpi["PEAK_EVENTS"].iloc[0]), "#00897b")
        with k2: kpi_card("Peak Forecast Units", f"{int(peak_kpi['PEAK_FORECAST_UNITS'].iloc[0]):,}", "#1565c0")
        with k3: kpi_card("Avg Seasonal Lift", f"{peak_kpi['AVG_LIFT'].iloc[0]}%", "#ef6c00")

        st.divider()
        events = run_query(f"SELECT DISTINCT PEAK_EVENT FROM {DB_SCHEMA}.BY_DEMAND_FORECAST WHERE PEAK_EVENT IS NOT NULL ORDER BY 1")
        selected_event = st.selectbox("Filter by Peak Event", ["ALL"] + events["PEAK_EVENT"].tolist())
        where_clause = ""
        if selected_event != "ALL":
            where_clause = f"AND (PEAK_EVENT = '{selected_event.replace(chr(39), chr(39)*2)}' OR PEAK_EVENT IS NULL)"

        weekly = run_query(f"""SELECT WEEK_START, SUM(FORECAST_QTY) AS FORECAST, SUM(BASELINE_QTY) AS BASELINE
            FROM {DB_SCHEMA}.BY_DEMAND_FORECAST WHERE 1=1 {where_clause} GROUP BY WEEK_START ORDER BY WEEK_START""")
        melted = weekly.melt(id_vars="WEEK_START", var_name="Series", value_name="Quantity")
        line = alt.Chart(melted).mark_area(opacity=0.3, line=True).encode(
            x=alt.X("WEEK_START:T", title="Week"), y=alt.Y("Quantity:Q", title="Units"),
            color=alt.Color("Series:N", scale=alt.Scale(domain=["FORECAST", "BASELINE"], range=["#1976d2", "#bdbdbd"])),
            tooltip=["WEEK_START:T", "Series:N", "Quantity:Q"],
        ).properties(title="Weekly Demand: Forecast vs Baseline", height=380)
        st.altair_chart(line, use_container_width=True)

        mat_compare = run_query(f"""SELECT MATERIAL_ID, SUM(BASELINE_QTY) AS BASELINE, SUM(FORECAST_QTY) AS FORECAST
            FROM {DB_SCHEMA}.BY_DEMAND_FORECAST WHERE IS_PEAK_WEEK = TRUE {where_clause} GROUP BY MATERIAL_ID ORDER BY FORECAST DESC""")
        if not mat_compare.empty:
            mc_melt = mat_compare.melt(id_vars="MATERIAL_ID", var_name="Type", value_name="Qty")
            bar_comp = alt.Chart(mc_melt).mark_bar().encode(
                x=alt.X("MATERIAL_ID:N", sort="-y", title="Material"), y=alt.Y("Qty:Q", title="Units"),
                color=alt.Color("Type:N", scale=alt.Scale(domain=["BASELINE", "FORECAST"], range=["#bdbdbd", "#1976d2"])),
                xOffset="Type:N", tooltip=["MATERIAL_ID", "Type", "Qty"],
            ).properties(title="Peak Weeks: Baseline vs Forecast by Material", height=320)
            st.altair_chart(bar_comp, use_container_width=True)

    with tab_t:
        lt1, lt2 = st.columns(2)
        with lt1:
            loads = run_query(f"SELECT LOAD_STATUS, COUNT(*) AS CNT FROM {DB_SCHEMA}.BY_LOADS GROUP BY LOAD_STATUS ORDER BY CNT DESC")
            load_bar = alt.Chart(loads).mark_bar(cornerRadiusTopLeft=4, cornerRadiusTopRight=4).encode(
                x=alt.X("LOAD_STATUS:N", sort="-y", title=""), y=alt.Y("CNT:Q", title="Loads"),
                color=alt.Color("LOAD_STATUS:N", legend=None), tooltip=["LOAD_STATUS", "CNT"],
            ).properties(title="Load Status", height=280)
            st.altair_chart(load_bar, use_container_width=True)
        with lt2:
            tenders = run_query(f"SELECT RESPONSE_TYPE, COUNT(*) AS CNT FROM {DB_SCHEMA}.BY_TENDER_EVENTS GROUP BY RESPONSE_TYPE ORDER BY CNT DESC")
            tender_bar = alt.Chart(tenders).mark_bar(cornerRadiusTopLeft=4, cornerRadiusTopRight=4).encode(
                x=alt.X("RESPONSE_TYPE:N", sort="-y", title=""), y=alt.Y("CNT:Q", title="Events"),
                color=alt.Color("RESPONSE_TYPE:N", legend=None), tooltip=["RESPONSE_TYPE", "CNT"],
            ).properties(title="Tender Responses", height=280)
            st.altair_chart(tender_bar, use_container_width=True)

        all_loads = run_query(f"""SELECT LOAD_ID, LANE_ID, RELATED_PO, CARRIER_ID, SHIPMENT_DATE, DELIVERY_DATE, LOAD_STATUS, WEIGHT_KG
            FROM {DB_SCHEMA}.BY_LOADS ORDER BY SHIPMENT_DATE DESC""")
        st.dataframe(all_loads, use_container_width=True, hide_index=True)

    with tab_p:
        # Plan vs Forecast gap analysis
        plan_gap = run_query(f"""
            SELECT cp.MATERIAL_ID, p.MATERIAL_DESC, p.DIVISION, p.BRAND,
                cp.COMMITTED_QTY, cp.REVENUE_PLAN_USD, cp.PLAN_CONFIDENCE,
                COALESCE(SUM(f.FORECAST_QTY), 0) AS TOTAL_FORECAST_QTY,
                (COALESCE(SUM(f.FORECAST_QTY), 0) - cp.COMMITTED_QTY) AS PLAN_GAP_QTY,
                ROUND((COALESCE(SUM(f.FORECAST_QTY), 0) - cp.COMMITTED_QTY) * p.UNIT_WHOLESALE_USD, 0) AS GAP_REVENUE_USD
            FROM {DB_SCHEMA}.BY_CONSENSUS_PLAN cp
            JOIN {DB_SCHEMA}.I_PRODUCT p ON p.MATERIAL_ID = cp.MATERIAL_ID
            LEFT JOIN {DB_SCHEMA}.BY_DEMAND_FORECAST f ON f.MATERIAL_ID = cp.MATERIAL_ID AND f.IS_PEAK_WEEK = TRUE
            GROUP BY cp.MATERIAL_ID, p.MATERIAL_DESC, p.DIVISION, p.BRAND,
                     cp.COMMITTED_QTY, cp.REVENUE_PLAN_USD, cp.PLAN_CONFIDENCE, p.UNIT_WHOLESALE_USD
            ORDER BY PLAN_GAP_QTY DESC""")

        # KPIs
        total_committed = plan_gap["COMMITTED_QTY"].sum()
        total_forecast = plan_gap["TOTAL_FORECAST_QTY"].sum()
        total_gap = plan_gap["PLAN_GAP_QTY"].sum()
        total_gap_rev = plan_gap["GAP_REVENUE_USD"].sum()

        pk1, pk2, pk3, pk4 = st.columns(4)
        with pk1: kpi_card("Committed (S&OP)", f"{int(total_committed):,}", "#00897b")
        with pk2: kpi_card("Peak Forecast", f"{int(total_forecast):,}", "#1565c0")
        with pk3: kpi_card("Plan Gap (units)", f"{int(total_gap):,}", "#d32f2f" if total_gap > 0 else "#388e3c")
        with pk4: kpi_card("Gap Revenue Impact", f"${int(total_gap_rev):,}", "#d32f2f" if total_gap_rev > 0 else "#388e3c")

        st.divider()

        # Gap chart by material
        gap_chart_data = plan_gap[plan_gap["PLAN_GAP_QTY"] != 0].head(15).copy()
        if not gap_chart_data.empty:
            gap_chart_data["label"] = gap_chart_data["MATERIAL_ID"] + " — " + gap_chart_data["MATERIAL_DESC"].str[:25]
            gap_bar = alt.Chart(gap_chart_data).mark_bar(cornerRadiusTopRight=4, cornerRadiusBottomRight=4).encode(
                y=alt.Y("label:N", sort="-x", title=""),
                x=alt.X("PLAN_GAP_QTY:Q", title="Forecast − Committed (units)"),
                color=alt.condition(
                    alt.datum.PLAN_GAP_QTY > 0,
                    alt.value("#d32f2f"),
                    alt.value("#388e3c")
                ),
                tooltip=["MATERIAL_ID", "MATERIAL_DESC", "COMMITTED_QTY", "TOTAL_FORECAST_QTY", "PLAN_GAP_QTY",
                          alt.Tooltip("GAP_REVENUE_USD:Q", format="$,.0f")],
            ).properties(title="Plan Gap: Forecast vs S&OP Committed", height=max(300, len(gap_chart_data) * 26))
            st.altair_chart(gap_bar, use_container_width=True)

        # Confidence breakdown
        cc1, cc2 = st.columns([1, 2])
        with cc1:
            conf = plan_gap.groupby("PLAN_CONFIDENCE").size().reset_index(name="COUNT")
            conf_colors = {"HIGH": "#388e3c", "MEDIUM": "#fbc02d", "LOW": "#d32f2f"}
            conf_donut = alt.Chart(conf).mark_arc(innerRadius=40).encode(
                theta=alt.Theta("COUNT:Q"),
                color=alt.Color("PLAN_CONFIDENCE:N", scale=alt.Scale(
                    domain=list(conf_colors.keys()), range=list(conf_colors.values()))),
                tooltip=["PLAN_CONFIDENCE", "COUNT"],
            ).properties(title="Plan Confidence", height=240)
            st.altair_chart(conf_donut, use_container_width=True)
        with cc2:
            st.dataframe(plan_gap[["MATERIAL_ID", "MATERIAL_DESC", "DIVISION", "COMMITTED_QTY",
                                    "TOTAL_FORECAST_QTY", "PLAN_GAP_QTY", "GAP_REVENUE_USD", "PLAN_CONFIDENCE"]],
                          use_container_width=True, hide_index=True)

        # ── Interactive Plan Override ──
        st.divider()
        st.markdown("### Adjust Plan")
        st.caption("Override the S&OP committed quantity for a material. Saved overrides persist in BY_PLAN_OVERRIDES.")

        ov_col1, ov_col2 = st.columns([1, 2])
        with ov_col1:
            materials = plan_gap["MATERIAL_ID"].tolist()
            sel_mat = st.selectbox("Material to override", materials, key="plan_override_mat")
            mat_row = plan_gap[plan_gap["MATERIAL_ID"] == sel_mat].iloc[0]

            current_committed = int(mat_row["COMMITTED_QTY"])
            forecast = int(mat_row["TOTAL_FORECAST_QTY"])

            st.markdown(f"**Current S&OP Committed:** {current_committed:,}")
            st.markdown(f"**Peak Forecast:** {forecast:,}")
            st.markdown(f"**Gap:** {int(mat_row['PLAN_GAP_QTY']):,} units")

            max_val = max(forecast * 2, current_committed * 2, 1)
            new_qty = st.slider("New committed quantity", min_value=0, max_value=max_val,
                                value=current_committed, step=500, key="plan_override_qty")
            reason = st.selectbox("Reason", ["Demand surge", "Supply constraint", "Safety stock build",
                                              "Seasonal adjustment", "Customer escalation", "Other"],
                                  key="plan_override_reason")

        with ov_col2:
            new_gap = forecast - new_qty
            st.markdown("")
            st.markdown("")
            compare_data = pd.DataFrame({
                "Measure": ["S&OP Committed", "Override Qty", "Peak Forecast"],
                "Quantity": [current_committed, new_qty, forecast],
                "Type": ["Original", "Override", "Forecast"]
            })
            compare_bar = alt.Chart(compare_data).mark_bar(cornerRadiusTopLeft=4, cornerRadiusTopRight=4).encode(
                x=alt.X("Measure:N", sort=["S&OP Committed", "Override Qty", "Peak Forecast"], title=""),
                y=alt.Y("Quantity:Q", title="Units"),
                color=alt.Color("Type:N", scale=alt.Scale(
                    domain=["Original", "Override", "Forecast"],
                    range=["#9e9e9e", "#1565c0", "#ef6c00"]
                )),
                tooltip=["Measure", "Quantity"],
            ).properties(height=260, title=f"{sel_mat} — Plan Comparison")
            st.altair_chart(compare_bar, use_container_width=True)

            gap_color = "#d32f2f" if new_gap > 0 else "#388e3c"
            st.markdown(f"**New gap:** <span style='color:{gap_color};font-weight:700;'>{new_gap:,} units</span>",
                        unsafe_allow_html=True)

        if new_qty != current_committed:
            if st.button("Save Override", type="primary", key="save_override"):
                safe_reason = reason.replace("'", "''")
                conn.query(f"""
                    MERGE INTO {DB_SCHEMA}.BY_PLAN_OVERRIDES t
                    USING (SELECT '{sel_mat}' AS MATERIAL_ID) s ON t.MATERIAL_ID = s.MATERIAL_ID
                    WHEN MATCHED THEN UPDATE SET OVERRIDE_QTY = {new_qty}, OVERRIDE_REASON = '{safe_reason}',
                        OVERRIDDEN_BY = CURRENT_USER(), OVERRIDE_TIMESTAMP = CURRENT_TIMESTAMP()
                    WHEN NOT MATCHED THEN INSERT (MATERIAL_ID, OVERRIDE_QTY, OVERRIDE_REASON)
                        VALUES ('{sel_mat}', {new_qty}, '{safe_reason}')
                """)
                st.success(f"Override saved: {sel_mat} → {new_qty:,} units ({reason})")

        # Show existing overrides
        existing = run_query(f"SELECT * FROM {DB_SCHEMA}.BY_PLAN_OVERRIDES ORDER BY OVERRIDE_TIMESTAMP DESC")
        if not existing.empty:
            st.markdown("#### Saved Overrides")
            st.dataframe(existing, use_container_width=True, hide_index=True)


# ===================================================================
# PAGE 4 — External Signals
# ===================================================================
elif page == "External Signals":
    st.markdown("## External Signals")
    st.caption("Real-time market, geopolitical and biosecurity intelligence")

    alerts = run_query(f"""SELECT ALERT_ID, DISEASE_NAME, COUNTRY, REGION, RISK_LEVEL, STATUS,
        AFFECTED_SPECIES, ALERT_DATE, STATUS
        FROM {DB_SCHEMA}.EXT_OUTBREAK_ALERTS WHERE STATUS = 'ACTIVE' ORDER BY RISK_LEVEL DESC""")

    if not alerts.empty:
        st.markdown(f"### Active Biosecurity Alerts ({len(alerts)})")
        cols = st.columns(min(len(alerts), 3))
        for idx, (_, row) in enumerate(alerts.iterrows()):
            color = RISK_COLORS.get(row["RISK_LEVEL"], "#757575")
            with cols[idx % 3]:
                st.markdown(f"""<div style="border-left:5px solid {color};border-radius:8px;
                    padding:16px;background:{color}0a;margin-bottom:12px;">
                    <div style="font-weight:700;font-size:1rem;">{row['DISEASE_NAME']}</div>
                    <div style="color:#666;font-size:0.85rem;">{row['COUNTRY']} &bull; {row['REGION']}</div>
                    <div style="margin-top:8px;"><span style="background:{color};color:white;
                    padding:2px 10px;border-radius:12px;font-size:0.8rem;font-weight:600;">{row['RISK_LEVEL']}</span>
                    &nbsp; {row['AFFECTED_SPECIES']}</div>
                    <div style="color:#999;font-size:0.75rem;margin-top:6px;">Since {row['ALERT_DATE']}</div>
                    </div>""", unsafe_allow_html=True)
    else:
        st.success("No active biosecurity alerts.")

    st.divider()
    tab_c, tab_n, tab_pv = st.tabs(["Commodity Prices", "News & Risk Events", "Ports & Vessels"])

    with tab_c:
        commodities = run_query(f"SELECT DISTINCT COMMODITY FROM {DB_SCHEMA}.EXT_COMMODITY_PRICES ORDER BY 1")
        selected_commodities = st.multiselect("Commodities", commodities["COMMODITY"].tolist(), default=commodities["COMMODITY"].tolist()[:3])
        if selected_commodities:
            in_list = ",".join([f"'{c.replace(chr(39), chr(39)*2)}'" for c in selected_commodities])
            prices = run_query(f"""SELECT PRICE_DATE, COMMODITY, SPOT_PRICE, SUPPLY_TIGHTNESS, YOY_CHANGE_PCT
                FROM {DB_SCHEMA}.EXT_COMMODITY_PRICES WHERE COMMODITY IN ({in_list}) ORDER BY PRICE_DATE""")
            price_line = alt.Chart(prices).mark_line(strokeWidth=2).encode(
                x=alt.X("PRICE_DATE:T", title="Date"), y=alt.Y("SPOT_PRICE:Q", title="Spot Price (USD/MT)"),
                color=alt.Color("COMMODITY:N"), tooltip=["PRICE_DATE:T", "COMMODITY:N", "SPOT_PRICE:Q", "SUPPLY_TIGHTNESS:N"],
            ).properties(title="Commodity Spot Prices (90 days)", height=380)
            st.altair_chart(price_line, use_container_width=True)

            latest = run_query(f"""SELECT COMMODITY, SPOT_PRICE, PRICE_UNIT, SUPPLY_TIGHTNESS, YOY_CHANGE_PCT
                FROM {DB_SCHEMA}.EXT_COMMODITY_PRICES
                WHERE PRICE_DATE = (SELECT MAX(PRICE_DATE) FROM {DB_SCHEMA}.EXT_COMMODITY_PRICES) AND COMMODITY IN ({in_list})
                ORDER BY COMMODITY""")
            st.dataframe(latest, use_container_width=True, hide_index=True)

    with tab_n:
        news = run_query(f"""SELECT EVENT_DATE, HEADLINE, RISK_CATEGORY, SEVERITY, SOURCE, RELATED_SUPPLIER, AFFECTED_COMMODITY
            FROM {DB_SCHEMA}.EXT_NEWS_RISK_EVENTS ORDER BY EVENT_DATE DESC""")
        st.dataframe(news, use_container_width=True, hide_index=True)

    with tab_pv:
        col_port, col_vessel = st.columns(2)
        with col_port:
            st.markdown("#### Port Congestion (latest)")
            ports = run_query(f"""SELECT PORT_CODE, PORT_NAME, COUNTRY, CONGESTION_SCORE, AVG_WAIT_HOURS, VESSELS_AT_ANCHOR, ALERT_LEVEL
                FROM {DB_SCHEMA}.EXT_PORT_CONGESTION
                WHERE REPORT_DATE = (SELECT MAX(REPORT_DATE) FROM {DB_SCHEMA}.EXT_PORT_CONGESTION) ORDER BY CONGESTION_SCORE DESC""")
            st.dataframe(ports, use_container_width=True, hide_index=True)
        with col_vessel:
            st.markdown("#### Vessel Tracker")
            vessels = run_query(f"""SELECT VESSEL_NAME, VESSEL_TYPE, CARGO_TYPE, DEPARTURE_PORT, DESTINATION_PORT,
                ORIGINAL_ETA, REVISED_ETA, DELAY_DAYS, CURRENT_STATUS
                FROM {DB_SCHEMA}.EXT_VESSEL_TRACKER ORDER BY DELAY_DAYS DESC""")
            st.dataframe(vessels, use_container_width=True, hide_index=True)


# ===================================================================
# PAGE 5 — Risk Command Center
# ===================================================================
elif page == "Risk Command Center":
    st.markdown("## Risk Command Center")
    st.caption("Composite risk scoring across all data layers")

    risk = run_query(f"""SELECT MATERIAL_ID, MATERIAL_DESC, DIVISION, BRAND, PLANT, PEAK_EVENT,
        COMPOSITE_RISK_SCORE, RISK_TIER, AT_RISK_SUPPLIERS, BIOSECURITY_ALERT,
        SUPPLY_SHORTFALL_QTY, REVENUE_AT_RISK_USD, DAYS_OF_SUPPLY, SAFETY_STOCK_DAYS,
        DISRUPTED_LOAD_COUNT, COMMODITY_YOY_CHANGE_PCT
        FROM {DB_SCHEMA}.V_SUPPLY_RISK_SCORE ORDER BY COMPOSITE_RISK_SCORE DESC""")

    # Risk leaderboard
    st.markdown("### Risk Leaderboard")
    top20 = risk.head(20).copy()
    top20["label"] = top20["MATERIAL_ID"] + " — " + top20["MATERIAL_DESC"].str[:30]
    leaderboard = alt.Chart(top20).mark_bar(cornerRadiusTopRight=4, cornerRadiusBottomRight=4).encode(
        y=alt.Y("label:N", sort="-x", title=""),
        x=alt.X("COMPOSITE_RISK_SCORE:Q", title="Composite Risk Score", scale=alt.Scale(domain=[0, 100])),
        color=alt.Color("RISK_TIER:N", scale=alt.Scale(domain=list(RISK_COLORS.keys()), range=list(RISK_COLORS.values()))),
        tooltip=["MATERIAL_ID", "MATERIAL_DESC", "COMPOSITE_RISK_SCORE", "RISK_TIER", "REVENUE_AT_RISK_USD"],
    ).properties(height=max(450, len(top20) * 26))
    st.altair_chart(leaderboard, use_container_width=True)

    st.divider()
    col_tier, col_div = st.columns(2)

    with col_tier:
        st.markdown("#### Risk Tier Distribution")
        tier_dist = risk.groupby("RISK_TIER").size().reset_index(name="COUNT")
        donut = alt.Chart(tier_dist).mark_arc(innerRadius=60, outerRadius=110).encode(
            theta=alt.Theta("COUNT:Q"),
            color=alt.Color("RISK_TIER:N", scale=alt.Scale(domain=list(RISK_COLORS.keys()), range=list(RISK_COLORS.values()))),
            tooltip=["RISK_TIER", "COUNT"],
        ).properties(height=300)
        st.altair_chart(donut, use_container_width=True)

    with col_div:
        st.markdown("#### Revenue at Risk by Division")
        div_risk = risk.groupby("DIVISION")["REVENUE_AT_RISK_USD"].sum().reset_index().sort_values("REVENUE_AT_RISK_USD", ascending=True)
        hbar = alt.Chart(div_risk).mark_bar(cornerRadiusTopRight=4, cornerRadiusBottomRight=4).encode(
            y=alt.Y("DIVISION:N", sort="-x", title=""),
            x=alt.X("REVENUE_AT_RISK_USD:Q", title="Revenue at Risk ($)"),
            color=alt.Color("DIVISION:N", scale=alt.Scale(domain=list(DIVISION_COLORS.keys()), range=list(DIVISION_COLORS.values())), legend=None),
            tooltip=["DIVISION", alt.Tooltip("REVENUE_AT_RISK_USD:Q", format="$,.0f")],
        ).properties(height=200)
        st.altair_chart(hbar, use_container_width=True)

    # Drill-down
    st.divider()
    st.markdown("### Material Drill-Down")
    selected_material = st.selectbox("Select Material", risk["MATERIAL_ID"].tolist())

    if selected_material:
        row = risk[risk["MATERIAL_ID"] == selected_material].iloc[0]
        tier_color = RISK_COLORS.get(row["RISK_TIER"], "#888")

        d1, d2, d3, d4, d5 = st.columns(5)
        with d1: kpi_card("Composite Score", f"{row['COMPOSITE_RISK_SCORE']:.1f}", tier_color)
        with d2: kpi_card("Risk Tier", row["RISK_TIER"], tier_color)
        with d3: kpi_card("Revenue at Risk", f"${row['REVENUE_AT_RISK_USD']:,.0f}", "#d32f2f")
        with d4: kpi_card("Days of Supply", int(row["DAYS_OF_SUPPLY"]), "#1565c0")
        with d5: kpi_card("Safety Target", int(row["SAFETY_STOCK_DAYS"]), "#00897b")

        with st.container(border=True):
            dc1, dc2 = st.columns(2)
            with dc1:
                st.markdown(f"**Material:** {row['MATERIAL_ID']} — {row['MATERIAL_DESC']}")
                st.markdown(f"**Division / Brand:** {row['DIVISION']} / {row['BRAND']}")
                st.markdown(f"**Plant:** {row['PLANT']}")
                st.markdown(f"**Peak Event:** {row['PEAK_EVENT'] or 'N/A'}")
            with dc2:
                st.markdown(f"**At-Risk Suppliers:** {row['AT_RISK_SUPPLIERS']}")
                st.markdown(f"**Biosecurity Alert:** {row['BIOSECURITY_ALERT']}")
                st.markdown(f"**Supply Shortfall:** {int(row['SUPPLY_SHORTFALL_QTY']):,} units")
                st.markdown(f"**Disrupted Loads:** {int(row['DISRUPTED_LOAD_COUNT'])}")
                st.markdown(f"**Commodity YoY Change:** {row['COMMODITY_YOY_CHANGE_PCT']:.1f}%")
