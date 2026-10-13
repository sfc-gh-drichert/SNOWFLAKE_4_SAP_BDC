#!/usr/bin/env python3
"""
Build docs/confect-petfood/data.js for the static GitHub Pages preview.

Static tables are parsed straight from the INSERT ... VALUES statements in
01_confect_petfood_demo_sc_risk_ice.sql. The three generated series
(BY_DEMAND_FORECAST, EXT_COMMODITY_PRICES, EXT_PORT_CONGESTION) and the three
analytic views (V_SEASONAL_COVERAGE_GAP, V_SUPPLY_RISK_SCORE and the inputs to
it) are re-implemented here with the same logic as the SQL.

UNIFORM(..., RANDOM()) noise uses a fixed seed, so generated values differ from
any live deployment but stay stable between builds.

Usage:
    python3 CPG_S4_BLUEY_CONFECT_PETFOOD/static_site/build_data.py
"""

import json
import random
import re
from collections import defaultdict
from datetime import date, timedelta
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

HERE = Path(__file__).resolve().parent
SQL_FILE = HERE.parent / "01_confect_petfood_demo_sc_risk_ice.sql"
OUT_FILE = HERE.parent.parent / "docs" / "confect-petfood" / "data.js"

AS_OF = date(2026, 8, 20)   # snapshot date hard-coded throughout the demo SQL
rng = random.Random(20260820)


# ---------------------------------------------------------------------------
# SQL parsing
# ---------------------------------------------------------------------------

def table_columns(sql, table):
    """Column names from a CREATE ... TABLE <table> ( ... ) block."""
    m = re.search(r"CREATE OR REPLACE\s+(?:ICEBERG\s+)?TABLE\s+%s\s*\(" % table, sql)
    cols = []
    for line in sql[m.end():].splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("--"):
            continue
        if stripped.startswith(")"):
            break
        name = stripped.split()[0]
        if name.upper() != "PRIMARY":
            cols.append(name)
    return cols


def _literal(tok):
    t = tok.strip()
    if t.upper() == "NULL":
        return None
    if t.upper() == "TRUE":
        return True
    if t.upper() == "FALSE":
        return False
    return Decimal(t)


def table_rows(sql, table):
    """Rows from INSERT INTO <table> VALUES (...), (...);  as dicts."""
    cols = table_columns(sql, table)
    m = re.search(r"INSERT INTO\s+%s\s+VALUES" % table, sql)
    i, n = m.end(), len(sql)
    rows, row, tok, had_str = [], None, "", False
    while i < n:
        c = sql[i]
        if row is None:
            if c == ";":
                break
            if sql.startswith("--", i):
                i = sql.find("\n", i)
                continue
            if c == "(":
                row, tok, had_str = [], "", False
            i += 1
            continue
        if c == "'":
            j, buf = i + 1, []
            while True:
                if sql[j] == "'":
                    if sql[j + 1] == "'":
                        buf.append("'")
                        j += 2
                        continue
                    break
                buf.append(sql[j])
                j += 1
            row.append("".join(buf))
            had_str = True
            i = j + 1
            continue
        if c in ",)":
            if not had_str:
                row.append(_literal(tok))
            tok, had_str = "", False
            if c == ")":
                rows.append(dict(zip(cols, row)))
                row = None
            i += 1
            continue
        tok += c
        i += 1
    return rows


# ---------------------------------------------------------------------------
# Generated series (mirror the INSERT ... WITH ... GENERATOR statements)
# ---------------------------------------------------------------------------

def uniform_int(lo, hi):
    return rng.randint(lo, hi)


def uniform_float(lo, hi):
    return rng.uniform(lo, hi)


def round_half_up(x, places=0):
    q = Decimal(1).scaleb(-places)
    return Decimal(x).quantize(q, rounding=ROUND_HALF_UP)


