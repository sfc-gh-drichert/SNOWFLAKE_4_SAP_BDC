-- Deploy Confect PetFood Demo Supply Chain Risk semantic view via SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML
-- Co-authored with CoCo
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE CONFECT_PETFOOD_WH;
CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML(
  'CONFECT_PETFOOD_DEMO.SC_RISK_DEMO',
  $$
# Confect PetFood Demo | Supply Chain Risk Intelligence — Cortex Analyst Semantic View
#
# Deploy instructions:
#   1. Run confect_petfood_demo_sc_risk_ice.sql first to create all base tables and views
#   2. Run this file to deploy the semantic view
#
# Narrative:
#   SAP S/4 (via BDC) supplies execution facts. Blue Yonder IBP supplies the plan.
#   External marketplace feeds supply early-warning signals.
#   This semantic view unifies all three so supply planners can ask in plain English.
#
# Scale: Multi-division CPG ~$38B annual revenue
#   Petcare ($20B)       — NovaPet, TailWag, PurrFresh
#   Confectionery ($9B)  — ChocoSnap, NutCrunch, WaferBliss, CocoBar, MaltBurst, StarChoc
#   Food ($5B)           — GrainHarvest, SauceCraft
#   8 plants · 28 suppliers · single-market (EUROPE focus, US secondary)
#   Projected revenue at risk: ~$44M across Halloween + Spring Puppy Season peaks
#
# Demo questions supported:
#   Act 1: "Which confectionery SKUs have a supply coverage gap for Halloween?"
#   Act 2: "What is the total financial exposure from the Halloween supply risk?"
#   Act 2: "Why is the carrier acceptance rate so low on the Abidjan-Rotterdam lane?"
#   Act 2: "What does the external port data show about Rotterdam congestion right now?"
#   Act 3: "Are there any supply risks in European petcare this quarter?"
#   Close:  "Which suppliers can cover the NovaPet protein shortfall?"
#   Global: "Give me a full supply chain risk overview across all divisions and peaks"

name: CONFECT_PETFOOD_SC_RISK_SV
tables:
  - name: RISK_SCORES
    description: >
      Composite supply chain risk dashboard per finished good SKU. Combines SAP BDC
      procurement and inventory data, Blue Yonder IBP demand and supply plan gaps,
      BY TMS transport disruption signals, and external market feeds (commodity prices,
      port congestion, biosecurity alerts). Risk score 0-100; tier = CRITICAL / HIGH /
      MODERATE / LOW. Central entity for supply risk questions.
    base_table:
      database: CONFECT_PETFOOD_DEMO
      schema: SC_RISK_DEMO
      table: V_SUPPLY_RISK_SCORE
    primary_key:
      columns:
        - MATERIAL_ID
        - PLANT
    dimensions:
      - name: material_id
        synonyms: [sku, product code, material, item]
        description: SAP material number / finished good identifier
        expr: MATERIAL_ID
        data_type: VARCHAR
      - name: material_desc
        synonyms: [product name, sku name, description]
        description: Human-readable product description
        expr: MATERIAL_DESC
        data_type: VARCHAR
      - name: division
        synonyms: [business unit, segment]
        description: Business division — CONFECTIONERY, PETCARE, or FOOD
        expr: DIVISION
        data_type: VARCHAR
      - name: brand
        synonyms: [brand name]
        description: >
          Product brand. Confectionery: ChocoSnap, NutCrunch, WaferBliss, CocoBar,
          MaltBurst, StarChoc, Festival. Petcare: NovaPet, TailWag, PurrFresh.
          Food: GrainHarvest, SauceCraft.
        expr: BRAND
        data_type: VARCHAR
      - name: plant
        synonyms: [factory, manufacturing site, production plant]
        description: >
          SAP plant code. NL01=Breda (confectionery hub), GB01=Swindon (UK),
          DE01=Cologne Germany (WaferBliss/CocoBar), US01=Lancaster PA (NA confectionery),
          FR01=Montpellier (NovaPet HQ), NL02=Tilburg (TailWag/PurrFresh),
          US02=Nashville TN (NA petcare), GB02=Kettering (Food).
        expr: PLANT
        data_type: VARCHAR
      - name: peak_event
        synonyms: [seasonal event, season, peak]
        description: Seasonal demand peak driving the risk (HALLOWEEN_2026, SPRING_PUPPY_2027, SPRING_KITTEN_2027, CHRISTMAS_2026)
        expr: PEAK_EVENT
        data_type: VARCHAR
      - name: risk_tier
        synonyms: [risk level, risk category, criticality]
        description: >
          Overall risk classification: CRITICAL (score>=75), HIGH (>=55),
          MODERATE (>=35), LOW (<35)
        expr: RISK_TIER
        data_type: VARCHAR
      - name: at_risk_suppliers
        synonyms: [affected suppliers, at risk vendors, problem suppliers]
        description: Comma-separated list of SAP LIFNR IDs for suppliers driving the risk
        expr: AT_RISK_SUPPLIERS
        data_type: VARCHAR
      - name: biosecurity_alert
        synonyms: [disease alert, H5N1, avian flu, outbreak]
        description: Active biosecurity alert level affecting the supply base (None if not applicable)
        expr: BIOSECURITY_ALERT
        data_type: VARCHAR
    facts:
      - name: composite_risk_score
        synonyms: [risk score, overall risk, supply risk index]
        description: >
          Weighted composite risk score 0-100. Weights: supplier risk 30%,
          transport risk 25%, coverage gap 25%, external news signals 10%,
          commodity market 10%.
        expr: COMPOSITE_RISK_SCORE
        data_type: NUMBER
      - name: supply_shortfall_qty
        synonyms: [shortfall, gap, units at risk, coverage gap quantity]
        description: Units where committed BY supply plan falls short of peak demand forecast
        expr: SUPPLY_SHORTFALL_QTY
        data_type: NUMBER
      - name: revenue_at_risk_usd
        synonyms: [revenue at risk, financial exposure, dollars at risk, value at risk]
        description: Revenue exposure in USD = supply shortfall × wholesale unit price
        expr: REVENUE_AT_RISK_USD
        data_type: NUMBER
      - name: days_of_supply
        synonyms: [days of inventory, DOS, coverage days, stock days]
        description: Current days of finished goods or raw material supply at current consumption rate
        expr: DAYS_OF_SUPPLY
        data_type: NUMBER
      - name: safety_stock_days
        synonyms: [safety stock, target stock days, minimum stock]
        description: Target minimum days of supply per SAP I_PRODUCTPLANT safety stock policy
        expr: SAFETY_STOCK_DAYS
        data_type: NUMBER
      - name: disrupted_load_count
        synonyms: [disrupted shipments, late loads, blocked loads]
        description: Number of BY TMS loads with status LATE, MISSED, or BLOCKED for this material
        expr: DISRUPTED_LOAD_COUNT
        data_type: NUMBER
      - name: commodity_yoy_change_pct
        synonyms: [commodity price change, price inflation, raw material cost change]
        description: Year-on-year % change in the key commodity price for this division (from marketplace feed)
        expr: COMMODITY_YOY_CHANGE_PCT
        data_type: NUMBER

  - name: FINISHED_GOODS_COVERAGE
    description: >
      Weekly supply coverage gap view per SKU — compares Blue Yonder IBP consensus
      plan against demand forecast. Surfaces seasonal coverage shortfalls before
      they show up as SAP delivery failures. Key table for Act 1 of the demo.
    base_table:
      database: CONFECT_PETFOOD_DEMO
      schema: SC_RISK_DEMO
      table: V_SEASONAL_COVERAGE_GAP
    primary_key:
      columns:
        - MATERIAL_ID
    dimensions:
      - name: material_id
        expr: MATERIAL_ID
        data_type: VARCHAR
      - name: material_desc
        expr: MATERIAL_DESC
        data_type: VARCHAR
      - name: division
        expr: DIVISION
        data_type: VARCHAR
      - name: brand
        expr: BRAND
        data_type: VARCHAR
      - name: peak_event
        description: Seasonal peak this coverage analysis is for (HALLOWEEN_2026, SPRING_PUPPY_2027, SPRING_KITTEN_2027, CHRISTMAS_2026)
        expr: PEAK_EVENT
        data_type: VARCHAR
      - name: coverage_status
        synonyms: [coverage risk, supply status, gap status]
        description: CRITICAL / HIGH / MEDIUM / LOW based on shortfall size and days-of-supply vs safety stock
        expr: COVERAGE_STATUS
        data_type: VARCHAR
    facts:
      - name: demand_forecast_qty
        synonyms: [forecast demand, planned demand, peak demand units]
        description: Total BY IBP forecast units across all peak weeks for this seasonal event
        expr: DEMAND_FORECAST_QTY
        data_type: NUMBER
      - name: by_committed_qty
        synonyms: [committed supply, confirmed supply, plan quantity]
        description: Total BY IBP consensus plan committed quantity for the peak period
        expr: BY_COMMITTED_QTY
        data_type: NUMBER
      - name: current_stock_qty
        synonyms: [inventory, stock on hand, current inventory]
        description: Current SAP unrestricted finished goods stock (from BDC PPH_DDL_STOCK_1)
        expr: CURRENT_STOCK_QTY
        data_type: NUMBER
      - name: supply_shortfall_qty
        synonyms: [units short, gap, shortfall]
        description: Forecast demand minus committed supply (positive = at-risk units)
        expr: SUPPLY_SHORTFALL_QTY
        data_type: NUMBER
      - name: revenue_at_risk_usd
        synonyms: [revenue at risk, financial risk, dollars at risk]
        description: Shortfall units × unit wholesale price
        expr: REVENUE_AT_RISK_USD
        data_type: NUMBER
      - name: days_of_supply
        expr: DAYS_OF_SUPPLY
        data_type: NUMBER
      - name: safety_stock_days
        expr: SAFETY_STOCK_DAYS
        data_type: NUMBER

  - name: BOM_RISK
    description: >
      Exploded Bill-of-Material risk — joins SAP BOM, supplier master, stock
      position, and external alerts to identify which raw-material / supplier
      combinations threaten finished goods production.
    base_table:
      database: CONFECT_PETFOOD_DEMO
      schema: SC_RISK_DEMO
      table: V_BOM_RISK_EXPLOSION
    primary_key:
      columns:
        - SUPPLIER_ID
        - FINISHED_GOOD_ID
        - PLANT
    dimensions:
      - name: supplier_id
        synonyms: [vendor id, LIFNR]
        expr: SUPPLIER_ID
        data_type: VARCHAR
      - name: supplier_name
        synonyms: [vendor name, supplier]
        expr: SUPPLIER_NAME
        data_type: VARCHAR
      - name: supplier_country
        expr: SUPPLIER_COUNTRY
        data_type: VARCHAR
      - name: supplier_region
        expr: SUPPLIER_REGION
        data_type: VARCHAR
      - name: credit_rating
        synonyms: [rating, vendor rating]
        expr: CREDIT_RATING
        data_type: VARCHAR
      - name: is_sole_source
        synonyms: [single source, sole supplier]
        expr: IS_SOLE_SOURCE
        data_type: BOOLEAN
      - name: contract_end
        synonyms: [contract expiry, contract expiration]
        expr: CONTRACT_END
        data_type: DATE
      - name: component_id
        synonyms: [raw material id, ingredient id]
        expr: COMPONENT_ID
        data_type: VARCHAR
      - name: component_desc
        synonyms: [raw material, ingredient, component]
        expr: COMPONENT_DESC
        data_type: VARCHAR
      - name: component_is_critical
        synonyms: [critical ingredient, critical component]
        expr: COMPONENT_IS_CRITICAL
        data_type: BOOLEAN
      - name: finished_good_id
        synonyms: [product id, SKU]
        expr: FINISHED_GOOD_ID
        data_type: VARCHAR
      - name: finished_good_desc
        synonyms: [product name, finished product]
        expr: FINISHED_GOOD_DESC
        data_type: VARCHAR
      - name: division
        expr: DIVISION
        data_type: VARCHAR
      - name: brand
        expr: BRAND
        data_type: VARCHAR
      - name: plant
        expr: PLANT
        data_type: VARCHAR
      - name: risk_reason
        synonyms: [why at risk, risk driver, root cause]
        description: >
          Primary risk driver: BIOSECURITY_RESTRICTION, LOW_CREDIT_RATING,
          SOLE_SOURCE_DEPENDENCY, or DELIVERY_DELAY
        expr: RISK_REASON
        data_type: VARCHAR
      - name: risk_event_type
        synonyms: [risk event, outbreak type]
        expr: RISK_EVENT_TYPE
        data_type: VARCHAR
      - name: risk_level
        expr: RISK_LEVEL
        data_type: VARCHAR
    facts:
      - name: safety_stock_gap_days
        synonyms: [stock gap, coverage gap days]
        description: Safety stock target minus current days of supply (positive = below target)
        expr: SAFETY_STOCK_GAP_DAYS
        data_type: NUMBER
      - name: current_days_of_supply
        synonyms: [days of supply, DOS]
        expr: CURRENT_DAYS_OF_SUPPLY
        data_type: NUMBER

  - name: TRANSPORT
    description: >
      Blue Yonder TMS loads enriched with tender acceptance signals and lane data.
      Identifies carrier reliability issues and port-of-origin logistics risk.
    base_table:
      database: CONFECT_PETFOOD_DEMO
      schema: SC_RISK_DEMO
      table: BY_LOADS
    primary_key:
      columns:
        - LOAD_ID
    dimensions:
      - name: load_id
        expr: LOAD_ID
        data_type: VARCHAR
      - name: lane_id
        synonyms: [shipping lane, trade lane, route]
        expr: LANE_ID
        data_type: VARCHAR
      - name: carrier_id
        synonyms: [carrier, shipping line, logistics provider]
        expr: CARRIER_ID
        data_type: VARCHAR
      - name: load_status
        synonyms: [shipment status, delivery status]
        description: >
          Current load status: SCHEDULED, IN_TRANSIT, DELIVERED, LATE, BLOCKED, MISSED
        expr: LOAD_STATUS
        data_type: VARCHAR
      - name: related_po
        synonyms: [purchase order, PO number]
        expr: RELATED_PO
        data_type: VARCHAR
      - name: shipment_date
        synonyms: [ship date, departure date]
        expr: SHIPMENT_DATE
        data_type: DATE
      - name: delivery_date
        synonyms: [arrival date, ETA, expected delivery]
        expr: DELIVERY_DATE
        data_type: DATE
    facts:
      - name: weight_kg
        synonyms: [weight, shipment weight, load weight]
        description: Total weight of the load in kilograms
        expr: WEIGHT_KG
        data_type: NUMBER

  - name: TENDER_EVENTS
    description: >
      Carrier tender acceptance/rejection signals from BY TMS. High rejection or
      silent-decline rates indicate lane-level logistics stress and predict future delays.
    base_table:
      database: CONFECT_PETFOOD_DEMO
      schema: SC_RISK_DEMO
      table: BY_TENDER_EVENTS
    primary_key:
      columns:
        - TENDER_ID
    dimensions:
      - name: tender_id
        expr: TENDER_ID
        data_type: VARCHAR
      - name: load_id
        expr: LOAD_ID
        data_type: VARCHAR
      - name: carrier_id
        synonyms: [carrier, shipping line]
        expr: CARRIER_ID
        data_type: VARCHAR
      - name: response_type
        synonyms: [tender response, acceptance status, carrier response]
        description: >
          Carrier response to tender: ACCEPTED, LATE_ACCEPT, REJECTED, SILENT_DECLINE
        expr: RESPONSE_TYPE
        data_type: VARCHAR
      - name: tender_time
        expr: TENDER_TIME
        data_type: TIMESTAMP_NTZ
      - name: response_time
        expr: RESPONSE_TIME
        data_type: TIMESTAMP_NTZ

  - name: PORT_CONGESTION
    description: >
      External port congestion data. Daily scores per port — congestion_score 1-10,
      wait hours, vessels at anchor, gate throughput %. Identifies logistics
      bottlenecks before they cascade into delivery failures.
    base_table:
      database: CONFECT_PETFOOD_DEMO
      schema: SC_RISK_DEMO
      table: EXT_PORT_CONGESTION
    primary_key:
      columns:
        - REPORT_DATE
        - PORT_CODE
    dimensions:
      - name: report_date
        expr: REPORT_DATE
        data_type: DATE
      - name: port_code
        synonyms: [port, port id]
        expr: PORT_CODE
        data_type: VARCHAR
      - name: port_name
        synonyms: [port, harbor]
        expr: PORT_NAME
        data_type: VARCHAR
      - name: country
        expr: COUNTRY
        data_type: VARCHAR
      - name: alert_level
        synonyms: [congestion alert, port alert]
        description: CRITICAL / HIGH / ELEVATED / NORMAL based on congestion score
        expr: ALERT_LEVEL
        data_type: VARCHAR
    facts:
      - name: congestion_score
        synonyms: [congestion, port score, congestion index]
        description: Port congestion severity 1.0-10.0 (10=gridlocked)
        expr: CONGESTION_SCORE
        data_type: NUMBER
      - name: avg_wait_hours
        synonyms: [wait time, anchorage wait, vessel wait]
        description: Average vessel wait time at anchorage in hours
        expr: AVG_WAIT_HOURS
        data_type: NUMBER
      - name: vessels_at_anchor
        synonyms: [ships waiting, vessels queued]
        description: Number of vessels currently at anchorage awaiting berth
        expr: VESSELS_AT_ANCHOR
        data_type: NUMBER
      - name: gate_throughput_pct
        synonyms: [gate throughput, port capacity, discharge rate]
        description: Gate throughput as % of normal capacity (100%=fully efficient)
        expr: GATE_THROUGHPUT_PCT
        data_type: NUMBER

  - name: COMMODITY_PRICES
    description: >
      Daily commodity spot prices from external marketplace feeds. Covers cocoa,
      sugar, chicken meal, palm oil, and wheat — the key raw material cost drivers.
    base_table:
      database: CONFECT_PETFOOD_DEMO
      schema: SC_RISK_DEMO
      table: EXT_COMMODITY_PRICES
    primary_key:
      columns:
        - PRICE_DATE
        - COMMODITY
    dimensions:
      - name: price_date
        expr: PRICE_DATE
        data_type: DATE
      - name: commodity
        synonyms: [raw material, ingredient, commodity type]
        description: Commodity name — COCOA, SUGAR_WHITE, CHICKEN_MEAL, PALM_OIL, WHEAT
        expr: COMMODITY
        data_type: VARCHAR
      - name: supply_tightness
        synonyms: [market tightness, supply condition]
        description: Market supply condition — TIGHT, NORMAL, or LOOSE
        expr: SUPPLY_TIGHTNESS
        data_type: VARCHAR
      - name: price_unit
        expr: PRICE_UNIT
        data_type: VARCHAR
      - name: currency
        expr: CURRENCY
        data_type: VARCHAR
    facts:
      - name: spot_price
        synonyms: [price, current price, market price]
        description: Daily spot price in stated currency per metric ton
        expr: SPOT_PRICE
        data_type: NUMBER
      - name: yoy_change_pct
        synonyms: [year over year change, price change, inflation rate]
        description: Year-on-year price change percentage
        expr: YOY_CHANGE_PCT
        data_type: NUMBER

  - name: VESSEL_TRACKER
    description: >
      Real-time vessel position and ETA data from external AIS/tracking feed.
      Links vessels to purchase orders for proactive delay detection.
    base_table:
      database: CONFECT_PETFOOD_DEMO
      schema: SC_RISK_DEMO
      table: EXT_VESSEL_TRACKER
    primary_key:
      columns:
        - VESSEL_ID
    dimensions:
      - name: vessel_id
        expr: VESSEL_ID
        data_type: VARCHAR
      - name: vessel_name
        synonyms: [ship name, vessel]
        expr: VESSEL_NAME
        data_type: VARCHAR
      - name: vessel_type
        expr: VESSEL_TYPE
        data_type: VARCHAR
      - name: carrier_id
        expr: CARRIER_ID
        data_type: VARCHAR
      - name: cargo_type
        synonyms: [cargo, commodity carried]
        expr: CARGO_TYPE
        data_type: VARCHAR
      - name: related_po
        synonyms: [purchase order, PO]
        expr: RELATED_PO
        data_type: VARCHAR
      - name: departure_port
        expr: DEPARTURE_PORT
        data_type: VARCHAR
      - name: destination_port
        expr: DESTINATION_PORT
        data_type: VARCHAR
      - name: current_status
        synonyms: [vessel status, position status]
        description: Current vessel status — AT_ANCHOR, IN_TRANSIT, IN_PORT, ARRIVED, SCHEDULED
        expr: CURRENT_STATUS
        data_type: VARCHAR
      - name: last_position_desc
        synonyms: [position, where is the ship, current location]
        description: Human-readable description of current vessel situation
        expr: LAST_POSITION_DESC
        data_type: VARCHAR
    facts:
      - name: delay_days
        synonyms: [days delayed, days late, vessel delay]
        description: Delay vs original ETA in days (negative = ahead of schedule)
        expr: DELAY_DAYS
        data_type: NUMBER
      - name: departure_date
        expr: DEPARTURE_DATE
        data_type: DATE
      - name: original_eta
        synonyms: [planned arrival, original ETA]
        expr: ORIGINAL_ETA
        data_type: DATE
      - name: revised_eta
        synonyms: [new ETA, updated ETA, current ETA]
        expr: REVISED_ETA
        data_type: DATE

  - name: OUTBREAK_ALERTS
    description: >
      Biosecurity and environmental alerts from DGAL, OIE, and national agencies.
      Tracks disease outbreaks (H5N1, FMD), natural disasters, and movement
      restrictions that may block supplier operations.
    base_table:
      database: CONFECT_PETFOOD_DEMO
      schema: SC_RISK_DEMO
      table: EXT_OUTBREAK_ALERTS
    primary_key:
      columns:
        - ALERT_ID
    dimensions:
      - name: alert_id
        expr: ALERT_ID
        data_type: VARCHAR
      - name: alert_date
        expr: ALERT_DATE
        data_type: DATE
      - name: pathogen
        synonyms: [disease, virus, hazard type]
        expr: PATHOGEN
        data_type: VARCHAR
      - name: disease_name
        synonyms: [outbreak name, alert name]
        expr: DISEASE_NAME
        data_type: VARCHAR
      - name: country
        expr: COUNTRY
        data_type: VARCHAR
      - name: region
        expr: REGION
        data_type: VARCHAR
      - name: risk_level
        synonyms: [alert severity, alert level]
        expr: RISK_LEVEL
        data_type: VARCHAR
      - name: movement_restriction
        synonyms: [quarantine, lockdown, trade ban]
        expr: MOVEMENT_RESTRICTION
        data_type: BOOLEAN
      - name: affected_species
        synonyms: [species, crop, livestock]
        expr: AFFECTED_SPECIES
        data_type: VARCHAR
      - name: status
        synonyms: [alert status, current status]
        description: ACTIVE or RESOLVED
        expr: STATUS
        data_type: VARCHAR
      - name: supply_chain_impact
        synonyms: [impact description, what does this affect]
        description: Free-text description of which suppliers and materials are impacted
        expr: SUPPLY_CHAIN_IMPACT
        data_type: VARCHAR

  - name: NEWS_RISK_EVENTS
    description: >
      Curated external news and intelligence events with supply chain risk signals.
      Covers labor disputes, commodity shocks, biosecurity, and logistics disruptions.
    base_table:
      database: CONFECT_PETFOOD_DEMO
      schema: SC_RISK_DEMO
      table: EXT_NEWS_RISK_EVENTS
    primary_key:
      columns:
        - EVENT_ID
    dimensions:
      - name: event_id
        expr: EVENT_ID
        data_type: VARCHAR
      - name: event_date
        expr: EVENT_DATE
        data_type: DATE
      - name: headline
        synonyms: [news headline, event title, what happened]
        expr: HEADLINE
        data_type: VARCHAR
      - name: source
        synonyms: [news source, publication]
        expr: SOURCE
        data_type: VARCHAR
      - name: risk_category
        synonyms: [event type, risk type, category]
        description: LABOR, COMMODITY, BIOSECURITY, or LOGISTICS
        expr: RISK_CATEGORY
        data_type: VARCHAR
      - name: affected_region
        expr: AFFECTED_REGION
        data_type: VARCHAR
      - name: affected_commodity
        expr: AFFECTED_COMMODITY
        data_type: VARCHAR
      - name: severity
        synonyms: [event severity, impact level]
        description: CRITICAL, HIGH, MEDIUM, or LOW
        expr: SEVERITY
        data_type: VARCHAR
      - name: supply_chain_signal
        synonyms: [signal, impact analysis, what it means]
        description: Analyst interpretation of supply chain impact
        expr: SUPPLY_CHAIN_SIGNAL
        data_type: VARCHAR
      - name: related_supplier
        synonyms: [affected supplier, impacted vendor]
        expr: RELATED_SUPPLIER
        data_type: VARCHAR

  - name: SUPPLIERS
    description: >
      SAP Vendor Master from BDC. Contains credit ratings, contract dates,
      sole-source flags, and geographic data for all 28 strategic suppliers.
    base_table:
      database: CONFECT_PETFOOD_DEMO
      schema: SC_RISK_DEMO
      table: I_SUPPLIER
    primary_key:
      columns:
        - SUPPLIER_ID
    dimensions:
      - name: supplier_id
        synonyms: [vendor id, LIFNR, supplier code]
        expr: SUPPLIER_ID
        data_type: VARCHAR
      - name: supplier_name
        synonyms: [vendor name, company name]
        expr: SUPPLIER_NAME
        data_type: VARCHAR
      - name: country
        expr: COUNTRY
        data_type: VARCHAR
      - name: region
        expr: REGION
        data_type: VARCHAR
      - name: supplier_type
        synonyms: [vendor type, category]
        expr: SUPPLIER_TYPE
        data_type: VARCHAR
      - name: credit_rating
        synonyms: [rating, financial rating]
        expr: CREDIT_RATING
        data_type: VARCHAR
      - name: is_sole_source
        synonyms: [single source, sole supplier, no alternative]
        expr: IS_SOLE_SOURCE
        data_type: BOOLEAN
      - name: is_active
        expr: IS_ACTIVE
        data_type: BOOLEAN
      - name: contract_start
        expr: CONTRACT_START
        data_type: DATE
      - name: contract_end
        synonyms: [contract expiry, expiration date]
        expr: CONTRACT_END
        data_type: DATE
      - name: payment_terms_days
        synonyms: [payment terms, days to pay]
        expr: PAYMENT_TERMS_DAYS
        data_type: NUMBER

  - name: PURCHASE_ORDERS
    description: >
      SAP Purchase Order aggregated view (replicated via BDC). Tracks open,
      received, and blocked POs with delivery dates and goods receipt status.
    base_table:
      database: CONFECT_PETFOOD_DEMO
      schema: SC_RISK_DEMO
      table: M_V_POH_AGGR
    primary_key:
      columns:
        - PO_NUMBER
    dimensions:
      - name: po_number
        synonyms: [purchase order, PO, order number]
        expr: PO_NUMBER
        data_type: VARCHAR
      - name: supplier_id
        expr: SUPPLIER_ID
        data_type: VARCHAR
      - name: material_id
        expr: MATERIAL_ID
        data_type: VARCHAR
      - name: plant
        expr: PLANT
        data_type: VARCHAR
      - name: po_status
        synonyms: [order status, PO state]
        description: OPEN, RECEIVED, or BLOCKED
        expr: PO_STATUS
        data_type: VARCHAR
      - name: po_date
        synonyms: [order date, purchase date]
        expr: PO_DATE
        data_type: DATE
      - name: delivery_date
        synonyms: [expected delivery, due date]
        expr: DELIVERY_DATE
        data_type: DATE
      - name: gr_date
        synonyms: [goods receipt date, received date]
        description: Date goods were received (NULL = not yet received)
        expr: GR_DATE
        data_type: DATE
    facts:
      - name: order_qty
        synonyms: [quantity ordered, PO quantity]
        expr: ORDER_QTY
        data_type: NUMBER
      - name: net_value_usd
        synonyms: [PO value, order value, purchase value]
        expr: NET_VALUE_USD
        data_type: NUMBER

  - name: STOCK
    description: >
      SAP stock snapshot from BDC (PPH_DDL_STOCK_1). Current unrestricted stock,
      in-transit, safety stock targets, and days-of-supply per material/plant.
    base_table:
      database: CONFECT_PETFOOD_DEMO
      schema: SC_RISK_DEMO
      table: PPH_DDL_STOCK_1
    primary_key:
      columns:
        - MATERIAL_ID
        - PLANT
    dimensions:
      - name: material_id
        expr: MATERIAL_ID
        data_type: VARCHAR
      - name: plant
        expr: PLANT
        data_type: VARCHAR
      - name: snapshot_date
        expr: SNAPSHOT_DATE
        data_type: DATE
    facts:
      - name: unrestricted_stock
        synonyms: [available stock, free stock, on-hand inventory]
        expr: UNRESTRICTED_STOCK
        data_type: NUMBER
      - name: in_transit_stock
        synonyms: [in transit, on the water, pipeline stock]
        expr: IN_TRANSIT_STOCK
        data_type: NUMBER
      - name: safety_stock
        synonyms: [safety stock level, minimum stock]
        expr: SAFETY_STOCK
        data_type: NUMBER
      - name: daily_consumption
        synonyms: [daily usage, burn rate, daily demand]
        expr: DAILY_CONSUMPTION
        data_type: NUMBER
      - name: days_of_supply
        synonyms: [DOS, days of inventory, coverage days]
        expr: DAYS_OF_SUPPLY
        data_type: NUMBER

  - name: DEMAND_FORECAST
    description: >
      Blue Yonder IBP weekly demand forecast. Shows baseline and seasonal lift
      for each SKU across 14-week rolling horizon. Peak weeks flagged with event name.
    base_table:
      database: CONFECT_PETFOOD_DEMO
      schema: SC_RISK_DEMO
      table: BY_DEMAND_FORECAST
    primary_key:
      columns:
        - MATERIAL_ID
        - WEEK_START
    dimensions:
      - name: material_id
        expr: MATERIAL_ID
        data_type: VARCHAR
      - name: week_start
        synonyms: [week, forecast week, period]
        expr: WEEK_START
        data_type: DATE
      - name: is_peak_week
        synonyms: [peak, seasonal peak]
        expr: IS_PEAK_WEEK
        data_type: BOOLEAN
      - name: peak_event
        synonyms: [season, event, seasonal event]
        expr: PEAK_EVENT
        data_type: VARCHAR
      - name: forecast_version
        expr: FORECAST_VERSION
        data_type: VARCHAR
    facts:
      - name: forecast_qty
        synonyms: [forecast, demand forecast, predicted demand]
        expr: FORECAST_QTY
        data_type: NUMBER
      - name: baseline_qty
        synonyms: [baseline, normal demand]
        expr: BASELINE_QTY
        data_type: NUMBER
      - name: seasonal_lift_pct
        synonyms: [lift, seasonal uplift, peak multiplier]
        description: Percentage demand increase above baseline during peak weeks
        expr: SEASONAL_LIFT_PCT
        data_type: NUMBER

verified_queries:
  # === ACT 1: SEASONAL COVERAGE GAP ===
  - name: halloween_coverage_gap
    question: "Which confectionery SKUs have a supply coverage gap for Halloween?"
    verified_at: 1787356800
    sql: |
      SELECT
          MATERIAL_ID,
          MATERIAL_DESC,
          BRAND,
          COVERAGE_STATUS,
          DEMAND_FORECAST_QTY,
          BY_COMMITTED_QTY,
          SUPPLY_SHORTFALL_QTY,
          REVENUE_AT_RISK_USD,
          DAYS_OF_SUPPLY,
          SAFETY_STOCK_DAYS
      FROM SC_RISK_DEMO.V_SEASONAL_COVERAGE_GAP
      WHERE PEAK_EVENT = 'HALLOWEEN_2026'
        AND DIVISION = 'CONFECTIONERY'
      ORDER BY REVENUE_AT_RISK_USD DESC

  - name: halloween_total_exposure
    question: "What is the total financial exposure from the Halloween supply risk?"
    verified_at: 1787356800
    sql: |
      SELECT
          DIVISION,
          COUNT(DISTINCT MATERIAL_ID) AS SKUS_AT_RISK,
          SUM(SUPPLY_SHORTFALL_QTY) AS TOTAL_SHORTFALL_UNITS,
          SUM(REVENUE_AT_RISK_USD) AS TOTAL_REVENUE_AT_RISK_USD,
          AVG(DAYS_OF_SUPPLY) AS AVG_DAYS_OF_SUPPLY
      FROM SC_RISK_DEMO.V_SEASONAL_COVERAGE_GAP
      WHERE PEAK_EVENT = 'HALLOWEEN_2026'
        AND SUPPLY_SHORTFALL_QTY > 0
      GROUP BY DIVISION
      ORDER BY TOTAL_REVENUE_AT_RISK_USD DESC

  # === ACT 2: LOGISTICS & TRANSPORT ===
  - name: carrier_acceptance_abidjan_rotterdam
    question: "Why is the carrier acceptance rate so low on the Abidjan-Rotterdam lane?"
    verified_at: 1787356800
    sql: |
      SELECT
          te.CARRIER_ID,
          te.RESPONSE_TYPE,
          te.TENDER_TIME,
          te.RESPONSE_TIME,
          l.LOAD_STATUS,
          l.RELATED_PO,
          DATEDIFF('hour', te.TENDER_TIME, COALESCE(te.RESPONSE_TIME, CURRENT_TIMESTAMP())) AS HOURS_TO_RESPOND
      FROM SC_RISK_DEMO.BY_TENDER_EVENTS te
      JOIN SC_RISK_DEMO.BY_LOADS l ON l.LOAD_ID = te.LOAD_ID
      WHERE l.LANE_ID = 'LANE-CIABJ-NLRTM'
      ORDER BY te.TENDER_TIME DESC

  - name: rotterdam_congestion
    question: "What does the external port data show about Rotterdam congestion right now?"
    verified_at: 1787356800
    sql: |
      SELECT
          REPORT_DATE,
          CONGESTION_SCORE,
          AVG_WAIT_HOURS,
          VESSELS_AT_ANCHOR,
          GATE_THROUGHPUT_PCT,
          ALERT_LEVEL
      FROM SC_RISK_DEMO.EXT_PORT_CONGESTION
      WHERE PORT_CODE = 'NLRTM'
      ORDER BY REPORT_DATE DESC
      LIMIT 14

  - name: vessel_delays
    question: "Which vessels are currently delayed and what cargo are they carrying?"
    verified_at: 1787356800
    sql: |
      SELECT
          VESSEL_NAME,
          CARRIER_ID,
          CARGO_TYPE,
          RELATED_PO,
          DEPARTURE_PORT,
          DESTINATION_PORT,
          ORIGINAL_ETA,
          REVISED_ETA,
          DELAY_DAYS,
          CURRENT_STATUS,
          LAST_POSITION_DESC
      FROM SC_RISK_DEMO.EXT_VESSEL_TRACKER
      WHERE DELAY_DAYS > 0
      ORDER BY DELAY_DAYS DESC

  # === ACT 3: PETCARE / BIOSECURITY ===
  - name: petcare_supply_risk
    question: "Are there any supply risks in European petcare this quarter?"
    verified_at: 1787356800
    sql: |
      SELECT
          r.MATERIAL_ID,
          r.MATERIAL_DESC,
          r.BRAND,
          r.RISK_TIER,
          r.COMPOSITE_RISK_SCORE,
          r.AT_RISK_SUPPLIERS,
          r.BIOSECURITY_ALERT,
          r.DAYS_OF_SUPPLY,
          r.SAFETY_STOCK_DAYS,
          r.SUPPLY_SHORTFALL_QTY,
          r.REVENUE_AT_RISK_USD
      FROM SC_RISK_DEMO.V_SUPPLY_RISK_SCORE r
      WHERE r.DIVISION = 'PETCARE'
        AND r.PLANT IN ('FR01','NL02')
      ORDER BY r.COMPOSITE_RISK_SCORE DESC

  - name: novapet_protein_alternatives
    question: "Which suppliers can cover the NovaPet protein shortfall?"
    verified_at: 1787356800
    sql: |
      SELECT
          s.SUPPLIER_ID,
          s.SUPPLIER_NAME,
          s.COUNTRY,
          s.REGION,
          s.CREDIT_RATING,
          s.IS_SOLE_SOURCE,
          s.CONTRACT_END,
          CASE
              WHEN oa.STATUS = 'ACTIVE' THEN 'BLOCKED - ' || oa.DISEASE_NAME
              ELSE 'AVAILABLE'
          END AS AVAILABILITY_STATUS
      FROM SC_RISK_DEMO.I_SUPPLIER s
      LEFT JOIN SC_RISK_DEMO.EXT_OUTBREAK_ALERTS oa
          ON oa.COUNTRY = s.COUNTRY
          AND oa.REGION = s.REGION
          AND oa.STATUS = 'ACTIVE'
          AND oa.RISK_LEVEL IN ('HIGH','CRITICAL')
      WHERE s.SUPPLIER_TYPE IN ('Poultry Protein','Animal Protein')
        AND s.IS_ACTIVE = TRUE
      ORDER BY AVAILABILITY_STATUS, s.CREDIT_RATING

  - name: h5n1_outbreak_status
    question: "What is the current H5N1 outbreak status affecting our suppliers?"
    verified_at: 1787356800
    sql: |
      SELECT
          ALERT_ID,
          ALERT_DATE,
          DISEASE_NAME,
          COUNTRY,
          REGION,
          RISK_LEVEL,
          MOVEMENT_RESTRICTION,
          STATUS,
          SUPPLY_CHAIN_IMPACT
      FROM SC_RISK_DEMO.EXT_OUTBREAK_ALERTS
      WHERE PATHOGEN = 'H5N1 HPAI'
      ORDER BY ALERT_DATE DESC

  - name: cocoa_force_majeure_impact
    question: "What is the impact of the Atlantic Origins force majeure on our supply chain?"
    verified_at: 1787356800
    sql: |
      SELECT
          bi.BOM_ID,
          b.MATERIAL_ID,
          p.MATERIAL_DESC,
          p.BRAND,
          b.PLANT,
          bi.COMPONENT_DESC,
          bi.COMPONENT_QTY,
          s.SUPPLIER_NAME,
          s.CREDIT_RATING,
          st.DAYS_OF_SUPPLY,
          pp.SAFETY_STOCK_DAYS
      FROM SC_RISK_DEMO.I_BILLOFMATERIALITEM bi
      JOIN SC_RISK_DEMO.I_BILLOFMATERIAL b ON b.BOM_ID = bi.BOM_ID
      JOIN SC_RISK_DEMO.I_PRODUCT p ON p.MATERIAL_ID = b.MATERIAL_ID
      JOIN SC_RISK_DEMO.I_SUPPLIER s ON s.SUPPLIER_ID = bi.PREFERRED_SUPPLIER
      JOIN SC_RISK_DEMO.I_PRODUCTPLANT pp ON pp.MATERIAL_ID = b.MATERIAL_ID AND pp.PLANT = b.PLANT
      LEFT JOIN SC_RISK_DEMO.PPH_DDL_STOCK_1 st ON st.MATERIAL_ID = b.MATERIAL_ID AND st.PLANT = b.PLANT
      WHERE bi.PREFERRED_SUPPLIER = 'LIFNR-CI-003'
      ORDER BY p.DIVISION, p.BRAND

  - name: blocked_purchase_orders
    question: "Which purchase orders are currently blocked and why?"
    verified_at: 1787356800
    sql: |
      SELECT
          po.PO_NUMBER,
          po.SUPPLIER_ID,
          s.SUPPLIER_NAME,
          po.MATERIAL_ID,
          p.MATERIAL_DESC,
          p.BRAND,
          po.PLANT,
          po.ORDER_QTY,
          po.NET_VALUE_USD,
          po.DELIVERY_DATE,
          po.PO_STATUS,
          COALESCE(oa.DISEASE_NAME, nr.HEADLINE) AS BLOCK_REASON
      FROM SC_RISK_DEMO.M_V_POH_AGGR po
      JOIN SC_RISK_DEMO.I_SUPPLIER s ON s.SUPPLIER_ID = po.SUPPLIER_ID
      JOIN SC_RISK_DEMO.I_PRODUCT p ON p.MATERIAL_ID = po.MATERIAL_ID
      LEFT JOIN SC_RISK_DEMO.EXT_OUTBREAK_ALERTS oa
          ON oa.COUNTRY = s.COUNTRY AND oa.STATUS = 'ACTIVE' AND oa.RISK_LEVEL IN ('HIGH','CRITICAL')
      LEFT JOIN SC_RISK_DEMO.EXT_NEWS_RISK_EVENTS nr
          ON nr.RELATED_SUPPLIER = po.SUPPLIER_ID AND nr.SEVERITY = 'CRITICAL'
      WHERE po.PO_STATUS = 'BLOCKED'
      ORDER BY po.NET_VALUE_USD DESC

  - name: cocoa_price_trend
    question: "What is the trend in cocoa prices over the last 90 days?"
    verified_at: 1787356800
    sql: |
      SELECT
          PRICE_DATE,
          SPOT_PRICE,
          SUPPLY_TIGHTNESS,
          YOY_CHANGE_PCT
      FROM SC_RISK_DEMO.EXT_COMMODITY_PRICES
      WHERE COMMODITY = 'COCOA'
      ORDER BY PRICE_DATE DESC

  # === COMBINED RISK OVERVIEW ===
  - name: full_risk_dashboard
    question: "Give me a full supply chain risk overview across all divisions and peaks"
    verified_at: 1787356800
    sql: |
      SELECT
          DIVISION,
          BRAND,
          MATERIAL_DESC,
          PEAK_EVENT,
          RISK_TIER,
          COMPOSITE_RISK_SCORE,
          REVENUE_AT_RISK_USD,
          DAYS_OF_SUPPLY,
          SAFETY_STOCK_DAYS,
          AT_RISK_SUPPLIERS,
          BIOSECURITY_ALERT,
          DISRUPTED_LOAD_COUNT
      FROM SC_RISK_DEMO.V_SUPPLY_RISK_SCORE
      WHERE RISK_TIER IN ('CRITICAL','HIGH','MODERATE')
      ORDER BY COMPOSITE_RISK_SCORE DESC

$$);


