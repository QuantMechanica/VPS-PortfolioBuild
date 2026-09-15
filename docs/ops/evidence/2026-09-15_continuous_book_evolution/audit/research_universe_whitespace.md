# Research Universe & External-Harvest ROI — White-Space Audit

**Task:** `research_universe_whitespace` (OWNER directive 2026-09-15 §44–§46, §49–§50)
**Auditor:** Claude (read-only subagent), 2026-09-15
**Sources:** `D:/QM/strategy_farm/state/farm_state.sqlite` (mode=ro), `framework/registry/*`, `framework/EAs/*`, card stores on C:/D:.
**Companion CSVs (this dir):** `universe_matrix.csv`, `universe_family_symbolclass.csv`, `harvest_funnel.csv`, `economic_failures_family_symbol_gate.csv`.

---

## Headline (3 lines)

1. The research universe is **~5,147 catalogued EA ideas / 4,089 built EAs**, but ~52% collapse into two families (**trend/momentum 28% + an unclassifiable "other" 27%**); the entire universe is **timeframe-heavy at D1/H1 (61% of Q02 pairs) and almost session-blind (95% of pairs have no session tag)** — the exact white space §46 and the FTMO mission (§47–§48) value most (intraday, scalp, session/ORB).
2. The harvest funnel is brutally lossy: **14,935 Q02 pairs → 54 Q08 PASS pairs → 55 DXZ book pairs** (≈0.37% of tested pairs reach a book); the tracked source ledger holds only **118 sources (96 done)** + 664 seed folders, so the directive's "tens of thousands of sources" is **not measurable in current metadata** and per-EA origin (external-harvest vs internal-discovery) is **not tagged**, blocking the §49 ROI split.
3. The failed population is large and structured — **~12,850 distinct economic-FAIL pairs**, concentrated at **Q04 (6,396) and Q02 (5,322)** on **EURUSD/GBPUSD/XAUUSD/USDJPY** in trend/momentum and "other" — a ready OBSERVE seed for §45 failure mining; `observe_projector.py` can already emit the funnel + failure population but is **missing timeframe, session/time-of-day, holding-duration, parameter-sensitivity and trade-level (MAE/MFE, correlation) fields**.

---

## Findings

### 1. Universe size and family concentration
- Catalogued EA ideas (registry ∪ built dirs): **5,147**; distinct built EAs (dir with `.ex5`/`.mq5`): **4,089** (`framework/registry/ea_id_registry.csv` = 4,900 rows; `framework/EAs/` = 4,124 dirs). Evidence: `harvest_funnel.csv`; script `scratchpad/analyze.py`.
- Family split (built EAs), deterministic slug classifier: `other 1,365 (33%)`, `trend/momentum 1,155 (28%)`, `breakout 298`, `oscillator/other 290`, `mean-reversion 287`, `basket/statarb 198`, `range/fade 167`, `session/ORB 157`, `pullback 75`, `grid/pyramid 51`, `pattern 46`. Evidence: `analyze.py` stdout; `universe_family_symbolclass.csv`.
- **Caveat:** the "other" bucket (~33%) is dominated by author-named anomaly/rotation/seasonal/value ideas (davey-, singh-, chan-, as-/aa-/qp-, unger-, estrada-, halloween-sell-in-may) whose mechanism is not inferable from the slug alone. The mechanism family is **not a first-class registry field** — it is only a slug heuristic (both here and in `observe_projector.classify_family`). Finding: the universe has no authoritative mechanism taxonomy.

### 2. Timeframe / holding-duration skew (Q02-tested pairs)
Distribution of the 14,935 Q02 (ea×symbol×tf) rows (`universe_matrix.csv`):
- Timeframe: **D1 5,566 · H1 3,591 · H4 2,455 · M15 1,450 · M5 1,225 · M30 454 · M1 284 · W1 65 · MN1 8**.
- Holding class: **position (D1+) 5,639 · intraday (M30–H1) 5,495 · swing (H4) 2,455 · scalp (M1–M5) 1,509**.
- White space: **scalp (M1–M5) is only ~10%** of tested pairs and **M30 is thin (3%)**. §48 explicitly permits scalping / high-frequency-enough intraday for FTMO — this is under-served.