FORECAST_SKUS = [
    # material_id, base_qty, peak_start, peak_end, lift, peak_event
    ("CS-HWEEN-400G", 5000, "2026-10-06", "2026-10-27", "2.8", "HALLOWEEN_2026"),
    ("CSP-HWEEN-400G", 4000, "2026-10-06", "2026-10-27", "2.5", "HALLOWEEN_2026"),
    ("CSS-US-400G", 4000, "2026-10-06", "2026-10-27", "3.0", "HALLOWEEN_2026"),
    ("NC-HWEEN-500G", 4500, "2026-10-06", "2026-10-27", "2.6", "HALLOWEEN_2026"),
    ("WB-HWEEN-450G", 3000, "2026-10-06", "2026-10-27", "2.2", "HALLOWEEN_2026"),
    ("MB-HWEEN-350G", 2500, "2026-10-13", "2026-10-27", "1.8", "HALLOWEEN_2026"),
    ("CB-HWEEN-260G", 2000, "2026-10-13", "2026-10-27", "1.5", "HALLOWEEN_2026"),
    ("FEST-XMAS-650G", 3000, "2026-11-09", "2026-12-14", "3.2", "CHRISTMAS_2026"),
    ("STAR-XMAS-450G", 2500, "2026-11-09", "2026-12-14", "2.8", "CHRISTMAS_2026"),
    ("CS-XMAS-400G", 4000, "2026-11-09", "2026-12-14", "3.0", "CHRISTMAS_2026"),
    ("NC-XMAS-500G", 4500, "2026-11-09", "2026-12-14", "2.8", "CHRISTMAS_2026"),
    ("CS-DIWALI-400G", 1500, "2026-10-05", "2026-11-02", "2.8", "DIWALI_2026"),
    ("NC-DIWALI-500G", 1200, "2026-10-05", "2026-11-02", "2.5", "DIWALI_2026"),
    ("CB-DIWALI-300G", 800, "2026-10-05", "2026-11-02", "2.0", "DIWALI_2026"),
    ("CS-CNY-400G", 1200, "2027-01-19", "2027-02-08", "3.0", "CNY_2027"),
    ("NC-CNY-500G", 1200, "2027-01-19", "2027-02-08", "2.8", "CNY_2027"),
    ("FEST-CNY-650G", 1500, "2027-01-19", "2027-02-08", "3.5", "CNY_2027"),
    ("NP-PUP-MED-4KG", 700, "2027-02-03", "2027-03-31", "1.4", "SPRING_PUPPY_2027"),
    ("NP-KIT-2KG", 500, "2027-02-03", "2027-03-31", "1.6", "SPRING_KITTEN_2027"),
]


def build_forecast():
    rows = []
    weeks = [date(2026, 8, 18) + timedelta(weeks=k) for k in range(26)]
    for wk in weeks:
        for mat, base, ps, pe, lift, event in FORECAST_SKUS:
            lift = Decimal(lift)
            peak = date.fromisoformat(ps) <= wk <= date.fromisoformat(pe)
            qty = round_half_up(base * (1 + (lift if peak else 0)) + uniform_int(-500, 500))
            rows.append({
                "MATERIAL_ID": mat, "WEEK_START": wk.isoformat(),
                "FORECAST_QTY": qty, "BASELINE_QTY": Decimal(base),
                "SEASONAL_LIFT_PCT": lift * 100 if peak else Decimal(0),
                "IS_PEAK_WEEK": peak, "PEAK_EVENT": event if peak else None,
                "FORECAST_VERSION": "IBP-2026-AUG-W3",
            })
    return rows


COMMODITIES = [
    # commodity, base_spot, trend_factor, unit, currency, yoy_change, tightness
    ("COCOA", "9250.00", "0.18", "USD/MT", "USD", "28.4", "TIGHT"),
    ("SUGAR_WHITE", "520.00", "-0.04", "USD/MT", "USD", "-3.2", "NORMAL"),
    ("CHICKEN_MEAL", "1380.00", "0.22", "EUR/MT", "EUR", "31.5", "TIGHT"),
    ("PALM_OIL", "968.00", "0.06", "USD/MT", "USD", "8.2", "NORMAL"),
    ("WHEAT", "242.00", "-0.08", "USD/MT", "USD", "-5.1", "LOOSE"),
]


