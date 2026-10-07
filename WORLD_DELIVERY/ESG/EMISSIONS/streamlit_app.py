import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
from snowflake.snowpark.context import get_active_session
import pandas as pd
import json

# =============================================================================
# World Delivery — ESG Intelligence Dashboard
# CxO-grade sustainability analytics powered by Snowflake + SAP BDC
# =============================================================================

st.set_page_config(page_title="World Delivery ESG", page_icon="🌍", layout="wide")

session = get_active_session()

# -- Helpers -------------------------------------------------------------------

@st.cache_data(ttl=300)
def run_query(sql: str) -> pd.DataFrame:
    return session.sql(sql).to_pandas()

BRAND_COLORS = {
    "EXPRESS": "#29B5E8", "SUPPLY_CHAIN": "#71D4F5", "ECOMMERCE": "#0F3B5F",
    "POST_PARCEL": "#11567F", "GROUP": "#97D1E8", "BUILDINGS": "#B0BEC5",
    "AIR": "#FF6B35", "ROAD": "#FFB347", "OCEAN": "#4FC3F7", "RAIL": "#81C784",
}

# -- Sidebar navigation -------------------------------------------------------

page = st.sidebar.radio(
    "Navigation",
    ["Executive Overview", "Emissions Deep Dive", "Forecast & Scenarios",
     "Fleet & Energy", "GoGreen Plus", "Workforce & Social", "ESG Agent Chat"],
    index=0,
)

st.sidebar.markdown("---")
st.sidebar.caption("World Delivery ESG Dashboard v1.0")
st.sidebar.caption("Powered by Snowflake + SAP BDC")


