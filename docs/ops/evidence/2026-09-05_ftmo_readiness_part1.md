# FTMO Readiness — Part 1: Governed Live Attribution & Candidate Feasibility (2026-09-05)

Task 8c561172 (Claude lane) · Drafter scout report bound · READ-ONLY evidence pass · No purchase, no T_Live action, no AutoTrading.
Successor of the 2026-09-04 Astra inventory (`docs/ops/evidence/2026-09-04_astra_ftmo_inventory.json`, qualified_pairs=8). This part is a readiness/attribution scout: it opens no sealed result and stays inside the pre-ratification boundary. Every value below carries a file path; where no source exists the cell is marked **MISSING** or **UNVERIFIED** and is never invented.

---

## Zusammenfassung (Deutsch, eine Seite)

**Zweck.** Zwei von Astra benannte Lücken schließen, ohne etwas zu kaufen: (A) das T_Live-Track-Record sauber auf *nur regierte* Ausführungen zurückrechnen mit ehrlicher Unsicherheit, und (B) für die 8 versiegelten FTMO-Kandidaten Marge/Hebel/Handelbarkeit/Swap/News-Blackout unter dem FTMO-Swing-Profil prüfen — jeder Wert mit Quellpfad, Fehlendes klar als MISSING/UNVERIFIED markiert.

**(A) Regierte Live-Attribution.** Der regierte Bestand sind die **24 Sleeves** des Deploy-Pointers `D:/QM/reports/state/live_deployment_pointer.json` (Konto 4000090541, T_Live/DXZ, Epoche 2026-07-24). Magic = ea_id·10000+slot. **Kritischer Drift-Befund:** der Pointer ist **`signed=False` / `approved_by=None`** — der regierte Bestand läuft gegen einen **UNSIGNIERTEN** Pointer (Signierung ist genau die offene OWNER-Handlung der 06.09-Session, Beleg-Zeile 3).