### 3. Session blindness (the sharpest white space for §46/§47)
Session inferred from slug (`universe_matrix.csv`): **unspecified 14,239 (95.3%)** · session-open 446 · overnight/seasonal 311 · london 108 · asian 64 · ny 48.
- Only ~4.7% of tested pairs carry any session/time-of-day intent. Opening-range (ORB), London/NY session and Asian-box systems — named in §48 as prime FTMO directions — are a near-empty cell. This is the highest-value, cheapest-to-fill white space.

### 4. Symbol universe concentration
Q02 activity by symbol (work_items): XAUUSD 20,102 · EURUSD 17,561 · GBPUSD 14,901 · USDJPY 14,095 · NDX 13,044 · XTIUSD 10,136 · GDAXI 7,393 · SP500 6,154 · WS30 6,118 · then a long FX-cross tail. Evidence: `analyze.py` symbol query. FX crosses and second-tier indices (UK100) are thin; the book (§4 below) already leans on the same majors/metals/indices, so symbol diversification white space overlaps with FTMO venue-fitness (§57).

### 5. The external-harvest funnel and stage ROI
Distinct ea×symbol pairs by gate (`harvest_funnel.csv`; PASS = taxonomy `strategy`, verdict `PASS*`):

| Stage | reached (pairs) | PASS (pairs) | survival vs prev |
|---|---|---|---|
| Q02 | 14,935 | 7,272 | — |
| Q03 | 2,241 | 2,070 | |
| Q04 | 7,242 | 836 | Q04 is the main economic filter |
| Q05 | 854 | 444 | |
| Q06 | 449 | 406 | |
| Q07 | 407 | 302 | |
| Q08 | 314 | **54** | second hard economic wall |
| Q09 | 145 | 125 | |
| Q11 | 33 | 32 | portfolio-candidate stage |
| DXZ book | **55** | — | `dxz23_execution_contracts.json` (55 pairs) |

- End-to-end yield: **55 book pairs / 14,935 Q02 pairs ≈ 0.37%**; **54 Q08 PASS / 14,935 ≈ 0.36%**. Two economic walls dominate: **Q04** (7,242→836) and **Q08** (314→54).
- Late-gate PASS tokens (Q10_NEWS, Q12, Q13, Q14) are **not** the string `PASS*` (they use `MODE_SELECTED`, `CONFIG_LOCKED`, `MULTI_SEED_*`, etc.), so PASS_pairs reads 0 there — use `reached` for Q10+; terminal Q14 = **34 pairs reached** (`work_items` phase=Q14). This matches the OWNER counter counting terminal Q14 pairs.

### 6. External-vs-internal ROI split is currently unmeasurable
- The tracked `sources` table holds **118 rows** (done 96 / pending 13 / blocked 9), types web_blog 41, mql5_codebase 26, book 16, paper 13, forum 10 (`analyze.py` sources query). Seed-source folders: `strategy-seeds/sources` = **664**.
- There is **no per-EA origin field** separating external-harvest from internal autonomous discovery. The registry `owner` column is a mission/agent label (Research 2,911 / Development 418 / agent names), not an origin class; slug prefixes (author name ⇒ external; `edgelab-`, `claude_cross_asset_discovery_` ⇒ internal) are only a proxy. **Consequence: EXTERNAL HARVEST ROI vs INTERNAL DISCOVERY ROI (§49) cannot be computed from current metadata** — this is the single blocking gap for the §49 allocation decision.

### 7. Economic-failure population (§45 seed) — large and clustered
- Excluding INFRA / measurement / invalid / setup and no-signal (ZERO_TRADES = 1,195 pairs held out), genuine economic FAILs total **~12,850 distinct family×symbol×gate pairs** (`economic_failures_family_symbol_gate.csv`).
- By gate: **Q04 6,396 · Q02 5,322** · Q05 422 · Q08 231 · Q03 129 · rest <100.
- By family: other 4,289 · trend/momentum 3,873 · mean-reversion 1,052 · oscillator/other 1,021 · breakout 979 · session/ORB 470 · basket/statarb 315 · range/fade 313 · pullback 193 · pattern 174 · grid/pyramid 76.
- Top clusters (distinct fail pairs): trend/momentum×EURUSD×Q04 (304), other×EURUSD×Q04 (276), trend/momentum×GBPUSD×Q04 (271), other×GBPUSD×Q04 (247), other×XAUUSD×Q04 (233), trend/momentum×USDJPY×Q04 (216). The FX-majors trend/momentum-at-Q04 cluster is the densest negative-knowledge seam for §45.