# =============================================================================
# PAGE 1: Executive Overview
# =============================================================================
if page == "Executive Overview":
    st.title("🌍 World Delivery — ESG Executive Overview")
    st.caption("Strategy 2030 · SBTi-validated targets · 7 steering KPIs")

    # -- 7 KPI Cards -----------------------------------------------------------
    kpis = run_query("SELECT * FROM V_ESG_KPI_DASHBOARD LIMIT 1")
    if not kpis.empty:
        k = kpis.iloc[0]
        c1, c2, c3, c4, c5, c6, c7 = st.columns(7)
        c1.metric("GHG Emissions", f"{k.get('KPI_1_GHG_EMISSIONS_MT', 0):.1f} Mt", "-3.2% YoY")
        c2.metric("Decarb Effects", f"{k.get('KPI_2_DECARB_EFFECTS_KT', 0):.0f} kt", "+12%")
        c3.metric("Engagement", f"{k.get('KPI_3_EMPLOYEE_ENGAGEMENT_PCT', 0):.0f}%", "+2pp")
        c4.metric("Women in Mgmt", f"{k.get('KPI_4_WOMEN_IN_MGMT_PCT', 0):.1f}%", "+1.2pp")
        c5.metric("LTIFR", f"{k.get('KPI_5_LTIFR', 0):.1f}", "-0.4")
        c6.metric("Compliance", f"{k.get('KPI_6_COMPLIANCE_TRAINING_PCT', 0):.0f}%", "+1pp")
        c7.metric("Cyber Rating", str(k.get('KPI_7_CYBERSECURITY_RATING', 'A-')), "stable")

    st.markdown("---")

    # -- GHG Trend + Decarb Effects side by side -------------------------------
    col_left, col_right = st.columns(2)

    with col_left:
        st.subheader("GHG Emissions by Scope (Year-over-Year)")
        esrs = run_query("""
            SELECT REPORTING_YEAR,
                   SCOPE_1_TONNES, SCOPE_2_MARKET_BASED_TONNES, SCOPE_3_TOTAL_TONNES
            FROM V_ESRS_E1_DISCLOSURE
            ORDER BY REPORTING_YEAR
        """)
        if not esrs.empty:
            fig = go.Figure()
            fig.add_trace(go.Bar(x=esrs["REPORTING_YEAR"], y=esrs["SCOPE_1_TONNES"],
                                 name="Scope 1", marker_color="#FF6B35"))
            fig.add_trace(go.Bar(x=esrs["REPORTING_YEAR"], y=esrs["SCOPE_2_MARKET_BASED_TONNES"],
                                 name="Scope 2 (market)", marker_color="#FFB347"))
            fig.add_trace(go.Bar(x=esrs["REPORTING_YEAR"], y=esrs["SCOPE_3_TOTAL_TONNES"],
                                 name="Scope 3", marker_color="#4FC3F7"))
            fig.update_layout(barmode="stack", height=380, margin=dict(l=20,r=20,t=30,b=20),
                              yaxis_title="Tonnes CO2e", legend=dict(orientation="h", y=-0.15))
            st.plotly_chart(fig, use_container_width=True)

    with col_right:
        st.subheader("SBTi 2030 Target Progress")
        decarb = run_query("SELECT * FROM V_DECARB_PROGRESS ORDER BY REPORTING_YEAR DESC LIMIT 1")
        if not decarb.empty:
            d = decarb.iloc[0]
            red_12 = d.get("REDUCTION_PCT_SCOPE_1_2", 0) or 0
            red_3 = d.get("REDUCTION_PCT_SCOPE_3", 0) or 0

            fig = go.Figure()
            fig.add_trace(go.Bar(x=["Scope 1&2"], y=[float(red_12)], name="Achieved",
                                 marker_color="#29B5E8", text=[f"{red_12:.1f}%"], textposition="inside"))
            fig.add_trace(go.Bar(x=["Scope 1&2"], y=[42 - max(float(red_12), 0)], name="Remaining",
                                 marker_color="#E0E0E0", showlegend=False))
            fig.add_trace(go.Bar(x=["Scope 3"], y=[float(red_3)],
                                 marker_color="#29B5E8", showlegend=False,
                                 text=[f"{red_3:.1f}%"], textposition="inside"))
            fig.add_trace(go.Bar(x=["Scope 3"], y=[25 - max(float(red_3), 0)],
                                 marker_color="#E0E0E0", showlegend=False))
            fig.update_layout(barmode="stack", height=380, margin=dict(l=20,r=20,t=30,b=20),
                              yaxis_title="Reduction %", yaxis_range=[0, 50],
                              legend=dict(orientation="h", y=-0.15))
            fig.add_hline(y=42, line_dash="dot", annotation_text="Scope 1&2 Target: -42%")
            fig.add_hline(y=25, line_dash="dot", annotation_text="Scope 3 Target: -25%", line_color="gray")
            st.plotly_chart(fig, use_container_width=True)

    # -- Scope 1 by Mode + Division -------------------------------------------
    col_a, col_b = st.columns(2)

    with col_a:
        st.subheader("Emissions by Transport Mode")
        mode_data = run_query("""
            SELECT TRANSPORTMODE, SUM(TOTAL_CO2E_TONNES) AS CO2E_TONNES
            FROM V_GHG_EMISSIONS_SUMMARY
            WHERE REPORTING_YEAR = (SELECT MAX(REPORTING_YEAR) FROM V_GHG_EMISSIONS_SUMMARY)
            GROUP BY TRANSPORTMODE ORDER BY CO2E_TONNES DESC
        """)
        if not mode_data.empty:
            fig = px.pie(mode_data, values="CO2E_TONNES", names="TRANSPORTMODE",
                         color="TRANSPORTMODE", color_discrete_map=BRAND_COLORS,
                         hole=0.45)
            fig.update_layout(height=350, margin=dict(l=20,r=20,t=30,b=20))
            st.plotly_chart(fig, use_container_width=True)

    with col_b:
        st.subheader("Emissions by Division")
        div_data = run_query("""
            SELECT DIVISION, SUM(TOTAL_CO2E_TONNES) AS CO2E_TONNES
            FROM V_GHG_EMISSIONS_SUMMARY
            WHERE REPORTING_YEAR = (SELECT MAX(REPORTING_YEAR) FROM V_GHG_EMISSIONS_SUMMARY)
            GROUP BY DIVISION ORDER BY CO2E_TONNES DESC
        """)
        if not div_data.empty:
            fig = px.bar(div_data, x="DIVISION", y="CO2E_TONNES",
                         color="DIVISION", color_discrete_map=BRAND_COLORS)
            fig.update_layout(height=350, margin=dict(l=20,r=20,t=30,b=20),
                              showlegend=False, yaxis_title="Tonnes CO2e")
            st.plotly_chart(fig, use_container_width=True)