-- =============================================================
-- CORTEX AGENT
-- Supply Chain Risk Intelligence Agent backed by the semantic view above.
-- =============================================================

CREATE OR REPLACE AGENT CONFECT_PETFOOD_DEMO.SC_RISK_DEMO.CONFECT_PETFOOD_SC_RISK_AGENT
  COMMENT = 'Supply chain risk intelligence agent for Confect PetFood — co-authored with CoCo'
  PROFILE = '{"display_name": "SC Risk Intelligence", "color": "blue"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto

  orchestration:
    tool_not_accessible: accept
    budget:
      seconds: 60
      tokens: 32000

  instructions:
    response: >
      You are a supply chain risk intelligence agent for Confect PetFood,
      a multi-division CPG company ($38B revenue) with Petcare, Confectionery,
      and Food divisions. Answer questions about supplier risk, demand forecasts,
      inventory levels, transport disruptions, biosecurity alerts, and revenue
      at risk. Be concise. Use tables for multi-row results. Highlight critical
      risks prominently. When discussing risk scores, explain the key drivers.
    orchestration: >
      Use the sc_risk_analyst tool for all data questions about supply chain risk,
      inventory, demand, suppliers, transport, commodity prices, and outbreak alerts.
    sample_questions:
      - question: "Which confectionery SKUs have a supply coverage gap for Halloween?"
      - question: "What is the total financial exposure from the Halloween supply risk?"
      - question: "Are there any supply risks in European petcare this quarter?"
      - question: "Which vessels are currently delayed and what cargo are they carrying?"
      - question: "Give me a full supply chain risk overview across all divisions and peaks"

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "sc_risk_analyst"
        description: >
          Converts natural language questions to SQL against the Confect PetFood
          supply chain risk semantic view. Covers risk scores, coverage gaps,
          BOM risk explosions, transport loads, outbreak alerts, commodity prices,
          vessel tracking, purchase orders, stock positions, and demand forecasts.
    - tool_spec:
        type: "data_to_chart"
        name: "data_to_chart"
        description: "Generates charts and visualizations from query results"

  tool_resources:
    sc_risk_analyst:
      semantic_view: "CONFECT_PETFOOD_DEMO.SC_RISK_DEMO.CONFECT_PETFOOD_SC_RISK_SV"
  $$;