- **Ausgeschlossen** (Beleg-Zeile 1, OWNER wörtlich „ja war ich selbst, kommt nicht mehr vor"): die zwei manuellen `magic=0`-Trades (27.07 NDX 1,00 Lot −1.537; 24.07 EURUSD 0,43 Lot −261). Kein Magic-Strip-Defekt, forensisch geschlossen.
- **Regierte Bilanz (CEO-Audit-Zahl, maßgeblich):** **−469 USD über 30 aktive Tage**, Sharpe-CI **[−6,8, +4,6]** (`docs/ops/CEO_AUDIT_2026-09-02.md:14`). DSR ≥ 0,95 = **0/24 Sleeves** für jedes N ≥ 10 (Zeile 43). Buch-Sharpe +2,13 = Diversifikation individuell insignifikanter Edges. **Kante ist unbewiesen, nicht widerlegt.**
- **Ausnahmenliste für OWNER-Adjudikation:** **4 regiert aussehende Magics stehen NICHT im signierten 24er-Roster:** 104760004, 106920005, 107150004, 109400003 (`artifacts/audit_live_book_inventory_20260819.json`, status=DRIFT). **Zwei (10476, 10715) haben nie einen Deal platziert** (`traded_ever=false`) → können in keinem Track-Record erscheinen (reine Label-Drift). Die zwei mit Deals (10692 letzter Trade 10.07., 10940 letzter Trade 29.06.) handelten **vor der Deploy-Epoche 24.07.** → Vor-Deployment-Altlast, außerhalb des regierten 30-Tage-Fensters. OWNER-Frage ist **Herkunft/Labeling**, nicht aktuelle P&L-Kontamination.
- **Ehrlichkeits-Caveat:** die maßgebliche regierte −469/30d-Zahl lebt nur in der CEO-Audit-Prosa; die committete Pro-Sleeve-Aufschlüsselung ist einen Monat alt (`live_deals_normalized.csv`, 2026-08-04) und partiell. Eine frische Deal-Export-Läufe ist nötig, um −469 pro Sleeve zu reproduzieren.

**(B) Kandidaten-Feasibility (8 Paare).** DXZ-Order-Routbarkeit ist für **alle 8** Symbole in der Matrix **UNBESTÄTIGT** (nur SP500 ist ORDER_ROUTABLE_CONFIRMED). FTMO-Swing-Hebel **1:30 FX / 1:15 Metalle+Öl** ist im Rulepack, aber **UNVERIFIED** (die Quelle-URL `ftmo.com/en/trading-symbols/` lieferte am 2026-09-04 **HTTP 404**; Korroboration nur aus dem 2026-07-30-Snapshot). **Swap ist die entscheidende Lücke:** die regierte Registry hat **null** Swap-Daten; echte Werte existieren nur für XTIUSD/XAU/USDJPY (07-30-Snapshot) — für **XAGUSD und die 4 FX-Kandidaten fehlt Swap vollständig**. 7 von 8 Kandidaten sind D1-Strategien (Mehrtage-Halten → mehrfache Swap-Anfälligkeit); **News-Blackout unter FTMO-Swing = KEINER** (Provider-Regel), nur die interne QM-Mitternachts-Guardrail (PROPOSED).

**(C) Nur-OWNER / geblockt.** (1) Pointer **signieren**; (2) die 4 Drift-Magics **adjudizieren**; (3) FTMO-Client-Area: Hebel 1:30/1:15, aktuelle Symbol-Liste, Marge/Swap für XAG + 4 FX **nachbeziehen** (404-URL); (4) FTMO-Demo/Free-Trial-Konto für den Ausführungs-Export **anlegen**; (5) **Kauf bleibt ausgeschlossen** (Blanket-Release 2026-09-05 „alles außer Kauf"); NO-BUY-Park re-verankert auf positive OOS/Live-Evidenz.

---

## A. Governed-only live attribution

### A.0 Governed identity basis

- **Roster source:** `D:/QM/reports/state/live_deployment_pointer.json` — written 2026-08-22T10:06:38Z, deployment epoch 2026-07-24T06:42Z, environment `T_Live/DXZ`, server `Darwinex-Live`, phase `DXZ_LIVE`, expected account **4000090541**, `expected_sleeves.count=24`, `manifest_sha256=8c719b08…`, `binary_setfile_fingerprint.fingerprint_sha256=8e476e5b…`, `n_binary_missing=0`.
- **Magic formula:** `magic = ea_id*10000 + slot`. Verified against the pointer's per-sleeve roster and `framework/registry/magic_numbers.csv`.
- **IDENTITY-DRIFT RED FLAG:** the pointer is **`signed=False`, `approved_by=None`**. `manifest_declared_status=LIVE` and `manifest_declared_approved_by="OWNER (Fabian) 2026-07-24 … countersigned via chat"` exist, but the pointer itself is **not cryptographically signed**. Signing it is the pending OWNER action for the 06.09 session (receipt row 3 = "ja"). **The governed book runs against an UNSIGNED pointer** — this is section C item 1.

### A.1 Governed roster — identity & drift flags (24 sleeves)

Identity from the deploy-pointer per-sleeve fingerprint; set-file expectation `ENV=live, RISK_FIXED=0, RISK_PERCENT=<value>` for every sleeve (`ex5_status=OK` for all 24). "In 08-04 export?" = whether the sleeve appears in the freshest **committed** per-deal export (see A.2).

| magic | ea | slot | preset (symbol/TF) | RISK_PERCENT | ex5_sha8 | identity | in 08-04 export? |
|---|---|---|---|---|---|---|---|
| 15560004 | 1556 | 4 | XAUUSD D1 aa-zak-mom12 | 0.6017 | 9371a8a0 | OK | yes |
| 15670007 | 1567 | 7 | EURUSD H4 demark-td-reverse-seq | 0.1791 | 71c2f84b | OK | no |
| 104030002 | 10403 | 2 | XAUUSD D1 et-turtle20x | 0.2204 | b6c194d9 | OK | no |
| 104400003 | 10440 | 3 | NDX H1 mql5-ohlc-mtf | 0.0577 | b71d3029 | OK (Q10 FAIL, no kill-switch baseline — CEO ask #5) | yes |
| 105130003 | 10513 | 3 | XAUUSD D1 mql5-ichimoku | 0.305 | 04b62af2 | OK | yes |
| 107060001 | 10706 | 1 | GBPUSD H1 tv-mon-ls | 0.053 | 01e34b20 | OK (also a Part-B candidate) | yes |
| 109110003 | 10911 | 3 | GDAXI H1 grimes-complex-pb | 0.1276 | a815c73d | OK | yes |
| 109190001 | 10919 | 1 | XTIUSD H4 grimes-overshoot | 0.9181 | 57e0db84 | OK | no |
| 109390001 | 10939 | 1 | GBPUSD H4 grimes-context-pb | 0.1887 | 308604a3 | OK | no |
| 111320000 | 11132 | 0 | SP500 D1 tm-cum-rsi2 | 0.4562 | 25b68c44 | OK | yes |
| 111650000 | 11165 | 0 | EURUSD H1 weiss-rsi-ma | 0.4127 | 8f6d33a3 | OK | yes |
| 111650002 | 11165 | 2 | AUDCAD H1 weiss-rsi-ma | 0.523 | 8f6d33a3 | OK | yes |
| 114210000 | 11421 | 0 | EURUSD D1 ohlc-daily-squeeze-rev | 0.3364 | 0f7c8ff9 | OK (also a Part-B candidate) | yes |
| 114210003 | 11421 | 3 | AUDUSD D1 ohlc-daily-squeeze-rev | 0.3614 | 0f7c8ff9 | OK | yes |
| 117080000 | 11708 | 0 | EURUSD D1 anon-market-squeeze | 0.508 | de06fb03 | OK | no |
| 125670002 | 12567 | 2 | XNGUSD D1 cum-rsi2-commodity | 0.9797 | 5d5be334 | OK | no |
| 125670003 | 12567 | 3 | XAUUSD D1 cum-rsi2-commodity | 0.7465 | 5d5be334 | OK | no |
| 127780000 | 12778 | 0 | AUDUSD D1 edgelab-cointegration | 0.4905 | 2c470706 | OK (structurally dark 0/4 legs — CEO §3.3) | no |
| 129690000 | 12969 | 0 | USDJPY M30 gotobi-nakane-fix | 0.51 | 933d63c0 | OK (silent since 28.08 — CEO §3.3) | no |
| 129890003 | 12989 | 3 | XAUUSD H4 grimes-nested-pb-v2 | 0.242 | 7f2c298f | OK | no |
| 131170000 | 13117 | 0 | EURGBP D1 eurgbp-audjpy | 0.4199 | adfa1ba6 | OK (structurally dark 0/4 legs — CEO §3.3) | no |
| 131280000 | 13128 | 0 | NDX H1 pre-fomc-drift | 1.0 | 364867a9 | OK (missed 29.07 FOMC = defect, MNT-036 REQUALIFY/REMOVE) | no |
| 132130000 | 13213 | 0 | USDJPY H1 balke-gmt3-range-break | 0.0431 | 321b1dca | OK | yes |
| 133010010 | 13301 | 10 | GDAXI M5 balke-minute-range-break | 0.0692 | d7f10a68 | OK | yes |

Roster ↔ log reconciliation: `magics_in_manifest_not_in_logs = []` (every governed sleeve is accounted for in the logs). Source: `artifacts/audit_live_book_inventory_20260819.json` → `manifest_reconciliation` (status=**DRIFT**, generated 2026-08-22T10:24:21Z, `pointer_signed=false`).

### A.2 Per-sleeve P&L — freshest COMMITTED export (2026-08-04, STALE + PARTIAL)

Source: `D:/QM/reports/portfolio/invvol_stage1_20260804/input_snapshots/live_deals_normalized.csv` (mtime 2026-08-04T15:58:45; invvol stage-1 input snapshot, **95 deal rows**). This is the freshest **committed** per-deal export, but it is **a month stale** vs the CEO audit's 2026-09-02 governed read and covers only the sleeves that had traded by 2026-08-04. Values are USD; "active days" counts distinct entry-deal UTC dates in this snapshot only.

| magic | symbol | rows | gross profit | swap | commission | net_actual | active days (in snapshot) |
|---|---|---|---|---|---|---|---|
| 15560004 | XAUUSD | 6 | +60.30 | −21.43 | −1.20 | **+37.67** | 6 |
| 104400003 | NDX | 4 | +1348.74 | +1.76 | −4.30 | **+1346.20** | 3 |
| 105130003 | XAUUSD | 2 | 0.00 | 0.00 | −0.20 | **−0.20** | 2 |
| 107060001 | GBPUSD | 4 | +116.53 | −2.85 | −3.55 | **+110.13** | 3 |
| 109110003 | GDAXI | 12 | −116.29 | −21.98 | −5.28 | **−143.55** | 6 |
| 111320000 | SP500 | 6 | +36.72 | −12.94 | −0.52 | **+23.26** | 6 |
| 111650000 | EURUSD | 2 | +66.60 | 0.00 | −2.06 | **+64.54** | 1 |
| 111650002 | AUDCAD | 6 | −49.02 | +14.68 | −10.26 | **−44.60** | 6 |
| 114210000 | EURUSD | 2 | 0.00 | 0.00 | −3.92 | **−3.92** | 2 |
| 114210003 | AUDUSD | 2 | 0.00 | 0.00 | −2.67 | **−2.67** | 2 |
| 132130000 | USDJPY | 20 | +183.92 | 0.00 | −16.68 | **+167.24** | 10 |
| 133010010 | GDAXI | 12 | +33.63 | 0.00 | −1.18 | **+32.45** | 6 |

**Caveat (do not read as the current governed book):** this snapshot is stale and partial. The `104400003/NDX +1,346` figure here is an early-window positive that does **not** carry into the CEO-audit-current governed book; 12 of 24 sleeves have no committed per-deal P&L in this snapshot at all (they either had not traded by 04.08 or are structurally dark). The authoritative *current* governed total is the CEO-audit figure in A.3, not the sum of this table. **Reproducing the −469/30-day figure per sleeve requires a fresh live-deals export** (the deal-export tooling re-run) or the terminal-local per-EA logs `C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/QM5_<id>_*.log` — an evidence gap flagged as a Part-1 compute step, not a MISSING source.

### A.3 Exclusions — manual OWNER trades (`magic=0`)

Per receipt row 1 (`decisions/2026-09-02_owner_receipts_ceo_asks.md`), OWNER verbatim: **"ja war ich selbst, kommt nicht mehr vor"**. The two `magic=0` positions are manual OWNER trades and are **EXCLUDED from every governed read**:

| date | symbol | volume | realized | note |
|---|---|---|---|---|
| 2026-07-27 | NDX | 1.00 lot | −1,537 USD | manual OWNER (CEO_AUDIT §3.1 line 14) |
| 2026-07-24 | EURUSD | 0.43 lot | −261 USD | manual OWNER (CEO_AUDIT §3.1 line 14) |

No magic-strip defect; forensic task closed. (In the 2026-08-04 export `magic=0` carries 12 rows including the 2026-04-24 "First deposit" BALANCE op and 3 DIVIDEND ops — those are account bookkeeping, not sleeve executions, and are likewise outside every governed read.)

### A.4 Exceptions list — trades that cannot be attributed to a signed governed identity (OWNER adjudication)

Source: `artifacts/audit_live_book_inventory_20260819.json` → `manifest_reconciliation.magics_in_logs_not_in_manifest`. Beyond `magic=0` (excluded above), **four governed-looking magics traded in T_Live logs that are NOT in the signed 24-sleeve roster.** These require OWNER adjudication (manual? unlabeled EA? stale deploy?).

All four facts below are from the cited 2026-08-22 audit's per-EA log rows (`rows[]`: `traded_ever`, `entries_accepted`, `last_trade_utc`).

| magic | implied ea/slot (symbol/TF) | traded? (audit 2026-08-22) | provenance / adjudication note |
|---|---|---|---|
| 104760004 | 10476 / slot 4 (USDCAD H1) | **NO** — `traded_ever=false`, `entries_accepted=0`, `last_trade=null` | Zero deals ever placed → **cannot appear in any track-record read.** Pure labeling exception (log emitted, no execution). |
| 106920005 | 10692 / slot 5 (NDX H1) | **YES** — `entries_accepted=2`, last trade **2026-07-10**; −153.70 net / 3 deal rows (08-04 export) | Last trade **predates the 2026-07-24 deploy epoch** → pre-deployment legacy EA activity, outside the governed 30-active-day window. This is a **provenance/labeling** ruling, not current governed-P&L leakage. |
| 107150004 | 10715 / slot 4 (USDJPY M15) | **NO** — `traded_ever=false`, `entries_accepted=0`, `last_trade=null` | Zero deals ever placed → **cannot appear in any track-record read.** Pure labeling exception. |
| 109400003 | 10940 / slot 3 (XAUUSD H4) | **YES** — `entries_accepted=1`, last trade **2026-06-29**; +14.74 net / 2 deal rows (08-04 export) | Last trade **predates the 2026-07-24 deploy epoch** → pre-deployment legacy activity, outside the governed window. Provenance/labeling ruling, not current-P&L leakage. |

**Interpretation.** Two of the four (10476, 10715) never placed a single deal as of the 2026-08-22 audit, so they cannot contaminate any P&L read — they are label-only drift. The two that did trade (10692, 10940) last executed **before the 2026-07-24 deploy epoch** (`live_deployment_pointer.json` deployment epoch 2026-07-24T06:42Z), i.e. legacy pre-deployment activity, almost certainly outside the governed 30-active-day window the CEO audit measures. The open question for OWNER is therefore **provenance/labeling** (why did governed-shaped magics run outside the signed roster — manual? unlabeled EA? stale deploy?), not whether −469/30d is being polluted today. Confirming that none has traded *since* the 2026-08-22 audit is a read-only re-run (→ section C item 2).

### A.5 Uncertainty statement (with arithmetic)

Authoritative source: `docs/ops/CEO_AUDIT_2026-09-02.md` lines 14 and 43.

- **Raw live book since 2026-07-19:** −2,227 USD.
- **Manual `magic=0` (excluded):** 27.07 NDX −1,537 + 24.07 EURUSD −261 = **−1,798 USD gross**; the CEO audit attributes **~76 %** of the realized loss to these two untagged trades.
- **Costs:** 5.7 % of the raw loss.
- **Governed book (manual trades removed):** **−469 USD over 30 active days.** (Note the transparent reconciliation gap: −2,227 − (−1,798) = −429; the −469 governed figure differs by ~40 USD because the audit allocates costs and other bookkeeping across the governed set — the audit's −469 is the maintained number; the −429 is the naive two-line subtraction. This ~40 USD delta is disclosed, not hidden.)
- **Governed Sharpe:** −1.10 ± 2.90 over 30 active days; **Sharpe CI [−6.8, +4.6]** — i.e. the confidence interval spans both large-negative and large-positive, so the sign of the governed edge is **statistically undetermined**.
- **Multiplicity:** **DSR ≥ 0.95 = 0/24 sleeves** at every N ≥ 10; E[max annualized Sharpe] under the null ≈ 1.06–1.44; the modeled book Sharpe +2.13 is diversification of individually insignificant edges.
- **Honest verdict:** the governed live edge is **unproven, not disproven.** 30 active days at a wide-CI negative mean is far too little signal to conclude anything; the cheapest decisive test is a 2026-Q1 out-of-sample pass (~3 terminal-hours, never run — CEO_AUDIT §3.2). **Track-record staleness caveat:** the −469/30d figure and per-sleeve MNT-036 breakdown live only in the session scratchpad referenced by the CEO audit (`wave1/mnt036_delta_2026-09-02.md`, `audit_synthesis.md`), **not committed to the repo**; the freshest committed per-deal export is 2026-08-04. A current per-sleeve governed attribution requires a fresh export.

---

## B. Candidate feasibility — 8 sealed FTMO-target pairs

Scope note: these 8 are the Q10_NEWS-sealed FTMO-target set, **distinct** from the 24-sleeve live DXZ book (only 10706/GBPUSD and 11421/EURUSD overlap both). Pipeline status confirmed from the farm DB (`file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro`, read 2026-09-05): Q08 `done` and Q10_NEWS `CONFIG_LOCKED` as of 2026-09-04 for all; **11910/NZDUSD Q08 = FAIL_SOFT** (scored PASS-class per census rule, receipt row 2), the other seven Q08 PASS.

### B.1 Identity & signal basis

| candidate | target magic | source | Q08 | Q10_NEWS | signal TF (median-hold proxy) | n_trades (Q08 baseline) |
|---|---|---|---|---|---|---|
| 10706/GBPUSD | 107060001 | magic_numbers.csv | PASS | CONFIG_LOCKED | **H1** (shortest hold) | 360 |
| 11421/EURUSD | 114210000 | magic_numbers.csv | PASS | CONFIG_LOCKED | D1 (multi-day) | 91 |
| 11422/USDCAD | 114220004 | magic_numbers.csv | PASS | CONFIG_LOCKED | D1 (multi-day) | 195 |
| 11910/NZDUSD | 119100006 | magic_numbers.csv | **FAIL_SOFT** | CONFIG_LOCKED | D1 (multi-day) | 63 |
| 13054/XTIUSD | 130540000 | magic_numbers.csv | PASS | CONFIG_LOCKED | D1 (multi-day) | 96 |
| 1537/XAGUSD | 15370001 | magic_numbers.csv | PASS | CONFIG_LOCKED | D1 (multi-day) | 60 |
| 20048/XTIUSD | 200480000 | magic_numbers.csv | PASS | CONFIG_LOCKED | D1 (multi-day) | 116 |
| 21505/XAGUSD | 215050000 | magic_numbers.csv | PASS | CONFIG_LOCKED | D1 (multi-day) | 82 |

**Median holding period:** no pre-computed median-hold field exists in the Q08 aggregates. The clean proxy is the signal timeframe: **7 of 8 are D1 strategies → multi-day holds → multiple swap accruals per trade** (swap-exposed for a Swing account); only 10706/GBPUSD is H1 (shortest hold). Exact per-position median requires parsing each sealed baseline `report.htm` deal list (e.g. `D:/QM/reports/pipeline/QM5_11421/Q08/_baseline/QM5_11421/20260902_193230/raw/run_01/report.htm`) pairing entry/exit by position id — **computable, not yet computed; flagged as a Part-1 compute step**, not a MISSING source.

### B.2 Per-symbol feasibility

Leverage from `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V2.json:254-261` (`ftmo_swing_leverage`: fx 1:30, metals 1:15, oil 1:15) — but **UNVERIFIED**: `docs/ops/evidence/2026-09-04_ftmo_official_rules_snapshot.json` marks both as `CARRIED_OVER` because the source URL `https://ftmo.com/en/trading-symbols/` returned **HTTP 404 on 2026-09-04** and the literal tokens `1:30`/`1:15` are absent from all eight retained bodies ("must be re-sourced before any decision that depends on them"). **Corroboration (not verification):** the same values were provider-captured earlier — `docs/ops/evidence/2026-07-30_ftmo_book3_symbol_cost_snapshot.json` (`leverageSwing=30` fx, `=15` XAU/XTI). Contract sizes from `framework/registry/venue_cost_model.json`; commission classes from `framework/registry/live_commission.json` (forex flat $5/lot RT, commodity $0/lot RT + 0.005 %/notional worst-case). DXZ tradability from `framework/registry/dwx_symbol_matrix.csv` (memory rule: tradability ALWAYS against the matrix).

| symbol (candidates) | DXZ tradability (matrix) | FTMO Swing leverage | margin (see profile caveat below) | contract size | swap (Swing) | news blackout (FTMO Swing) |
|---|---|---|---|---|---|---|
| GBPUSD (10706) | **UNCONFIRMED** — `live_order_status` EMPTY (canonical_name_verified=true only), matrix line 22 | 1:30 (**UNVERIFIED**, 404) | STANDARD 1 % (`marginPercent=1` = 1/leverageStandard 100, 07-30 snapshot); **Swing ~3.33 % UNVERIFIED** (1/30 derived — no swing-margin field on disk) | 100,000 (FX std) | **MISSING** — no source on disk | **NONE** (rulepack `ftmo_swing_news.restricted=false` + provider RE_CONFIRMED 2026-09-04 — see B.4) |
| EURUSD (11421) | **UNCONFIRMED** — EMPTY, matrix line 16 | 1:30 (**UNVERIFIED**) | STANDARD 1 %; **Swing ~3.33 % UNVERIFIED** (1/30 derived) | 100,000 | **MISSING** | **NONE** (see B.4) |
| USDCAD (11422) | **UNCONFIRMED** — EMPTY, matrix line 31 | 1:30 (**UNVERIFIED**) | STANDARD 1 %; **Swing ~3.33 % UNVERIFIED** (1/30 derived) | 100,000 | **MISSING** (also absent from venue_cost_model per-symbol) | **NONE** (see B.4) |
| NZDUSD (11910) | **UNCONFIRMED** — EMPTY, matrix line 28 | 1:30 (**UNVERIFIED**) | STANDARD 1 %; **Swing ~3.33 % UNVERIFIED** (1/30 derived) | 100,000 | **MISSING** (also absent from venue_cost_model per-symbol) | **NONE** (see B.4) |
| XTIUSD (13054, 20048) | **UNCONFIRMED** — EMPTY, matrix line 38 | 1:15 oil (**UNVERIFIED**) | STANDARD 2 % (`marginPercent=2` = 1/leverageStandard 50, 07-30 snapshot); **Swing ~6.67 % UNVERIFIED** (1/15 derived) | 1000 bbl (DWX) → FTMO USOIL.cash 100 bbl (10×) | swap_long **+4.22** pts / short **−26.8** pts, triple Wed (07-30 snapshot; **hostile short**, positive-carry long); *must be hash-bound before use* | **NONE** (see B.4) |
| XAGUSD (1537, 21505) | **UNCONFIRMED** — EMPTY, matrix line 35 | 1:15 metals (**UNVERIFIED**) | **MISSING** — 07-30 snapshot captured XAU only, not XAG (Swing ~6.67 % would derive from 1/15, but leverage itself UNVERIFIED) | 5000 oz | **MISSING** — no XAG swap in any snapshot | **NONE** (see B.4) |

**Margin profile caveat (major correction):** the 07-30 snapshot’s `marginPercent` field is the **STANDARD-profile** margin — it equals `1/leverageStandard` exactly (1/100 = 1 % FX, 1/50 = 2 % oil/metal). The snapshot carries **no swing-margin field** (`marginSwing`/`margin_swing` absent). Under the FTMO **Swing** profile this section is scoped to (1:30 FX / 1:15 metals+oil), the correct margin is `1/leverageSwing` = **~3.33 % FX / ~6.67 % metals+oil** — i.e. **~3.3× the standard-profile number**, materially less lot-sizing headroom. Both Swing-derived figures are **UNVERIFIED** because the leverage they derive from is itself UNVERIFIED (2026-09-04 trading-symbols URL 404 → CARRIED_OVER; no swing-margin field was ever captured). Do **not** size against the 1 %/2 % standard-profile cells under a Swing header.

*(For reference, SP500 is the only symbol in the matrix with `live_order_status=ORDER_ROUTABLE_CONFIRMED`, matrix line 29 — none of the 8 candidates carry that record.)*

### B.3 Swap feasibility — the decisive gap

- **Governed registry has zero swap data:** `framework/registry/venue_cost_model.json` sets `swap_note=null` for every symbol; `open_axes_not_covered.swap` = *"OPEN for all symbols … no real swap numbers exist on disk … never invented."* Resolve by a T1 script exporting `SYMBOL_SWAP_MODE/LONG/SHORT/ROLLOVER3DAYS`.
- **Only captured swaps** (non-registry, `docs/ops/evidence/2026-07-30_ftmo_book3_symbol_cost_snapshot.json`): XTIUSD long +4.22 / short −26.8 (triple Wed); XAUUSD long −66.21 / short −23.55; USDJPY long +0.92 / short −19.78. **None of these three is a majority of the candidate set.**
- **MISSING for candidates:** XAGUSD (1537, 21505) and all four FX candidates (GBPUSD, EURUSD, USDCAD, NZDUSD) have **no swap source on disk**.
- **Adoption caveat:** `docs/ops/evidence/2026-07-31_book3_sealed_validation_review.md:187` warns the snapshot swap "must be explicitly adopted, hash-bound, and interpreted" before use — it is not yet bound into the governed cost model.
- **Feasibility read (honest):** with 7 of 8 candidates on D1 multi-day holds, swap accrues every night the position is open, so swap sign/magnitude is material to Swing viability — yet it is **MISSING for 6 of the 8** and only the two XTIUSD candidates have a (unbound, short-hostile) captured value. **A precise Swing swap-feasibility statement cannot be made from disk today.** CEO_AUDIT §3.4 summary: "only a handful of sleeves are Swing-compatible."

### B.4 News blackout under the FTMO Swing profile

**No effective provider blackout to model.** `FTMO_2S_100K_SWING_V2.json:184-192` (`ftmo_swing_news`) sets `evaluation_restricted=false` and `ftmo_account_swing_restricted=false` ("the published selected-news restriction does not apply to Swing FTMO Accounts"); `:195-203` (`ftmo_swing_weekend`) likewise false.

**Freshly provider-confirmed on 2026-09-04 (HTTP 200 — NOT tainted by the leverage 404).** The news and weekend no-restriction facts were RE_CONFIRMED against the live FTMO pages in the same 2026-09-04 fetch batch that 404'd on trading-symbols: `docs/ops/evidence/2026-09-04_ftmo_official_rules_snapshot.json` source_id **`ftmo_news_official`** (HTTP 200) — evidence_quote *"The Swing account type have no restrictions on trading during news releases."* — and source_id **`ftmo_weekend_official`** (HTTP 200) — evidence_quote *"The Swing account type does not have any restrictions on holding positions overnight or over the weekend."* (raw bodies `docs/ops/evidence/ftmo_fetch_20260904/ftmo_news_official.html`, `…/ftmo_weekend_official.html`; both quotes machine-checked as literal substrings). So the **NONE** blackout conclusion is provider-current confidence, distinct from the UNVERIFIED/CARRIED_OVER leverage from the same batch.

The only temporal-OFF semantics that apply are QM's **own optional** guardrail `qm_ftmo_midnight_entry_window` (`:384-398`: block new entries 23:50–00:10 Europe/Prague around the CE(S)T daily-loss reset) — classification `INTERNAL_QM_POLICY_NOT_PROVIDER_RULE`, status `PROPOSED_FOR_CALIBRATION`, **not a provider rule**.

---

## C. OWNER action list

### C.1 Only the OWNER can do / verify

1. **SIGN the deploy pointer.** `D:/QM/reports/state/live_deployment_pointer.json` is `signed=False` / `approved_by=None`; the governed book runs against an unsigned pointer. Signing lifts the SP-A1/A2 risk-freeze. Receipt row 3 = "ja" (06.09 session). *Only OWNER.*
2. **ADJUDICATE (rule on) the 4 drift magics** `[104760004, 106920005, 107150004, 109400003]` that appear in T_Live logs outside the signed roster (A.4). The **ruling itself** — manual? unlabeled EA? stale deploy? keep or purge the label? — is *Only OWNER*. The facts are already established (A.4): two (10476, 10715) never placed a deal (pure label drift), the two that traded (10692, 10940) last executed 2026-07-10 / 2026-06-29, both **before** the 2026-07-24 deploy epoch → pre-deployment legacy, not current-book contamination. The read-only data-gathering to confirm none has traded *since* the 2026-08-22 audit is **AI-commissionable, not OWNER work** → moved to C.2.
3. **FTMO client-area terms** (login-gated, the 404'd public URL cannot supply them): (a) confirm Swing leverage **1:30 FX / 1:15 metals+oil** (currently CARRIED_OVER/UNVERIFIED); (b) current trading-symbols availability list — the FTMO-tradability question for the 8 candidates that the DXZ matrix cannot answer; (c) per-symbol margin & swap for **XAGUSD** and the **four FX candidates** (the exact MISSING cells in B.2/B.3). *Only OWNER.*
4. **Create the FTMO demo / Free-Trial account** for the execution-fidelity export (`ftmo_free_trial_gate`, rulepack `:494-499`). This is the non-purchase path to a real symbol/margin/swap capture. *Only OWNER (account creation).*
5. **PURCHASE stays excluded.** The 2026-09-05 blanket release — OWNER verbatim **"Alles, bis auf den Kauf, freigegeben, das uns dem Ziel näher bringt!"** (03:53Z 2026-09-05) — is recorded across receipt rows 9-17 of `decisions/2026-09-02_owner_receipts_ceo_asks.md`, each carrying that quote with the purchase explicitly excluded (this P7b task is bound as **row 16**). The FTMO NO-BUY park stands, re-anchored to positive OOS/live edge evidence (receipt row 6, CEO_AUDIT §5 ask 6). *`ftmo_owner_purchase_gate` (rulepack `:500-505`) is a separate signed OWNER decision — not requested here.*

### C.2 Blocked / to be commissioned

- **DXZ order-routability for the 8 candidate symbols** is UNCONFIRMED in `dwx_symbol_matrix.csv` (only SP500 confirmed). Note: for an FTMO Swing feasibility read the binding tradability authority is **FTMO's** symbol list, not DXZ's — so this is subordinate to C.1 item 3(b), not a substitute for it.
- **T1 swap-export task** to fill the `venue_cost_model` swap gap (`SYMBOL_SWAP_MODE/LONG/SHORT/ROLLOVER3DAYS` for the 8 candidate symbols) is commissionable under standing authorization (GRÜN infra measurement, ≤1h factory time), but is a factory-terminal action outside this read-only Part-1 scope — flag for commissioning, then the captured values must be explicitly adopted and hash-bound per the 2026-07-31 review.
- **Fresh live-deals export / per-EA log parse** to reproduce the current governed −469/30d figure per sleeve (A.2/A.5 staleness gap) — commissionable, read-only against T_Live journals, but not yet run.
- **Fresh `audit_live_book_inventory.py` re-run + per-EA log parse (read-only)** to confirm whether the four drift magics (A.4) still emit / trade after the 2026-08-22 audit — this is the data-gathering behind C.1 item 2's OWNER ruling; commissionable under standing authorization (GRÜN read-only measurement), not an OWNER action itself.
- **2026-Q1 OOS diagnostic** (~3 terminal-hours, non-admission) is the cheapest decisive edge test but remains **PENDING the 2026-09-05 positive-evidence acceptance test OWNER ratification** — Part 1 opens no sealed result and stays inside that boundary.

---

## Evidence index

- `D:/QM/reports/state/live_deployment_pointer.json` — governed roster (24 sleeves; `signed=False`; account 4000090541; per-sleeve magic + ex5_sha256 + RISK_PERCENT)
- `artifacts/audit_live_book_inventory_20260819.json` — `manifest_reconciliation` status=DRIFT; `magics_in_logs_not_in_manifest=[0,104760004,106920005,107150004,109400003]`; `pointer_signed=false`
- `tools/strategy_farm/portfolio/audit_live_book_inventory.py` — read-only reconciliation tool (no `live_attribution`/`track_record`/`mnt_036` script exists; MNT-036 delta is a scratchpad memo)
- `D:/QM/reports/portfolio/invvol_stage1_20260804/input_snapshots/live_deals_normalized.csv` — freshest committed per-deal export (2026-08-04, STALE + PARTIAL)
- `docs/ops/CEO_AUDIT_2026-09-02.md:14,43` — governed −469 USD / 30 active days; Sharpe CI [−6.8,+4.6]; DSR≥0.95 = 0/24
- `decisions/2026-09-02_owner_receipts_ceo_asks.md` — row 1 (magic=0 manual OWNER, excluded); rows 9-17 (2026-09-05 blanket release, verbatim "Alles, bis auf den Kauf, freigegeben"; this P7b task = row 16; 18 rows total); row 6 (NO-BUY re-anchor)
- `framework/registry/magic_numbers.csv` — candidate magics (107060001, 114210000, 114220004, 119100006, 130540000, 15370001, 200480000, 215050000)
- `framework/registry/dwx_symbol_matrix.csv` — all 8 candidate symbols `live_order_status` EMPTY; SP500 = ORDER_ROUTABLE_CONFIRMED
- `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V2.json:184-203,254-261,384-398,494-505` — Swing leverage / news / weekend / midnight window / gates
- `docs/ops/evidence/2026-09-04_ftmo_official_rules_snapshot.json` — trading-symbols URL HTTP 404; swing leverage CARRIED_OVER/UNVERIFIED
- `docs/ops/evidence/2026-07-30_ftmo_book3_symbol_cost_snapshot.json` — leverageSwing 30/15; marginPercent 1/2; swap XTI +4.22/−26.8, XAU −66.21, USDJPY +0.92/−19.78 (3 symbols only)
- `docs/ops/evidence/2026-07-31_book3_sealed_validation_review.md:187` — snapshot swap must be adopted/hash-bound before use
- `framework/registry/venue_cost_model.json` — XAG 5000oz, XTI 1000bbl, commission; `swap_note=null` everywhere; NZDUSD & USDCAD absent per-symbol
- `framework/registry/live_commission.json` — worst-case classes (forex $5 flat / commodity $0 flat, both 0.005 %/notional RT)
- `docs/ops/evidence/2026-09-04_astra_ftmo_inventory.json` — Part-0 predecessor (qualified_pairs=8)
- Farm DB `file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro` — Q08/Q10_NEWS status per candidate (read 2026-09-05)

*Drafter: Claude (Factory CEO lane), task 8c561172. Read-only pass; no purchase, no T_Live action, no AutoTrading toggle.*