# =============================================================================
# PAGE 2: Emissions Deep Dive
# =============================================================================
elif page == "Emissions Deep Dive":
    st.title("Emissions Deep Dive")

    fc1, fc2 = st.columns(2)
    divisions = run_query("SELECT DISTINCT DIVISION FROM V_GHG_EMISSIONS_SUMMARY ORDER BY 1")
    div_filter = fc1.multiselect("Division", divisions["DIVISION"].tolist(), default=divisions["DIVISION"].tolist())
    modes = run_query("SELECT DISTINCT TRANSPORTMODE FROM V_GHG_EMISSIONS_SUMMARY ORDER BY 1")
    mode_filter = fc2.multiselect("Transport Mode", modes["TRANSPORTMODE"].tolist(), default=modes["TRANSPORTMODE"].tolist())

    div_str = ",".join([f"'{d}'" for d in div_filter]) if div_filter else "'_'"
    mode_str = ",".join([f"'{m}'" for m in mode_filter]) if mode_filter else "'_'"

    st.subheader("Emissions by Division and Mode")
    detail = run_query(f"""
        SELECT DIVISION, TRANSPORTMODE,
               SUM(TOTAL_CO2E_TONNES) AS CO2E_TONNES,
               SUM(SHIPMENT_COUNT) AS SHIPMENTS
        FROM V_GHG_EMISSIONS_SUMMARY
        WHERE DIVISION IN ({div_str}) AND TRANSPORTMODE IN ({mode_str})
        GROUP BY 1, 2 ORDER BY CO2E_TONNES DESC
    """)
    if not detail.empty:
        fig = px.bar(detail, x="DIVISION", y="CO2E_TONNES", color="TRANSPORTMODE",
                     color_discrete_map=BRAND_COLORS, barmode="group")
        fig.update_layout(height=400, yaxis_title="Tonnes CO2e")
        st.plotly_chart(fig, use_container_width=True)

    st.subheader("Emissions by Fuel Type")
    fuel = run_query(f"""
        SELECT FUELTYPEUSED, SUM(TOTAL_CO2E_TONNES) AS CO2E_TONNES
        FROM V_GHG_EMISSIONS_SUMMARY
        WHERE DIVISION IN ({div_str}) AND TRANSPORTMODE IN ({mode_str})
        GROUP BY 1 ORDER BY CO2E_TONNES DESC
    """)
    if not fuel.empty:
        fig = px.bar(fuel, x="FUELTYPEUSED", y="CO2E_TONNES", color="FUELTYPEUSED")
        fig.update_layout(height=350, showlegend=False, yaxis_title="Tonnes CO2e")
        st.plotly_chart(fig, use_container_width=True)

    st.subheader("Top Emission Routes (Air)")
    routes = run_query("""
        SELECT ORIGIN, DESTINATION, COUNT(*) AS SHIPMENTS,
               SUM(CO2EKG)/1000 AS CO2E_TONNES,
               AVG(DISTANCEKM) AS AVG_DISTANCE_KM
        FROM Z_SHIPMENT_EMISSIONS
        WHERE TRANSPORTMODE = 'AIR'
        GROUP BY 1, 2
        ORDER BY CO2E_TONNES DESC
        LIMIT 10
    """)
    st.dataframe(routes, use_container_width=True)