def build_commodity_prices():
    rows = []
    for k in range(90):
        d = AS_OF - timedelta(days=k)
        for com, base, trend, unit, cur, yoy, tight in COMMODITIES:
            spot = Decimal(base) * (1 + Decimal(trend) * Decimal(k) / 90) + uniform_int(-50, 50)
            rows.append({
                "PRICE_DATE": d.isoformat(), "COMMODITY": com,
                "SPOT_PRICE": round_half_up(spot, 2), "SUPPLY_TIGHTNESS": tight,
                "PRICE_UNIT": unit, "CURRENCY": cur,
                "YOY_CHANGE_PCT": round_half_up(Decimal(yoy) + Decimal(str(uniform_float(-2.0, 2.0))), 2),
            })
    return rows


PORTS = [
    # code, name, country, base_score, base_wait, base_vessels, base_throughput, trend
    ("NLRTM", "Port of Rotterdam", "Netherlands", "7.2", "48.0", 24, "78.0", "0.08"),
    ("CIABJ", "Port of Abidjan", "Ivory Coast", "5.8", "36.0", 18, "84.0", "0.05"),
    ("BEANR", "Port of Antwerp", "Belgium", "4.1", "22.0", 12, "91.0", "-0.02"),
    ("GBFXT", "Port of Felixstowe", "United Kingdom", "3.8", "18.0", 10, "93.0", "0.01"),
    ("USNYC", "Port of New York/NJ", "United States", "4.5", "26.0", 15, "88.0", "0.04"),
    ("NOSVG", "Port of Bergen", "Norway", "1.8", "8.0", 4, "97.0", "-0.01"),
]


def build_port_congestion():
    rows = []
    for k in range(45):
        d = AS_OF - timedelta(days=k)
        for code, name, country, score, wait, vessels, thru, trend in PORTS:
            score, wait, thru, trend = map(Decimal, (score, wait, thru, trend))
            level = score + trend
            rows.append({
                "REPORT_DATE": d.isoformat(), "PORT_CODE": code, "PORT_NAME": name, "COUNTRY": country,
                "CONGESTION_SCORE": round_half_up(score + Decimal(str(uniform_float(-0.5, 0.5))) + trend, 1),
                "AVG_WAIT_HOURS": round_half_up(wait + uniform_int(-4, 4) + trend * 12, 1),
                "VESSELS_AT_ANCHOR": round_half_up(vessels + uniform_int(-3, 3)),
                "GATE_THROUGHPUT_PCT": round_half_up(thru + uniform_int(-3, 3) - trend * 5, 1),
                "ALERT_LEVEL": "CRITICAL" if level > 7 else "HIGH" if level > 5 else "ELEVATED" if level > 3 else "NORMAL",
            })
    return rows


# ---------------------------------------------------------------------------
# Analytic views (same joins and CASE logic as the SQL, including fan-out)
# ---------------------------------------------------------------------------

def mean(values):
    values = list(values)
    return sum(values, Decimal(0)) / len(values)


def lt(a, b):
    """SQL a < b with NULL semantics."""
    return a is not None and b is not None and a < b