### 8. What `observe_projector.py` can already build vs what is missing
- **Already emits** (`tools/strategy_farm/research/observe_projector.py`, dataset `qm.research-dataset/v1`, read-only, taxonomy-split): `gate_outcomes.csv` (ea_id, symbol, phase, verdict, verdict_taxonomy, reason_class, window, created), `ea_metrics.csv` (net_profit, profit_factor, trades, drawdown_money/pct, sharpe), `holds.csv`, `sources.csv`, `idea_families.csv` (slug→family). This is sufficient to reproduce **the funnel (§5)** and **the economic-fail population (§7)**.
- **Missing for §45 failure mining / §46 white space:** (a) **timeframe** (only in `setfile_path`, not projected) and (b) **session / time-of-day** — both required for §45 "time-of-day effects" and §46 session white space; (c) **holding-duration class**; (d) **parameter values / OPT_CENSUS sweep results** — required for §45 "parameters that do not matter" and regime work (parameter sensitivity is in `detail_json`/OPT_CENSUS, not the flat CSVs); (e) **trade-level fields** (MAE/MFE, entry-time, per-trade streams) for "recurring losing conditions" and cross-EA **correlation**; (f) **per-year/per-regime conditioning** (only a coarse `window` string today); (g) a **richer mechanism family** than the ~33%-"other" slug heuristic.

---

## Drift table

| Topic | Doc / directive says | Runtime says | Path |
|---|---|---|---|
| Sources processed | Directive §49: "after tens of thousands of sources" | `sources` table = 118 (96 done); seed folders = 664 | `farm_state.sqlite:sources`; `strategy-seeds/sources` |
| Origin ROI split | §49 requires EXTERNAL vs INTERNAL HARVEST ROI comparison | No per-EA origin field; `owner` col is mission/agent label, not origin | `framework/registry/ea_id_registry.csv` |
| Mechanism family | §46 asks "which mechanisms dominate / are missing" | No authoritative family field; only slug heuristic (~33% "other") | `observe_projector.classify_family`; `analyze.py` |
| DXZ book size | Vault/older refs treat book as fixed set | 55 pairs in current contract `DXZ-23-2026-07-fidelity-remediation` (file updated 2026-09-15) | `framework/registry/dxz23_execution_contracts.json` |
| Session coverage | §47/§48 prioritise session/ORB/intraday for FTMO | 95.3% of tested pairs have no session tag; scalp = 10% | `universe_matrix.csv` |

---

## Open questions strictly requiring OWNER

None. All items below are implementable within existing tooling and the standing authorization; the origin-tagging gap (§6) is an engineering task, not an OWNER decision.

---

## Recommended actions (for the implementing phases)

1. **Extend `observe_projector.py`** (`tools/strategy_farm/research/observe_projector.py`) to add, per gate_outcomes row: `timeframe` (regex on `setfile_path`), `session` and `holding_class` (from slug + tf), and `symbol_class`. This directly unblocks §45 time-of-day mining and §46 session white space. Emit a new `parameter_sensitivity.csv` sourced from `OPT_CENSUS` / `ea_metrics.detail_json`.
2. **Add a per-EA `origin` field** to `framework/registry/ea_id_registry.csv` (values: `external_source` / `internal_discovery` / `owner_mission`), backfilled from slug prefix + `sources` join, so §49 EXTERNAL vs INTERNAL ROI becomes computable. Until then, treat the §49 ROI comparison as **GAP**.
3. **Seed §45 failure-mining** on the densest clusters first (`economic_failures_family_symbol_gate.csv`): trend/momentum & "other" × {EURUSD,GBPUSD,XAUUSD,USDJPY} × Q04, and the Q02 no-signal (ZERO_TRADES) population (1,195 pairs) as a separate "setup/parameterisation" study — never mixed with economic FAILs (§44).
4. **Prioritise white-space cards** (feed the ready-card reservoir, throttled per routing contract) toward the empty cells in `universe_matrix.csv`: session/ORB and scalp/intraday on the majors already in the book — the intersection of §46 white space and §47/§48 FTMO needs. Avoid new D1 trend/momentum cousins (§40, §46 "do not endlessly create cousins").
5. **Add a mechanism-family field** or upgrade the slug heuristic so the ~33% "other" bucket is resolved before white-space metrics are used for allocation decisions.