# =============================================================================
# PAGE 3: Forecast & Scenarios
# =============================================================================
elif page == "Forecast & Scenarios":
    st.title("Emission Forecast & Scenario Analysis")
    st.caption("Will we hit our SBTi 2030 targets? Three scenarios through 2030.")

    scope_choice = st.radio("Scope", ["Scope 1&2", "Scope 3"], horizontal=True)
    scope_filter = "SCOPE_1_2" if scope_choice == "Scope 1&2" else "SCOPE_3"
    target_pct = 42.0 if scope_filter == "SCOPE_1_2" else 25.0
    target_label = f"-{target_pct:.0f}% by 2030"

    # -- Scenario trajectory chart ---------------------------------------------
    st.subheader(f"{scope_choice} Emission Trajectory — Actuals vs Scenarios")

    forecast = run_query(f"""
        SELECT REPORTING_YEAR, SCENARIO, TOTAL_CO2E_MT, REDUCTION_FROM_BASE_PCT,
               IS_FORECAST, TARGET_STATUS
        FROM V_EMISSION_FORECAST
        WHERE SCOPE_GROUP = '{scope_filter}'
        ORDER BY SCENARIO, REPORTING_YEAR
    """)

    if not forecast.empty:
        color_map = {"ACTUAL": "#29B5E8", "BAU": "#FF6B35", "ACCELERATED": "#81C784", "SBTI_REQUIRED": "#B0BEC5"}
        dash_map = {"ACTUAL": "solid", "BAU": "dash", "ACCELERATED": "dash", "SBTI_REQUIRED": "dot"}

        fig = go.Figure()
        for scenario in ["ACTUAL", "BAU", "ACCELERATED", "SBTI_REQUIRED"]:
            df_s = forecast[forecast["SCENARIO"] == scenario]
            if not df_s.empty:
                fig.add_trace(go.Scatter(
                    x=df_s["REPORTING_YEAR"], y=df_s["TOTAL_CO2E_MT"],
                    mode="lines+markers", name=scenario.replace("_", " ").title(),
                    line=dict(color=color_map.get(scenario, "#888"), dash=dash_map.get(scenario, "solid"), width=3),
                    marker=dict(size=8)
                ))

        # Add SBTi 2030 target point
        target_mt = 4.36 if scope_filter == "SCOPE_1_2" else 24.53
        fig.add_trace(go.Scatter(
            x=[2030], y=[target_mt], mode="markers",
            marker=dict(size=15, symbol="star", color="red", line=dict(width=2, color="white")),
            name=f"SBTi 2030 Target ({target_label})", showlegend=True
        ))

        fig.update_layout(
            height=450, margin=dict(l=20,r=20,t=30,b=20),
            yaxis_title="Million Tonnes CO2e",
            xaxis_title="Year",
            legend=dict(orientation="h", y=-0.15),
            xaxis=dict(dtick=1)
        )
        st.plotly_chart(fig, use_container_width=True)

        # -- Gap analysis cards ------------------------------------------------
        bau_2030 = forecast[(forecast["SCENARIO"]=="BAU") & (forecast["REPORTING_YEAR"]==2030)]
        acc_2030 = forecast[(forecast["SCENARIO"]=="ACCELERATED") & (forecast["REPORTING_YEAR"]==2030)]
        sbt_2030 = forecast[(forecast["SCENARIO"]=="SBTI_REQUIRED") & (forecast["REPORTING_YEAR"]==2030)]

        st.subheader("2030 Scenario Comparison")
        c1, c2, c3 = st.columns(3)

        if not bau_2030.empty:
            bau_mt = bau_2030.iloc[0]["TOTAL_CO2E_MT"]
            bau_gap = bau_mt - target_mt
            c1.metric("BAU (Current Path)", f"{bau_mt:.2f} Mt",
                      f"{'Misses' if bau_gap > 0 else 'Meets'} target by {abs(bau_gap):.2f} Mt",
                      delta_color="inverse")
        if not acc_2030.empty:
            acc_mt = acc_2030.iloc[0]["TOTAL_CO2E_MT"]
            acc_gap = acc_mt - target_mt
            c2.metric("Accelerated Decarb", f"{acc_mt:.2f} Mt",
                      f"{'Misses' if acc_gap > 0 else 'Meets'} target by {abs(acc_gap):.2f} Mt",
                      delta_color="inverse")
        if not sbt_2030.empty:
            sbt_mt = sbt_2030.iloc[0]["TOTAL_CO2E_MT"]
            c3.metric("SBTi Required Path", f"{sbt_mt:.2f} Mt", target_label)

    # -- Decarb lever analysis -------------------------------------------------
    st.markdown("---")
    st.subheader("Decarbonization Levers — Marginal Abatement Cost Curve")

    lever_scenario = st.selectbox("Scenario", ["BAU", "ACCELERATED"], index=1)
    lever_year = st.slider("Projection Year", 2026, 2030, 2030)

    levers = run_query(f"""
        SELECT LEVER_NAME, CO2E_REDUCTION_KT, INVESTMENT_MEUR,
               COST_PER_TONNE_EUR, READINESS,
               CUMULATIVE_REDUCTION_KT, CUMULATIVE_INVESTMENT_MEUR
        FROM V_DECARB_LEVER_ANALYSIS
        WHERE SCENARIO = '{lever_scenario}' AND REPORTING_YEAR = {lever_year}
        ORDER BY COST_PER_TONNE_EUR
    """)

    if not levers.empty:
        col_l, col_r = st.columns(2)

        with col_l:
            fig = px.bar(levers, x="LEVER_NAME", y="CO2E_REDUCTION_KT",
                         color="READINESS",
                         color_discrete_map={"DEPLOYED": "#29B5E8", "SCALING": "#FFB347",
                                             "PILOT": "#FF6B35", "EMERGING": "#B0BEC5"},
                         text_auto=True)
            fig.update_layout(height=380, yaxis_title="CO2e Reduction (kt)", showlegend=True,
                              xaxis_title="")
            st.plotly_chart(fig, use_container_width=True)

        with col_r:
            fig = go.Figure()
            fig.add_trace(go.Bar(
                x=levers["LEVER_NAME"], y=levers["COST_PER_TONNE_EUR"],
                marker_color=["#29B5E8" if r == "DEPLOYED" else "#FFB347" if r == "SCALING" else "#FF6B35" for r in levers["READINESS"]],
                text=levers["COST_PER_TONNE_EUR"].apply(lambda x: f"EUR {x:,.0f}"),
                textposition="outside"
            ))
            fig.update_layout(height=380, yaxis_title="EUR per tonne CO2e avoided",
                              xaxis_title="", title="Marginal Abatement Cost")
            st.plotly_chart(fig, use_container_width=True)

        st.subheader(f"Investment Summary — {lever_scenario} scenario, {lever_year}")
        total_reduction = levers["CO2E_REDUCTION_KT"].sum()
        total_invest = levers["INVESTMENT_MEUR"].sum()
        avg_cost = total_invest * 1000 / max(total_reduction, 1)
        m1, m2, m3 = st.columns(3)
        m1.metric("Total CO2e Reduction", f"{total_reduction:,.0f} kt")
        m2.metric("Total Investment", f"EUR {total_invest:,.0f}M")
        m3.metric("Avg Cost per Tonne", f"EUR {avg_cost:,.0f}")

        st.dataframe(levers, use_container_width=True)