def v_seasonal_coverage_gap(t):
    """One row per material x peak event; S&OP commitment pro-rated to the peak weeks."""
    products = {p["MATERIAL_ID"]: p for p in t["I_PRODUCT"]}
    horizon = defaultdict(set)
    peak = {}
    for f in t["BY_DEMAND_FORECAST"]:
        horizon[f["MATERIAL_ID"]].add(f["WEEK_START"])
        if not f["IS_PEAK_WEEK"]:
            continue
        agg = peak.setdefault((f["MATERIAL_ID"], f["PEAK_EVENT"]), {"forecast": Decimal(0), "weeks": 0})
        agg["forecast"] += f["FORECAST_QTY"]
        agg["weeks"] += 1
    committed = defaultdict(Decimal)
    for c in t["BY_CONSENSUS_PLAN"]:
        committed[c["MATERIAL_ID"]] += c["COMMITTED_QTY"]
    stock = {(s["MATERIAL_ID"], s["PLANT"]): s for s in t["PPH_DDL_STOCK_1"]}
    material_stock = {}
    for pp in t["I_PRODUCTPLANT"]:
        ms = material_stock.setdefault(pp["MATERIAL_ID"], {"dos": [], "ssd": []})
        st = stock.get((pp["MATERIAL_ID"], pp["PLANT"]))
        if st and st["DAYS_OF_SUPPLY"] is not None:
            ms["dos"].append(st["DAYS_OF_SUPPLY"])
        ms["ssd"].append(pp["SAFETY_STOCK_DAYS"])

    rows = []
    for (mat, event), agg in peak.items():
        if mat not in products:
            continue
        p = products[mat]
        cp = committed.get(mat)
        peak_committed = round_half_up(cp * agg["weeks"] / len(horizon[mat])) if cp is not None else Decimal(0)
        ms = material_stock.get(mat, {"dos": [], "ssd": []})
        dos = min(ms["dos"]) if ms["dos"] else None
        ssd = max(ms["ssd"]) if ms["ssd"] else None
        short = max(agg["forecast"] - peak_committed, Decimal(0))
        if short > 0 and lt(dos, ssd):
            status = "CRITICAL"
        elif short > 0:
            status = "HIGH"
        elif lt(dos, ssd):
            status = "MEDIUM"
        else:
            status = "LOW"
        rows.append({
            "MATERIAL_ID": mat, "PEAK_EVENT": event,
            "SUPPLY_SHORTFALL_QTY": short,
            "REVENUE_AT_RISK_USD": round_half_up(short * p["UNIT_WHOLESALE_USD"]),
            "DAYS_OF_SUPPLY": dos if dos is not None else Decimal(0),
            "SAFETY_STOCK_DAYS": ssd,
            "COVERAGE_STATUS": status,
        })
    return rows


