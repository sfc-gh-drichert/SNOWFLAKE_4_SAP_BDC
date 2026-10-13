/*
 * Confect PetFood — Supply Risk Command Center (static GitHub Pages preview).
 * Mirrors CPG_S4_BLUEY_CONFECT_PETFOOD/streamlit/streamlit_app.py page for page.
 * Each block notes the SQL it reproduces so the two stay easy to compare.
 */
(function () {
  'use strict';

  const D = window.DEMO_DATA;
  const RISK_COLORS = { CRITICAL: '#d32f2f', HIGH: '#f57c00', MODERATE: '#fbc02d', MEDIUM: '#fbc02d', LOW: '#388e3c' };
  const DIVISION_COLORS = { CONFECTIONERY: '#7b1fa2', PETCARE: '#1976d2', FOOD: '#388e3c' };
  const SOURCE_COLORS = { sap: '#1565c0', by: '#00897b', ext: '#e65100' };
  const CONF_COLORS = { HIGH: '#388e3c', MEDIUM: '#fbc02d', LOW: '#d32f2f' };
  const TABLEAU = ['#4c78a8', '#f58518', '#e45756', '#72b7b2', '#54a24b', '#eeca3b', '#b279a2', '#ff9da6', '#9d755d', '#bab0ac'];
  const OVERRIDE_KEY = 'confectPetfood.planOverrides';

  // ── helpers ─────────────────────────────────────────────────────────────
  const fmtInt = n => Math.round(n).toLocaleString('en-US');
  const fmtUsd = n => (n < 0 ? '-$' : '$') + fmtInt(Math.abs(n));
  const sum = (rows, f) => rows.reduce((a, r) => a + (Number(f(r)) || 0), 0);
  const cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);
  const by = (f, desc) => (a, b) => (desc ? -1 : 1) * cmp(f(a), f(b));
  const uniq = arr => Array.from(new Set(arr));
  const tint = (hex, alpha) => hex + alpha;

  function groupBy(rows, keyFn) {
    const m = new Map();
    rows.forEach(r => { const k = keyFn(r); if (!m.has(k)) m.set(k, []); m.get(k).push(r); });
    return m;
  }

  function el(tag, props, children) {
    const node = document.createElement(tag);
    Object.entries(props || {}).forEach(([k, v]) => {
      if (k === 'class') node.className = v;
      else if (k === 'text') node.textContent = v;
      else if (k === 'style') Object.assign(node.style, v);
      else node.setAttribute(k, v);
    });
    (children || []).forEach(c => c != null && node.append(c));
    return node;
  }

  // Bold "**x**" fragments without using innerHTML.
  function richText(text) {
    const span = el('span');
    text.split(/(\*\*[^*]+\*\*)/).forEach(part => {
      if (part.startsWith('**')) span.append(el('strong', { text: part.slice(2, -2) }));
      else if (part) span.append(part);
    });
    return span;
  }

  // ── components ──────────────────────────────────────────────────────────
  let charts = [];
  function chart(height, config) {
    const canvas = el('canvas');
    const box = el('div', { class: 'chart-box', style: { height: height + 'px' } }, [canvas]);
    config.options = Object.assign({ responsive: true, maintainAspectRatio: false, animation: { duration: 250 } }, config.options);
    // Draw after the box is attached so Chart.js can measure it.
    requestAnimationFrame(() => charts.push(new Chart(canvas, config)));
    return box;
  }

  function kpi(label, value, color) {
    return el('div', { class: 'kpi', style: { background: `linear-gradient(135deg, ${tint(color, '22')}, ${tint(color, '08')})`, borderLeft: `4px solid ${color}` } }, [
      el('div', { class: 'label', text: label }),
      el('div', { class: 'value', text: String(value), style: { color } }),
    ]);
  }

  function sourceCard(title, color, items) {
    return el('div', { class: 'source-card', style: { border: `1px solid ${tint(color, '44')}`, borderTop: `4px solid ${color}`, background: tint(color, '06') } }, [
      el('div', { class: 'title', text: title, style: { color } }),
      ...items.map(i => el('div', { class: 'item' }, [richText(i)])),
    ]);
  }

  // columns: [key] or [{key, label, wrap}]
  function table(rows, columns) {
    const cols = columns.map(c => (typeof c === 'string' ? { key: c, label: c } : Object.assign({ label: c.key }, c)));
    const thead = el('thead', {}, [el('tr', {}, cols.map(c => el('th', { text: c.label })))]);
    const tbody = el('tbody', {}, rows.map(r => el('tr', {}, cols.map(c => {
      const v = r[c.key];
      if (v === null || v === undefined) return el('td', { class: 'null', text: 'None' });
      if (typeof v === 'boolean') return el('td', { text: v ? '✔' : '✘' });
      if (typeof v === 'number') return el('td', { class: 'num', text: Number.isInteger(v) ? fmtInt(v) : v.toLocaleString('en-US', { maximumFractionDigits: 2 }) });
      return el('td', { class: c.wrap ? 'wrap' : '', text: String(v) });
    }))));
    return el('div', { class: 'table-wrap' }, [el('table', {}, [thead, tbody])]);
  }

  // Tabs render lazily on first open so charts measure a visible container.
  function tabs(defs) {
    const bar = el('div', { class: 'tabs' });
    const panels = defs.map(() => el('div', { hidden: '' }));
    const rendered = new Set();
    const show = i => {
      bar.querySelectorAll('button').forEach((b, j) => b.classList.toggle('active', i === j));
      panels.forEach((p, j) => { p.hidden = i !== j; });
      if (!rendered.has(i)) { rendered.add(i); defs[i].render(panels[i]); }
    };
    defs.forEach((d, i) => {
      const b = el('button', { type: 'button', text: d.label });
      b.addEventListener('click', () => show(i));
      bar.append(b);
    });
    const wrap = el('div', {}, [bar, ...panels]);
    requestAnimationFrame(() => show(0));
    return wrap;
  }

  function header(title, caption) {
    return [el('h2', { class: 'page-title', text: title }), el('div', { class: 'caption', text: caption })];
  }

  function selectBox(labelText, options, onChange, selected) {
    const sel = el('select');
    options.forEach(o => {
      const opt = el('option', { value: o.value, text: o.label });
      if (o.value === selected) opt.selected = true;
      sel.append(opt);
    });
    sel.addEventListener('change', () => onChange(sel.value));
    return el('div', {}, [el('label', { class: 'ctl', text: labelText }), sel]);
  }

  const hBarOpts = (xTitle, extra) => Object.assign({
    indexAxis: 'y',
    plugins: { legend: { display: false } },
    scales: { x: { title: { display: true, text: xTitle } } },
  }, extra);

  // ── page 1: overview ────────────────────────────────────────────────────
  function pageOverview(root) {
    root.append(...header('Supply Risk Command Center', 'Confect PetFood | Multi-source risk intelligence powered by Snowflake'));

    // V_SUPPLY_RISK_SCORE WHERE RISK_TIER IN ('CRITICAL','HIGH','MODERATE')
    const sub = D.V_SUPPLY_RISK_SCORE.filter(r => ['CRITICAL', 'HIGH', 'MODERATE'].includes(r.RISK_TIER));
    const active = D.EXT_OUTBREAK_ALERTS.filter(a => a.STATUS === 'ACTIVE');
    root.append(el('div', { class: 'row' }, [
      kpi('Revenue at Risk', fmtUsd(sum(sub, r => r.REVENUE_AT_RISK_USD)), '#d32f2f'),
      kpi('High / Critical SKUs', sub.filter(r => ['CRITICAL', 'HIGH'].includes(r.RISK_TIER)).length, '#f57c00'),
      kpi('Active Disruptions', active.length, '#7b1fa2'),
      kpi('Suppliers at Risk', Math.max(uniq(sub.map(r => r.AT_RISK_SUPPLIERS)).length - 1, 0), '#1565c0'),
    ]));

    const openPo = D.M_V_POH_AGGR.filter(p => p.GR_DATE === null);
    root.append(el('h3', { text: 'Data Sources' }), el('div', { class: 'cols' }, [
      sourceCard('SAP S/4HANA via BDC', SOURCE_COLORS.sap, [
        `**${D.I_PRODUCT.length}** Products`, `**${D.I_SUPPLIER.length}** Suppliers`,
        `**${D.I_BILLOFMATERIALITEM.length}** BOM Components`, `**${D.M_V_POH_AGGR.length}** Purchase Orders`,
        `**${fmtUsd(sum(openPo, p => p.NET_VALUE_USD))}** Open PO Value`,
      ]),
      sourceCard('Blue Yonder IBP + TMS', SOURCE_COLORS.by, [
        `**${fmtInt(D.BY_DEMAND_FORECAST.length)}** Forecast Records`, `**${D.BY_LOADS.length}** Shipment Loads`,
        `**${D.BY_CONSENSUS_PLAN.length}** Consensus Plans`, `**${D.BY_TENDER_EVENTS.length}** Tender Events`,
      ]),
      sourceCard('External Market Signals', SOURCE_COLORS.ext, [
        `**${uniq(D.EXT_COMMODITY_PRICES.map(c => c.COMMODITY)).length}** Commodity Feeds`,
        `**${uniq(D.EXT_PORT_CONGESTION.map(p => p.PORT_CODE)).length}** Ports Monitored`,
        `**${active.length}** Active Biosecurity Alerts`, `**${D.EXT_NEWS_RISK_EVENTS.length}** News Risk Events`,
      ]),
    ]));

    root.append(el('h3', { text: 'Data Fusion' }), el('div', { class: 'cols' }, [
      el('div', { class: 'box' }, [richText('**SAP BDC** → Products, Suppliers, BOMs, POs, Stock')]),
      el('div', { class: 'box' }, [richText('**Blue Yonder** → Demand Forecast, Consensus Plan, Loads, Tenders')]),
      el('div', { class: 'box' }, [richText('**External** → Commodity Prices, Ports, Outbreaks, News, Vessels')]),
    ]), el('div', { class: 'arrows', text: '↓ ↓ ↓' }), el('div', { class: 'box' }, [el('div', { class: 'cols wide-right' }, [
      el('div', {}, [el('h4', { text: 'Snowflake Intelligence Layer', style: { marginTop: 0 } }), el('div', { text: '17 Iceberg Tables + 3 Analytic Views' })]),
      el('div', {}, [richText('**Composite Risk Score** = Supplier (30%) + Transport (25%) + Coverage (25%) + External (10%) + Commodity (10%)')]),
    ])]));
  }

  // ── page 2: SAP BDC ─────────────────────────────────────────────────────
  function pageSap(root) {
    root.append(...header('SAP BDC Zero Copy', 'Product, supplier, inventory and procurement data from SAP S/4HANA via BDC'));
    const openPo = D.M_V_POH_AGGR.filter(p => p.GR_DATE === null);
    root.append(el('div', { class: 'row' }, [
      kpi('Products', D.I_PRODUCT.length, '#1565c0'),
      kpi('Suppliers', D.I_SUPPLIER.filter(s => s.IS_ACTIVE).length, '#00897b'),
      kpi('BOM Components', D.I_BILLOFMATERIALITEM.length, '#5e35b1'),
      kpi('Purchase Orders', D.M_V_POH_AGGR.length, '#ef6c00'),
      kpi('Open PO Value', fmtUsd(sum(openPo, p => p.NET_VALUE_USD)), '#c62828'),
    ]), el('hr'));

    root.append(tabs([
      { label: 'Products', render(p) {
        const byDiv = groupBy(D.I_PRODUCT, r => r.DIVISION);
        const divs = Object.keys(DIVISION_COLORS).filter(d => byDiv.has(d));
        const brands = Array.from(groupBy(D.I_PRODUCT, r => r.DIVISION + '|' + r.BRAND).values())
          .map(rs => ({ DIVISION: rs[0].DIVISION, BRAND: rs[0].BRAND, SKUs: rs.length,
                        Avg_Price: '$' + (sum(rs, r => r.UNIT_WHOLESALE_USD) / rs.length).toFixed(2) }))
          .sort((a, b) => cmp(a.DIVISION, b.DIVISION) || cmp(a.BRAND, b.BRAND));
        p.append(el('div', { class: 'cols wide-right' }, [
          el('div', {}, [el('h4', { text: 'Products by Division' }), chart(280, {
            type: 'doughnut',
            data: { labels: divs, datasets: [{ data: divs.map(d => byDiv.get(d).length), backgroundColor: divs.map(d => DIVISION_COLORS[d]) }] },
            options: { cutout: '35%' },
          })]),
          table(brands, ['DIVISION', 'BRAND', 'SKUs', 'Avg_Price']),
        ]));
      } },
      { label: 'Suppliers', render(p) {
        const rows = D.I_SUPPLIER.filter(s => s.IS_ACTIVE)
          .sort((a, b) => -cmp(a.CREDIT_RATING, b.CREDIT_RATING) || cmp(a.SUPPLIER_NAME, b.SUPPLIER_NAME));
        p.append(table(rows, ['SUPPLIER_ID', 'SUPPLIER_NAME', 'COUNTRY', 'REGION', 'SUPPLIER_TYPE', 'CREDIT_RATING', 'IS_SOLE_SOURCE', 'CONTRACT_END']));
      } },
      { label: 'Inventory & Coverage', render(p) {
        const prod = new Map(D.I_PRODUCT.map(r => [r.MATERIAL_ID, r]));
        const pp = new Map(D.I_PRODUCTPLANT.map(r => [r.MATERIAL_ID + '|' + r.PLANT, r]));
        const inv = D.PPH_DDL_STOCK_1.filter(s => prod.has(s.MATERIAL_ID) && pp.has(s.MATERIAL_ID + '|' + s.PLANT)).map(s => {
          const plant = pp.get(s.MATERIAL_ID + '|' + s.PLANT);
          return { MATERIAL_ID: s.MATERIAL_ID, MATERIAL_DESC: prod.get(s.MATERIAL_ID).MATERIAL_DESC, PLANT: s.PLANT,
                   PLANT_NAME: plant.PLANT_NAME, UNRESTRICTED_STOCK: s.UNRESTRICTED_STOCK, DAYS_OF_SUPPLY: s.DAYS_OF_SUPPLY,
                   DAILY_CONSUMPTION: s.DAILY_CONSUMPTION, SAFETY_STOCK_DAYS: plant.SAFETY_STOCK_DAYS,
                   GAP_DAYS: Math.round((plant.SAFETY_STOCK_DAYS - s.DAYS_OF_SUPPLY) * 10) / 10 };
        }).sort(by(r => r.GAP_DAYS, true));
        const top = inv.slice(0, 15);
        p.append(el('h4', { text: 'Days of Supply vs Safety Stock Target' }), chart(320, {
          type: 'bar',
          data: { labels: top.map(r => `${r.MATERIAL_ID} (${r.PLANT})`), datasets: [
            { label: 'DAYS_OF_SUPPLY', data: top.map(r => r.DAYS_OF_SUPPLY), backgroundColor: '#1976d2' },
            { label: 'SAFETY_STOCK_DAYS', data: top.map(r => r.SAFETY_STOCK_DAYS), backgroundColor: '#d32f2f' },
          ] },
          options: { scales: { y: { title: { display: true, text: 'Days' } } } },
        }), table(inv, Object.keys(inv[0])));
      } },
      { label: 'Purchase Orders', render(p) {
        const rows = D.M_V_POH_AGGR.slice().sort(by(r => r.DELIVERY_DATE, true));
        p.append(table(rows, ['PO_NUMBER', 'MATERIAL_ID', 'SUPPLIER_ID', 'ORDER_QTY', 'NET_VALUE_USD', 'PO_STATUS', 'DELIVERY_DATE', 'GR_DATE']));
      } },
    ]));
  }

  // ── page 3: Blue Yonder ─────────────────────────────────────────────────
  function demandTab(p) {
    const peak = D.BY_DEMAND_FORECAST.filter(f => f.IS_PEAK_WEEK);
    p.append(el('div', { class: 'row' }, [
      kpi('Peak Events', uniq(peak.map(f => f.PEAK_EVENT)).length, '#00897b'),
      kpi('Peak Forecast Units', fmtInt(sum(peak, f => f.FORECAST_QTY)), '#1565c0'),
      kpi('Avg Seasonal Lift', (sum(peak, f => f.SEASONAL_LIFT_PCT) / peak.length).toFixed(1) + '%', '#ef6c00'),
    ]), el('hr'));

    const events = uniq(peak.map(f => f.PEAK_EVENT)).sort();
    const body = el('div');
    const draw = event => {
      body.replaceChildren();
      // WHERE PEAK_EVENT = :event OR PEAK_EVENT IS NULL
      const keep = f => event === 'ALL' || f.PEAK_EVENT === event || f.PEAK_EVENT === null;
      const weekly = Array.from(groupBy(D.BY_DEMAND_FORECAST.filter(keep), f => f.WEEK_START).entries()).sort(by(e => e[0]));
      body.append(chart(380, {
        type: 'line',
        data: { labels: weekly.map(e => e[0]), datasets: [
          { label: 'FORECAST', data: weekly.map(e => sum(e[1], f => f.FORECAST_QTY)), borderColor: '#1976d2', backgroundColor: 'rgba(25,118,210,0.3)', fill: true, pointRadius: 2 },
          { label: 'BASELINE', data: weekly.map(e => sum(e[1], f => f.BASELINE_QTY)), borderColor: '#9e9e9e', backgroundColor: 'rgba(189,189,189,0.3)', fill: true, pointRadius: 2 },
        ] },
        options: { plugins: { title: { display: true, text: 'Weekly Demand: Forecast vs Baseline' } }, scales: { y: { title: { display: true, text: 'Units' } } } },
      }));
      const mats = Array.from(groupBy(peak.filter(keep), f => f.MATERIAL_ID).entries())
        .map(([m, rs]) => ({ m, base: sum(rs, f => f.BASELINE_QTY), fc: sum(rs, f => f.FORECAST_QTY) }))
        .sort(by(r => r.fc, true));
      body.append(chart(320, {
        type: 'bar',
        data: { labels: mats.map(r => r.m), datasets: [
          { label: 'BASELINE', data: mats.map(r => r.base), backgroundColor: '#bdbdbd' },
          { label: 'FORECAST', data: mats.map(r => r.fc), backgroundColor: '#1976d2' },
        ] },
        options: { plugins: { title: { display: true, text: 'Peak Weeks: Baseline vs Forecast by Material' } }, scales: { y: { title: { display: true, text: 'Units' } } } },
      }));
    };
    p.append(selectBox('Filter by Peak Event', ['ALL', ...events].map(e => ({ value: e, label: e })), draw, 'ALL'), body);
    draw('ALL');
  }

  function transportTab(p) {
    const countBar = (rows, key, title, yTitle) => {
      const counts = Array.from(groupBy(rows, r => r[key]).entries()).map(([k, v]) => [k, v.length]).sort(by(e => e[1], true));
      return chart(280, {
        type: 'bar',
        data: { labels: counts.map(c => c[0]), datasets: [{ data: counts.map(c => c[1]), backgroundColor: counts.map((_, i) => TABLEAU[i % TABLEAU.length]), borderRadius: 4 }] },
        options: { plugins: { legend: { display: false }, title: { display: true, text: title } }, scales: { y: { title: { display: true, text: yTitle } } } },
      });
    };
    p.append(el('div', { class: 'cols' }, [
      countBar(D.BY_LOADS, 'LOAD_STATUS', 'Load Status', 'Loads'),
      countBar(D.BY_TENDER_EVENTS, 'RESPONSE_TYPE', 'Tender Responses', 'Events'),
    ]), table(D.BY_LOADS.slice().sort(by(r => r.SHIPMENT_DATE, true)),
      ['LOAD_ID', 'LANE_ID', 'RELATED_PO', 'CARRIER_ID', 'SHIPMENT_DATE', 'DELIVERY_DATE', 'LOAD_STATUS', 'WEIGHT_KG']));
  }

  function loadOverrides() {
    try { return JSON.parse(window.localStorage.getItem(OVERRIDE_KEY)) || {}; } catch (e) { return memoryOverrides; }
  }
  let memoryOverrides = {};
  function saveOverrides(o) {
    memoryOverrides = o;
    try { window.localStorage.setItem(OVERRIDE_KEY, JSON.stringify(o)); } catch (e) { /* private mode: keep in memory */ }
  }

  function planTab(p) {
    // Consensus plan vs peak-week forecast (same SQL as the Streamlit Plan Override tab)
    const prod = new Map(D.I_PRODUCT.map(r => [r.MATERIAL_ID, r]));
    const peakByMat = groupBy(D.BY_DEMAND_FORECAST.filter(f => f.IS_PEAK_WEEK), f => f.MATERIAL_ID);
    const plan = D.BY_CONSENSUS_PLAN.filter(c => prod.has(c.MATERIAL_ID)).map(c => {
      const pr = prod.get(c.MATERIAL_ID);
      const fc = sum(peakByMat.get(c.MATERIAL_ID) || [], f => f.FORECAST_QTY);
      return { MATERIAL_ID: c.MATERIAL_ID, MATERIAL_DESC: pr.MATERIAL_DESC, DIVISION: pr.DIVISION, COMMITTED_QTY: c.COMMITTED_QTY,
               TOTAL_FORECAST_QTY: fc, PLAN_GAP_QTY: fc - c.COMMITTED_QTY,
               GAP_REVENUE_USD: Math.round((fc - c.COMMITTED_QTY) * pr.UNIT_WHOLESALE_USD), PLAN_CONFIDENCE: c.PLAN_CONFIDENCE };
    }).sort(by(r => r.PLAN_GAP_QTY, true));

    const gap = sum(plan, r => r.PLAN_GAP_QTY), gapRev = sum(plan, r => r.GAP_REVENUE_USD);
    p.append(el('div', { class: 'row' }, [
      kpi('Committed (S&OP)', fmtInt(sum(plan, r => r.COMMITTED_QTY)), '#00897b'),
      kpi('Peak Forecast', fmtInt(sum(plan, r => r.TOTAL_FORECAST_QTY)), '#1565c0'),
      kpi('Plan Gap (units)', fmtInt(gap), gap > 0 ? '#d32f2f' : '#388e3c'),
      kpi('Gap Revenue Impact', fmtUsd(gapRev), gapRev > 0 ? '#d32f2f' : '#388e3c'),
    ]), el('hr'));

    const gapRows = plan.filter(r => r.PLAN_GAP_QTY !== 0).slice(0, 15);
    p.append(el('h4', { text: 'Plan Gap: Forecast vs S&OP Committed' }), chart(Math.max(300, gapRows.length * 26), {
      type: 'bar',
      data: { labels: gapRows.map(r => `${r.MATERIAL_ID} — ${r.MATERIAL_DESC.slice(0, 25)}`),
              datasets: [{ data: gapRows.map(r => r.PLAN_GAP_QTY), backgroundColor: gapRows.map(r => (r.PLAN_GAP_QTY > 0 ? '#d32f2f' : '#388e3c')), borderRadius: 4 }] },
      options: hBarOpts('Forecast − Committed (units)'),
    }));

    const conf = Array.from(groupBy(plan, r => r.PLAN_CONFIDENCE).entries());
    p.append(el('div', { class: 'cols wide-right' }, [
      el('div', {}, [el('h4', { text: 'Plan Confidence' }), chart(240, {
        type: 'doughnut',
        data: { labels: conf.map(c => c[0]), datasets: [{ data: conf.map(c => c[1].length), backgroundColor: conf.map(c => CONF_COLORS[c[0]] || '#888') }] },
        options: { cutout: '35%' },
      })]),
      table(plan, ['MATERIAL_ID', 'MATERIAL_DESC', 'DIVISION', 'COMMITTED_QTY', 'TOTAL_FORECAST_QTY', 'PLAN_GAP_QTY', 'GAP_REVENUE_USD', 'PLAN_CONFIDENCE']),
    ]));

    // ── interactive override (browser-only stand-in for MERGE INTO BY_PLAN_OVERRIDES)
    p.append(el('hr'), el('h3', { text: 'Adjust Plan' }),
      el('div', { class: 'caption', text: 'Override the S&OP committed quantity for a material. In this preview overrides are saved in your browser; the live app writes them to BY_PLAN_OVERRIDES.' }));
    const editor = el('div');
    const saved = el('div');
    p.append(editor, saved);

    const renderSaved = () => {
      const rows = Object.values(loadOverrides()).sort(by(r => r.OVERRIDE_TIMESTAMP, true));
      saved.replaceChildren();
      if (!rows.length) return;
      const clear = el('button', { type: 'button', class: 'btn', text: 'Clear saved overrides' });
      clear.addEventListener('click', () => { saveOverrides({}); renderSaved(); });
      saved.append(el('h4', { text: 'Saved Overrides' }), table(rows, ['MATERIAL_ID', 'OVERRIDE_QTY', 'OVERRIDE_REASON', 'OVERRIDDEN_BY', 'OVERRIDE_TIMESTAMP']), clear);
    };

    const renderEditor = mat => {
      editor.replaceChildren();
      const row = plan.find(r => r.MATERIAL_ID === mat);
      const current = row.COMMITTED_QTY, fc = row.TOTAL_FORECAST_QTY;
      const max = Math.max(fc * 2, current * 2, 1);
      const slider = el('input', { type: 'range', min: '0', max: String(max), step: '500', value: String(current) });
      const sliderVal = el('strong', { text: fmtInt(current) });
      const reason = el('select');
      ['Demand surge', 'Supply constraint', 'Safety stock build', 'Seasonal adjustment', 'Customer escalation', 'Other']
        .forEach(r => reason.append(el('option', { value: r, text: r })));
      const gapText = el('p');
      const chartSlot = el('div');
      const saveBtn = el('button', { type: 'button', class: 'btn primary', text: 'Save Override' });
      const msg = el('div');

      const refresh = () => {
        const qty = Number(slider.value);
        sliderVal.textContent = fmtInt(qty);
        const newGap = fc - qty;
        gapText.replaceChildren(el('strong', { text: 'New gap: ' }), el('strong', { text: `${fmtInt(newGap)} units`, style: { color: newGap > 0 ? '#d32f2f' : '#388e3c' } }));
        saveBtn.disabled = qty === current;
        chartSlot.replaceChildren(chart(260, {
          type: 'bar',
          data: { labels: ['S&OP Committed', 'Override Qty', 'Peak Forecast'], datasets: [{ data: [current, qty, fc], backgroundColor: ['#9e9e9e', '#1565c0', '#ef6c00'], borderRadius: 4 }] },
          options: { plugins: { legend: { display: false }, title: { display: true, text: `${mat} — Plan Comparison` } }, scales: { y: { title: { display: true, text: 'Units' } } } },
        }));
      };
      slider.addEventListener('input', () => { sliderVal.textContent = fmtInt(Number(slider.value)); });
      slider.addEventListener('change', refresh);
      saveBtn.addEventListener('click', () => {
        const all = loadOverrides();
        all[mat] = { MATERIAL_ID: mat, OVERRIDE_QTY: Number(slider.value), OVERRIDE_REASON: reason.value,
                     OVERRIDDEN_BY: 'you (this browser)', OVERRIDE_TIMESTAMP: new Date().toISOString().slice(0, 19).replace('T', ' ') };
        saveOverrides(all);
        msg.replaceChildren(el('div', { class: 'success', text: `Override saved: ${mat} → ${fmtInt(Number(slider.value))} units (${reason.value})` }));
        renderSaved();
      });

      editor.append(el('div', { class: 'cols wide-right' }, [
        el('div', {}, [
          selectBox('Material to override', plan.map(r => ({ value: r.MATERIAL_ID, label: r.MATERIAL_ID })), renderEditor, mat),
          el('p', {}, [richText(`**Current S&OP Committed:** ${fmtInt(current)}`)]),
          el('p', {}, [richText(`**Peak Forecast:** ${fmtInt(fc)}`)]),
          el('p', {}, [richText(`**Gap:** ${fmtInt(row.PLAN_GAP_QTY)} units`)]),
          el('label', { class: 'ctl' }, ['New committed quantity: ', sliderVal]), slider,
          el('label', { class: 'ctl', text: 'Reason' }), reason,
        ]),
        el('div', {}, [chartSlot, gapText]),
      ]), saveBtn, msg);
      refresh();
    };
    renderEditor(plan[0].MATERIAL_ID);
    renderSaved();
  }

  function pageBy(root) {
    root.append(...header('Blue Yonder Planning', 'Demand forecasts, consensus plans and transport execution from Blue Yonder IBP & TMS'));
    root.append(tabs([
      { label: 'Demand & Consensus Plan', render: demandTab },
      { label: 'Transport Execution', render: transportTab },
      { label: 'Plan Override', render: planTab },
    ]));
  }

  // ── page 4: external signals ────────────────────────────────────────────
  function pageExt(root) {
    root.append(...header('External Signals', 'Real-time market, geopolitical and biosecurity intelligence'));
    const alerts = D.EXT_OUTBREAK_ALERTS.filter(a => a.STATUS === 'ACTIVE').sort(by(a => a.RISK_LEVEL, true));
    if (alerts.length) {
      root.append(el('h3', { text: `Active Biosecurity Alerts (${alerts.length})` }), el('div', { class: 'cols' }, alerts.map(a => {
        const c = RISK_COLORS[a.RISK_LEVEL] || '#757575';
        return el('div', { class: 'alert-card', style: { borderLeft: `5px solid ${c}`, background: tint(c, '0a') } }, [
          el('div', { class: 'name', text: a.DISEASE_NAME }),
          el('div', { class: 'where', text: `${a.COUNTRY} • ${a.REGION}` }),
          el('div', { style: { marginTop: '8px' } }, [el('span', { class: 'badge', text: a.RISK_LEVEL, style: { background: c } }), a.AFFECTED_SPECIES]),
          el('div', { class: 'since', text: `Since ${a.ALERT_DATE}` }),
        ]);
      })));
    }
    root.append(el('hr'), tabs([
      { label: 'Commodity Prices', render(p) {
        const all = uniq(D.EXT_COMMODITY_PRICES.map(c => c.COMMODITY)).sort();
        const selected = new Set(all.slice(0, 3));
        const chips = el('div', { class: 'chips' });
        const body = el('div');
        const draw = () => {
          body.replaceChildren();
          const picked = all.filter(c => selected.has(c));
          if (!picked.length) { body.append(el('p', { class: 'note', text: 'Select at least one commodity.' })); return; }
          const rows = D.EXT_COMMODITY_PRICES.filter(c => selected.has(c.COMMODITY));
          const dates = uniq(rows.map(r => r.PRICE_DATE)).sort();
          const byCom = groupBy(rows, r => r.COMMODITY);
          body.append(chart(380, {
            type: 'line',
            data: { labels: dates, datasets: picked.map(c => {
              const m = new Map(byCom.get(c).map(r => [r.PRICE_DATE, r.SPOT_PRICE]));
              const color = TABLEAU[all.indexOf(c) % TABLEAU.length];
              return { label: c, data: dates.map(d => m.get(d)), borderColor: color, backgroundColor: color, pointRadius: 0, borderWidth: 2 };
            }) },
            options: { plugins: { title: { display: true, text: 'Commodity Spot Prices (90 days)' } }, scales: { y: { title: { display: true, text: 'Spot Price (USD/MT)' } } } },
          }));
          const latest = D.EXT_COMMODITY_PRICES.reduce((m, r) => (r.PRICE_DATE > m ? r.PRICE_DATE : m), '');
          body.append(table(rows.filter(r => r.PRICE_DATE === latest).sort(by(r => r.COMMODITY)),
            ['COMMODITY', 'SPOT_PRICE', 'PRICE_UNIT', 'SUPPLY_TIGHTNESS', 'YOY_CHANGE_PCT']));
        };
        all.forEach(c => {
          const chip = el('button', { type: 'button', class: 'chip' + (selected.has(c) ? ' on' : ''), text: c });
          chip.addEventListener('click', () => {
            if (selected.has(c)) selected.delete(c); else selected.add(c);
            chip.classList.toggle('on', selected.has(c));
            draw();
          });
          chips.append(chip);
        });
        p.append(el('label', { class: 'ctl', text: 'Commodities' }), chips, body);
        draw();
      } },
      { label: 'News & Risk Events', render(p) {
        p.append(table(D.EXT_NEWS_RISK_EVENTS.slice().sort(by(r => r.EVENT_DATE, true)),
          ['EVENT_DATE', { key: 'HEADLINE', wrap: true }, 'RISK_CATEGORY', 'SEVERITY', 'SOURCE', 'RELATED_SUPPLIER', 'AFFECTED_COMMODITY']));
      } },
      { label: 'Ports & Vessels', render(p) {
        const latest = D.EXT_PORT_CONGESTION.reduce((m, r) => (r.REPORT_DATE > m ? r.REPORT_DATE : m), '');
        p.append(el('div', { class: 'cols' }, [
          el('div', {}, [el('h4', { text: 'Port Congestion (latest)' }), table(
            D.EXT_PORT_CONGESTION.filter(r => r.REPORT_DATE === latest).sort(by(r => r.CONGESTION_SCORE, true)),
            ['PORT_CODE', 'PORT_NAME', 'COUNTRY', 'CONGESTION_SCORE', 'AVG_WAIT_HOURS', 'VESSELS_AT_ANCHOR', 'ALERT_LEVEL'])]),
          el('div', {}, [el('h4', { text: 'Vessel Tracker' }), table(
            D.EXT_VESSEL_TRACKER.slice().sort(by(r => r.DELAY_DAYS, true)),
            ['VESSEL_NAME', 'VESSEL_TYPE', 'CARGO_TYPE', 'DEPARTURE_PORT', 'DESTINATION_PORT', 'ORIGINAL_ETA', 'REVISED_ETA', 'DELAY_DAYS', 'CURRENT_STATUS'])]),
        ]));
      } },
    ]));
  }

  // ── page 5: risk command center ─────────────────────────────────────────
  function pageRisk(root) {
    root.append(...header('Risk Command Center', 'Composite risk scoring across all data layers'));
    const risk = D.V_SUPPLY_RISK_SCORE.slice().sort(by(r => r.COMPOSITE_RISK_SCORE, true));
    const top = risk.slice(0, 20);
    root.append(el('h3', { text: 'Risk Leaderboard' }), chart(Math.max(450, top.length * 26), {
      type: 'bar',
      data: { labels: top.map(r => `${r.MATERIAL_ID} @ ${r.PLANT} — ${r.MATERIAL_DESC.slice(0, 30)}`),
              datasets: [{ data: top.map(r => r.COMPOSITE_RISK_SCORE), backgroundColor: top.map(r => RISK_COLORS[r.RISK_TIER]), borderRadius: 4 }] },
      options: hBarOpts('Composite Risk Score', { scales: { x: { min: 0, max: 100, title: { display: true, text: 'Composite Risk Score' } } } }),
    }), el('hr'));

    const tiers = Object.keys(RISK_COLORS).filter(t => t !== 'MEDIUM');
    const tierCounts = tiers.map(t => risk.filter(r => r.RISK_TIER === t).length);
    const divRisk = Array.from(groupBy(risk, r => r.DIVISION).entries())
      .map(([d, rs]) => [d, sum(rs, r => r.REVENUE_AT_RISK_USD)]).sort(by(e => e[1], true));
    root.append(el('div', { class: 'cols' }, [
      el('div', {}, [el('h4', { text: 'Risk Tier Distribution' }), chart(300, {
        type: 'doughnut',
        data: { labels: tiers, datasets: [{ data: tierCounts, backgroundColor: tiers.map(t => RISK_COLORS[t]) }] },
        options: { cutout: '55%' },
      })]),
      el('div', {}, [el('h4', { text: 'Revenue at Risk by Division' }), chart(200, {
        type: 'bar',
        data: { labels: divRisk.map(e => e[0]), datasets: [{ data: divRisk.map(e => e[1]), backgroundColor: divRisk.map(e => DIVISION_COLORS[e[0]] || '#888'), borderRadius: 4 }] },
        options: hBarOpts('Revenue at Risk ($)'),
      })]),
    ]), el('hr'), el('h3', { text: 'Material Drill-Down' }));

    const detail = el('div');
    const drill = idx => {
      const r = risk[Number(idx)];
      const tc = RISK_COLORS[r.RISK_TIER] || '#888';
      detail.replaceChildren(el('div', { class: 'row' }, [
        kpi('Composite Score', r.COMPOSITE_RISK_SCORE.toFixed(1), tc),
        kpi('Risk Tier', r.RISK_TIER, tc),
        kpi('Revenue at Risk', fmtUsd(r.REVENUE_AT_RISK_USD), '#d32f2f'),
        kpi('Days of Supply', Math.round(r.DAYS_OF_SUPPLY), '#1565c0'),
        kpi('Safety Target', Math.round(r.SAFETY_STOCK_DAYS), '#00897b'),
      ]), el('div', { class: 'box detail', style: { marginTop: '14px' } }, [el('div', { class: 'cols' }, [
        el('div', {}, [
          el('p', {}, [richText(`**Material:** ${r.MATERIAL_ID} — ${r.MATERIAL_DESC}`)]),
          el('p', {}, [richText(`**Division / Brand:** ${r.DIVISION} / ${r.BRAND}`)]),
          el('p', {}, [richText(`**Plant:** ${r.PLANT}`)]),
          el('p', {}, [richText(`**Peak Event:** ${r.PEAK_EVENT || 'N/A'}`)]),
        ]),
        el('div', {}, [
          el('p', {}, [richText(`**At-Risk Suppliers:** ${r.AT_RISK_SUPPLIERS}`)]),
          el('p', {}, [richText(`**Biosecurity Alert:** ${r.BIOSECURITY_ALERT}`)]),
          el('p', {}, [richText(`**Supply Shortfall:** ${fmtInt(r.SUPPLY_SHORTFALL_QTY)} units`)]),
          el('p', {}, [richText(`**Disrupted Loads:** ${r.DISRUPTED_LOAD_COUNT}`)]),
          el('p', {}, [richText(`**Commodity YoY Change:** ${Number(r.COMMODITY_YOY_CHANGE_PCT).toFixed(1)}%`)]),
        ]),
      ])]));
    };
    root.append(selectBox('Select Material', risk.map((r, i) => ({ value: String(i), label: `${r.MATERIAL_ID} (${r.PLANT}${r.PEAK_EVENT ? ', ' + r.PEAK_EVENT : ''})` })), drill, '0'), detail);
    drill(0);
  }

  // ── router ──────────────────────────────────────────────────────────────
  const PAGES = { overview: pageOverview, sap: pageSap, by: pageBy, ext: pageExt, risk: pageRisk };
  function route() {
    const key = PAGES[location.hash.slice(1)] ? location.hash.slice(1) : 'overview';
    charts.forEach(c => c.destroy());
    charts = [];
    const root = document.getElementById('page');
    root.replaceChildren();
    PAGES[key](root);
    document.querySelectorAll('#nav a').forEach(a => a.classList.toggle('active', a.dataset.page === key));
    window.scrollTo(0, 0);
  }

  Chart.defaults.font.family = getComputedStyle(document.documentElement).fontFamily;
  Chart.defaults.color = '#31333f';
  document.getElementById('as-of').textContent = D.asOf;
  window.addEventListener('hashchange', route);
  route();
})();