# =============================================================================
# PAGE 4: Fleet & Energy (was page 3)
# =============================================================================
elif page == "Fleet & Energy":
    st.title("Fleet Electrification & Energy")

    fleet = run_query("""
        SELECT DRIVETYPE, COUNT(*) AS VEHICLE_COUNT,
               AVG(CO2GPERKM) AS AVG_CO2_GPKM
        FROM Z_FLEET_VEHICLE WHERE ISACTIVE = TRUE
        GROUP BY 1 ORDER BY VEHICLE_COUNT DESC
    """)

    ev_count = fleet[fleet["DRIVETYPE"].isin(["BEV", "PHEV", "H2"])]["VEHICLE_COUNT"].sum() if not fleet.empty else 0
    total = fleet["VEHICLE_COUNT"].sum() if not fleet.empty else 1

    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Total Fleet", f"{total:,.0f}")
    c2.metric("e-Vehicles", f"{ev_count:,.0f}")
    c3.metric("e-Vehicle %", f"{ev_count/total*100:.1f}%")
    renewable = run_query("""
        SELECT SUM(CASE WHEN ENERGYSOURCETYPE IN ('GRID_RENEWABLE','SOLAR_ONSITE','WIND_ONSITE') THEN CONSUMPTIONKWH ELSE 0 END)
             / NULLIF(SUM(CONSUMPTIONKWH), 0) * 100 AS RENEWABLE_PCT
        FROM Z_FACILITY_ENERGY
    """)
    rpct = renewable.iloc[0]["RENEWABLE_PCT"] if not renewable.empty and renewable.iloc[0]["RENEWABLE_PCT"] else 0
    c4.metric("Renewable Energy %", f"{rpct:.1f}%")

    st.markdown("---")
    col_l, col_r = st.columns(2)

    with col_l:
        st.subheader("Fleet by Drive Type")
        if not fleet.empty:
            drive_order = ["BEV", "PHEV", "H2", "HVO", "CNG", "DIESEL"]
            fleet["DRIVETYPE"] = pd.Categorical(fleet["DRIVETYPE"], categories=drive_order, ordered=True)
            fleet = fleet.sort_values("DRIVETYPE")
            colors = {"BEV": "#29B5E8", "PHEV": "#71D4F5", "H2": "#81C784",
                       "HVO": "#FFB347", "CNG": "#FFA726", "DIESEL": "#B0BEC5"}
            fig = px.bar(fleet, x="DRIVETYPE", y="VEHICLE_COUNT", color="DRIVETYPE",
                         color_discrete_map=colors)
            fig.update_layout(height=350, showlegend=False, yaxis_title="Vehicles")
            st.plotly_chart(fig, use_container_width=True)

    with col_r:
        st.subheader("Facility Energy Mix")
        energy_mix = run_query("""
            SELECT ENERGYSOURCETYPE, SUM(CONSUMPTIONMWH) AS MWH
            FROM Z_FACILITY_ENERGY GROUP BY 1 ORDER BY MWH DESC
        """)
        if not energy_mix.empty:
            fig = px.pie(energy_mix, values="MWH", names="ENERGYSOURCETYPE", hole=0.4)
            fig.update_layout(height=350, margin=dict(l=20,r=20,t=30,b=20))
            st.plotly_chart(fig, use_container_width=True)