def v_supply_risk_score(t, coverage):
    suppliers = {s["SUPPLIER_ID"]: s for s in t["I_SUPPLIER"]}
    boms = {b["BOM_ID"]: b for b in t["I_BILLOFMATERIAL"]}
    items_by_bom = defaultdict(list)
    for bi in t["I_BILLOFMATERIALITEM"]:
        items_by_bom[bi["BOM_ID"]].append(bi)
    active_alerts = [a for a in t["EXT_OUTBREAK_ALERTS"] if a["STATUS"] == "ACTIVE"]

    # supplier_risk
    sup_scores, sup_bio, sup_ids = defaultdict(list), defaultdict(list), defaultdict(set)
    for b in t["I_BILLOFMATERIAL"]:
        for bi in items_by_bom[b["BOM_ID"]]:
            if not bi["IS_CRITICAL"]:
                continue
            s = suppliers[bi["PREFERRED_SUPPLIER"]]
            for oa in [a for a in active_alerts if a["COUNTRY"] == s["COUNTRY"]] or [None]:
                level = oa["RISK_LEVEL"] if oa else None
                if level == "CRITICAL":
                    score = 95
                elif level == "HIGH":
                    score = 80
                elif s["CREDIT_RATING"] in ("B-", "C") and s["IS_SOLE_SOURCE"]:
                    score = 85
                elif s["CREDIT_RATING"] == "B":
                    score = 60
                elif s["IS_SOLE_SOURCE"]:
                    score = 50
                else:
                    score = 20
                mat = b["MATERIAL_ID"]
                sup_scores[mat].append(score)
                if oa:
                    sup_bio[mat].append(level)
                sup_ids[mat].add(s["SUPPLIER_ID"])
    supplier_risk = {m: {"score": max(v), "bio": max(sup_bio[m]) if sup_bio[m] else None,
                         "ids": ", ".join(sorted(sup_ids[m]))} for m, v in sup_scores.items()}

    # transport_risk (open POs only)
    resp_score = {"SILENT_DECLINE": 90, "REJECTED": 70, "LATE_ACCEPT": 45}
    tr_scores, tr_disrupted = defaultdict(list), defaultdict(int)
    for po in t["M_V_POH_AGGR"]:
        if po["GR_DATE"] is not None:
            continue
        for ld in [l for l in t["BY_LOADS"] if l["RELATED_PO"] == po["PO_NUMBER"]] or [None]:
            tenders = [e for e in t["BY_TENDER_EVENTS"] if ld and e["LOAD_ID"] == ld["LOAD_ID"]] or [None]
            for te in tenders:
                tr_scores[po["MATERIAL_ID"]].append(Decimal(resp_score.get(te["RESPONSE_TYPE"] if te else None, 15)))
                if ld and ld["LOAD_STATUS"] in ("LATE", "MISSED", "BLOCKED"):
                    tr_disrupted[po["MATERIAL_ID"]] += 1
    transport_risk = {m: {"score": mean(v), "disrupted": tr_disrupted[m]} for m, v in tr_scores.items()}

    # coverage_risk
    cov_score = {"CRITICAL": 95, "HIGH": 75, "MEDIUM": 45}
    coverage_by_mat = defaultdict(list)
    for c in coverage:
        coverage_by_mat[c["MATERIAL_ID"]].append(dict(c, score=cov_score.get(c["COVERAGE_STATUS"], 15)))

    # external_risk
    sev_score = {"CRITICAL": 90, "HIGH": 70, "MEDIUM": 40}
    ext = defaultdict(list)
    for nr in t["EXT_NEWS_RISK_EVENTS"]:
        if nr["SEVERITY"] not in sev_score:
            continue
        for bi in t["I_BILLOFMATERIALITEM"]:
            if bi["PREFERRED_SUPPLIER"] == nr["RELATED_SUPPLIER"]:
                ext[boms[bi["BOM_ID"]]["MATERIAL_ID"]].append(sev_score[nr["SEVERITY"]])
    external_risk = {m: max(v) for m, v in ext.items()}

    # commodity_risk (last 7 days)
    division_of = {"COCOA": "CONFECTIONERY", "CHICKEN_MEAL": "PETCARE"}
    cutoff = (AS_OF - timedelta(days=7)).isoformat()
    com_scores, com_yoy = defaultdict(list), defaultdict(list)
    for cp in t["EXT_COMMODITY_PRICES"]:
        div = division_of.get(cp["COMMODITY"])
        if cp["PRICE_DATE"] >= cutoff and div:
            com_scores[div].append(65 if cp["SUPPLY_TIGHTNESS"] == "TIGHT" else 20)
            com_yoy[div].append(cp["YOY_CHANGE_PCT"])
    commodity_risk = {d: {"score": max(v), "yoy": mean(com_yoy[d])} for d, v in com_scores.items()}

    rows = []
    plants = defaultdict(list)
    for pp in t["I_PRODUCTPLANT"]:
        plants[pp["MATERIAL_ID"]].append(pp)
    for p in t["I_PRODUCT"]:
        mat = p["MATERIAL_ID"]
        sr, tr = supplier_risk.get(mat), transport_risk.get(mat)
        er, cm = external_risk.get(mat), commodity_risk.get(p["DIVISION"])
        n_plants = len(plants[mat]) * len(coverage_by_mat.get(mat) or [None])
        for pp in plants[mat]:
            for cr in coverage_by_mat.get(mat) or [None]:
                composite = round_half_up(
                    Decimal(sr["score"] if sr else 20) * Decimal("0.30")
                    + (tr["score"] if tr else Decimal(20)) * Decimal("0.25")
                    + Decimal(cr["score"] if cr else 15) * Decimal("0.25")
                    + Decimal(er if er is not None else 10) * Decimal("0.10")
                    + Decimal(cm["score"] if cm else 10) * Decimal("0.10"), 1)
                tier = ("CRITICAL" if composite >= 75 else "HIGH" if composite >= 55
                        else "MODERATE" if composite >= 35 else "LOW")
                rows.append({
                    "MATERIAL_ID": mat, "MATERIAL_DESC": p["MATERIAL_DESC"], "DIVISION": p["DIVISION"],
                    "BRAND": p["BRAND"], "PLANT": pp["PLANT"],
                    "PEAK_EVENT": cr["PEAK_EVENT"] if cr else None,
                    "COMPOSITE_RISK_SCORE": composite, "RISK_TIER": tier,
                    "AT_RISK_SUPPLIERS": sr["ids"] if sr else "None",
                    "BIOSECURITY_ALERT": (sr["bio"] if sr and sr["bio"] else "None"),
                    "SUPPLY_SHORTFALL_QTY": round_half_up(Decimal(cr["SUPPLY_SHORTFALL_QTY"] if cr else 0) / n_plants),
                    "REVENUE_AT_RISK_USD": round_half_up(Decimal(cr["REVENUE_AT_RISK_USD"] if cr else 0) / n_plants),
                    "DAYS_OF_SUPPLY": cr["DAYS_OF_SUPPLY"] if cr else 0,
                    "SAFETY_STOCK_DAYS": cr["SAFETY_STOCK_DAYS"] if cr and cr["SAFETY_STOCK_DAYS"] is not None else 42,
                    "DISRUPTED_LOAD_COUNT": tr["disrupted"] if tr else 0,
                    "COMMODITY_YOY_CHANGE_PCT": cm["yoy"] if cm else 0,
                })
    return rows


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