# =============================================================================
# PAGE 4: GoGreen Plus
# =============================================================================
elif page == "GoGreen Plus":
    st.title("GoGreen Plus — Green Logistics Revenue")
    st.caption("Emission-reduced logistics via SAF, e-vehicles, and carbon insetting")

    gg = run_query("""
        SELECT SUM(GREEN_PREMIUM_USD) AS PREMIUM,
               SUM(TOTAL_REVENUE_USD) AS REVENUE,
               SUM(CO2E_AVOIDED_TONNES) AS CO2E_AVOIDED,
               SUM(SAF_DEPLOYED_TONNES) AS SAF_TONNES,
               SUM(ORDER_COUNT) AS ORDERS
        FROM V_GOGREEN_REVENUE
    """)
    if not gg.empty:
        g = gg.iloc[0]
        c1, c2, c3, c4 = st.columns(4)
        c1.metric("Green Premium Revenue", f"${g['PREMIUM']:,.0f}")
        c2.metric("CO2e Avoided", f"{g['CO2E_AVOIDED']:,.0f} t")
        c3.metric("SAF Deployed", f"{g['SAF_TONNES']:,.0f} t")
        c4.metric("Total Orders", f"{g['ORDERS']:,.0f}")

    st.markdown("---")
    col_l, col_r = st.columns(2)

    with col_l:
        st.subheader("Revenue by Customer Segment")
        seg = run_query("""
            SELECT CUSTOMERSEGMENT,
                   SUM(GREEN_PREMIUM_USD) AS PREMIUM_USD,
                   SUM(CO2E_AVOIDED_TONNES) AS CO2E_AVOIDED
            FROM V_GOGREEN_REVENUE GROUP BY 1 ORDER BY PREMIUM_USD DESC
        """)
        if not seg.empty:
            fig = px.bar(seg, x="CUSTOMERSEGMENT", y="PREMIUM_USD",
                         color="CUSTOMERSEGMENT", text_auto=True)
            fig.update_layout(height=350, showlegend=False, yaxis_title="Green Premium USD")
            st.plotly_chart(fig, use_container_width=True)

    with col_r:
        st.subheader("CO2e Avoided by Technology")
        tech = run_query("""
            SELECT DECARBTECHNOLOGY, SUM(CO2E_AVOIDED_TONNES) AS CO2E_AVOIDED
            FROM V_GOGREEN_REVENUE GROUP BY 1 ORDER BY CO2E_AVOIDED DESC
        """)
        if not tech.empty:
            fig = px.pie(tech, values="CO2E_AVOIDED", names="DECARBTECHNOLOGY", hole=0.4)
            fig.update_layout(height=350, margin=dict(l=20,r=20,t=30,b=20))
            st.plotly_chart(fig, use_container_width=True)

    st.subheader("Top Customers by CO2e Avoidance")
    customers = run_query("""
        SELECT CUSTOMERNAME, CUSTOMERSEGMENT,
               SUM(ORDER_COUNT) AS ORDERS,
               SUM(GREEN_PREMIUM_USD) AS PREMIUM_USD,
               SUM(CO2E_AVOIDED_TONNES) AS CO2E_AVOIDED_T,
               SUM(SAF_DEPLOYED_TONNES) AS SAF_T,
               SUM(CERTIFICATES_ISSUED) AS CERTS
        FROM V_GOGREEN_REVENUE
        GROUP BY 1, 2
        ORDER BY CO2E_AVOIDED_T DESC
        LIMIT 15
    """)
    st.dataframe(customers, use_container_width=True)


# =============================================================================
# PAGE 5: Workforce & Social
# =============================================================================
elif page == "Workforce & Social":
    st.title("Workforce & Social KPIs")

    wf_latest = run_query("""
        SELECT SUM(HEADCOUNT) AS HC,
               AVG(ENGAGEMENTSCORE) AS ENG,
               AVG(WOMENINMANAGEMENTPCT) AS WIM,
               AVG(TRAININGHRSPEREMPLOYEE) AS TRN
        FROM SF_CORE_WORKFORCE
        WHERE QUARTER = (SELECT MAX(QUARTER) FROM SF_CORE_WORKFORCE)
    """)
    sf_latest = run_query("""
        SELECT AVG(LTIFR) AS LTIFR FROM SF_HEALTH_SAFETY
        WHERE QUARTER = (SELECT MAX(QUARTER) FROM SF_HEALTH_SAFETY)
    """)

    if not wf_latest.empty:
        w = wf_latest.iloc[0]
        s_val = sf_latest.iloc[0]["LTIFR"] if not sf_latest.empty else 0
        c1, c2, c3, c4, c5 = st.columns(5)
        c1.metric("Total Headcount", f"{w['HC']:,.0f}")
        c2.metric("Engagement", f"{w['ENG']:.0f}%")
        c3.metric("Women in Mgmt", f"{w['WIM']:.1f}%")
        c4.metric("Training Hrs/Emp", f"{w['TRN']:.1f}")
        c5.metric("LTIFR", f"{s_val:.1f}")

    st.markdown("---")
    col_l, col_r = st.columns(2)

    with col_l:
        st.subheader("Employee Engagement by Division")
        eng_trend = run_query("""
            SELECT QUARTER, DIVISION, AVG(ENGAGEMENTSCORE) AS ENGAGEMENT
            FROM SF_CORE_WORKFORCE GROUP BY 1, 2 ORDER BY 1
        """)
        if not eng_trend.empty:
            fig = px.line(eng_trend, x="QUARTER", y="ENGAGEMENT", color="DIVISION",
                          color_discrete_map=BRAND_COLORS, markers=True)
            fig.update_layout(height=350, yaxis_title="Engagement Score")
            st.plotly_chart(fig, use_container_width=True)

    with col_r:
        st.subheader("Women in Management Trend")
        wim_trend = run_query("""
            SELECT QUARTER, AVG(WOMENINMANAGEMENTPCT) AS WIM_PCT
            FROM SF_CORE_WORKFORCE GROUP BY 1 ORDER BY 1
        """)
        if not wim_trend.empty:
            fig = go.Figure()
            fig.add_trace(go.Scatter(x=wim_trend["QUARTER"], y=wim_trend["WIM_PCT"],
                                     mode="lines+markers", name="Actual", line=dict(color="#29B5E8")))
            fig.add_hline(y=30, line_dash="dot", annotation_text="2030 Target: 30%", line_color="gray")
            fig.update_layout(height=350, yaxis_title="Women in Management %")
            st.plotly_chart(fig, use_container_width=True)

    st.subheader("LTIFR by Division")
    ltifr = run_query("""
        SELECT DIVISION, QUARTER, AVG(LTIFR) AS LTIFR
        FROM SF_HEALTH_SAFETY GROUP BY 1, 2 ORDER BY 2
    """)
    if not ltifr.empty:
        fig = px.line(ltifr, x="QUARTER", y="LTIFR", color="DIVISION",
                      color_discrete_map=BRAND_COLORS, markers=True)
        fig.update_layout(height=350, yaxis_title="LTIFR (per 200k hours)")
        st.plotly_chart(fig, use_container_width=True)