def to_json(value):
    if isinstance(value, Decimal):
        return int(value) if value == value.to_integral_value() else float(round(value, 4))
    if isinstance(value, date):
        return value.isoformat()
    raise TypeError(type(value))


def main():
    sql = SQL_FILE.read_text(encoding="utf-8")
    literal_tables = [
        "I_SUPPLIER", "I_PRODUCT", "I_PRODUCTPLANT", "I_BILLOFMATERIAL", "I_BILLOFMATERIALITEM",
        "M_V_POH_AGGR", "PPH_DDL_STOCK_1", "BY_CONSENSUS_PLAN", "BY_LOADS", "BY_LANES",
        "BY_TENDER_EVENTS", "EXT_VESSEL_TRACKER", "EXT_OUTBREAK_ALERTS", "EXT_NEWS_RISK_EVENTS",
    ]
    t = {name: table_rows(sql, name) for name in literal_tables}
    t["BY_DEMAND_FORECAST"] = build_forecast()
    t["EXT_COMMODITY_PRICES"] = build_commodity_prices()
    t["EXT_PORT_CONGESTION"] = build_port_congestion()
    t["V_SUPPLY_RISK_SCORE"] = v_supply_risk_score(t, v_seasonal_coverage_gap(t))

    payload = json.dumps({"asOf": AS_OF.isoformat(), **t}, default=to_json, separators=(",", ":"))
    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUT_FILE.write_text("// Generated by CPG_S4_BLUEY_CONFECT_PETFOOD/static_site/build_data.py — do not edit.\n"
                        "window.DEMO_DATA = " + payload + ";\n", encoding="utf-8")
    for name, rows in t.items():
        print(f"{name:24s} {len(rows):5d} rows")
    print(f"Wrote {OUT_FILE} ({OUT_FILE.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