# =============================================================================
# PAGE 6: ESG Agent Chat
# =============================================================================
elif page == "ESG Agent Chat":
    st.title("ESG Intelligence Agent")
    st.caption("Ask questions about emissions, ESRS compliance, fleet, GoGreen Plus, and workforce KPIs")

    AGENT_FQN = f"{session.get_current_database()}.ESG.WORLD_DELIVERY_ESG_AGENT"

    sample_qs = [
        "What are our total GHG emissions by scope for FY2025?",
        "Will we hit our SBTi Scope 1&2 target under current trajectory?",
        "Compare BAU vs accelerated scenario for Scope 3 through 2030",
        "What is the most cost-effective decarbonization lever?",
        "What is the GoGreen Plus revenue by customer segment?",
        "How many e-vehicles do we have by drive type?",
        "Generate the ESRS E1-6 disclosure table",
        "Give me the 7 steering KPIs for the latest period",
    ]

    st.markdown("**Sample questions:**")
    cols = st.columns(2)
    for i, q in enumerate(sample_qs):
        if cols[i % 2].button(q, key=f"sq_{i}", use_container_width=True):
            st.session_state["agent_input"] = q

    if "messages" not in st.session_state:
        st.session_state.messages = []

    for msg in st.session_state.messages:
        with st.chat_message(msg["role"]):
            st.markdown(msg["content"])

    prompt = st.chat_input("Ask about World Delivery ESG performance...")
    if "agent_input" in st.session_state and st.session_state.agent_input:
        prompt = st.session_state.pop("agent_input")

    if prompt:
        st.session_state.messages.append({"role": "user", "content": prompt})
        with st.chat_message("user"):
            st.markdown(prompt)

        with st.chat_message("assistant"):
            with st.spinner("Analyzing..."):
                try:
                    import _snowflake
                    resp = _snowflake.send_snow_api_request(
                        "POST",
                        f"/api/v2/cortex/agent:run",
                        {},
                        {},
                        json.dumps({
                            "model": "auto",
                            "agent_fqn": AGENT_FQN,
                            "messages": [{"role": "user", "content": [{"type": "text", "text": prompt}]}],
                            "tools": [{"tool_spec": {"type": "cortex_analyst_text_to_sql", "name": "ESG_Analyst"}}],
                            "tool_resources": {"ESG_Analyst": {"semantic_view": f"{session.get_current_database()}.ESG.WORLD_DELIVERY_ESG_SV"}},
                        }),
                        {},
                        30000,
                    )
                    result = json.loads(resp.get("content", "{}"))
                    # Extract text from streamed response
                    answer_text = ""
                    if isinstance(result, dict) and "message" in result:
                        for item in result["message"].get("content", []):
                            if item.get("type") == "text":
                                answer_text += item["text"]
                    elif isinstance(result, list):
                        for event in result:
                            if isinstance(event, dict):
                                for item in event.get("delta", {}).get("content", []):
                                    if item.get("type") == "text":
                                        answer_text += item.get("text", "")
                    if not answer_text:
                        answer_text = str(result)

                    st.markdown(answer_text)
                    st.session_state.messages.append({"role": "assistant", "content": answer_text})
                except Exception as e:
                    error_msg = f"Agent error: {str(e)}"
                    st.error(error_msg)
                    st.session_state.messages.append({"role": "assistant", "content": error_msg})
