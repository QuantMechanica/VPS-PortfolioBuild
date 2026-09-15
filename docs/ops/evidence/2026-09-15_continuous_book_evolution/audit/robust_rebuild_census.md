# Robust / Commercial / Reference Rebuild Census — runtime-resolved

**Task:** OWNER directive 2026-09-15 §55–§56 (`docs/ops/evidence/2026-09-15_continuous_book_evolution/owner_directive_verbatim.md:1356`).
**Auditor:** read-only subagent. **Date:** 2026-09-15.
**DB:** `D:/QM/strategy_farm/state/farm_state.sqlite` (opened `?mode=ro`). **Repo:** `C:/QM/repo` (branch `agents/board-advisor`).

---

## Headline (3 lines)

1. The only "robust/commercial/reference rebuild" family that reached the top of the pipeline is **René Balke Range Breakout**: **QM5_13213 (USDJPY)** and **QM5_13301 (GDAXI)** are actually **LIVE in the DXZ book** (deals in `C:/QM/mt5/T_Live/.../journal/live_deals_normalized.csv`), while `portfolio_candidates` still marks both `EVIDENCE_STALE` — a runtime-vs-DB drift.
2. Gold Reaper (Wim Schrynemakers) was **investigated and rejected as a clone** (`docs/research/GOLD_REAPER_BREAKOUT_MINING_2026-07-23.md`); seed card `QM5_31008` is `status: REJECTED` and was never built into `framework/EAs/`. Balke's own gold leg (`QM5_13213 XAUUSD`) is `Q02 RETIRE`.
3. The whole Balke USDJPY optimisation strand (QM5_41097/41324/41398/41405, thousands of `OPT_CENSUS` rows, all `NOT_APPROVED` research instruments) is stalled behind a `BALKE_PATTERN_REPAIR_REVIEW_PENDING` hold and a machine-wide `NEWS_CALENDAR_TAINTED` pin; the 2026-09-11 window sweep proves a **better window exists** (`s0_l8` = 00:00–08:00 UTC+3, OOS costed PF 1.21) than the deployed 03:00–06:00.

---

## Findings (numbered, each with evidence)

### A. René Balke Range Breakout family (the core §55 target)

**F1 — QM5_13213 `balke-gmt3-range-breakout` (canonical Balke, USDJPY) is LIVE and at the pipeline top.**
- Source / R1: "René Balke ForexFactory Range Breakout, exact-parameter port (OWNER-verified via agy analysis 2026-07-13); ported from QM5_9936 `ff-range-breakout-gmt3-h1`" — `framework/EAs/QM5_13213_balke-gmt3-range-breakout/SPEC.md:5`.
- Mechanics: builds completed 03:00–06:00 GMT+3-equiv H1 range; at 06:00 places buy-stop at range high / sell-stop at range low, initial stop opposite side, no fixed TP; skips day if range <0.4× or >2.5× ATR(14,H1); +1R two-bar trail; single evening resolution 18:00 GMT+3; opposite-side touch exit. Differs from parent QM5_9936 only in `range_start_hour 1→3` and collapsing 9936's 13:00/20:00 hours into one 18:00 exit (`SPEC.md:15-27`).
- Compiled ex5: 2026-08-25 (`framework/EAs/QM5_13213_balke-gmt3-range-breakout/QM5_13213...ex5`).
- Runtime gate (per-symbol, `work_items`): **USDJPY.DWX** Q02 PASS → Q03 PASS → Q04 PASS_SOFT → Q05 PASS → Q06 PASS → Q07 PASS → Q08 PASS (also FAIL_SOFT/INFRA_FAIL attempts) → Q09 PASS → Q10 PASS → **Q11 PASS**; Q09_PORTFOLIO = FAIL_PORTFOLIO; Q12 held. **XAUUSD.DWX = Q02 RETIRE.**
- Highest contiguous valid gate: **Q11** (USDJPY).
- Metrics at Q11 (`ea_metrics`): net **+114,284**, PF **1.16**, **1,624** trades, DD **22.8%** (backtest RISK_FIXED).
- Current blocker: two active holds on USDJPY (`work_item_holds`): `BALKE_PATTERN_REPAIR_REVIEW_PENDING` at Q12 (CEO-DEC-BALKE-PATTERN-RECOVERY-20260909) + `NEWS_CALENDAR_TAINTED` at Q09_NEWS (`PINNED_CALENDAR_TAINTED:86b2c0b5…`).
- Live status: **deployed to DXZ** — `C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/baselines/QM5_13213_USDJPY_DWX.json` (n=1624), kill-switch `ks_state_13213_132130000.state`, EA log `QM5_13213_ea-13213.log`, deals in `journal/live_deals_normalized.csv`.
- DXZ suitability: **already live**; modest but positive edge (PF 1.16), high trade count → real diversifier on USDJPY. FTMO suitability: high trade density (~1,624 full-history) is favourable, but backtest DD 22.8% must be scaled to FTMO's 10% total / 5% daily limits; **no formal Q10 FTMO recommendation exists** (Q10 aggregate `D:/QM/reports/pipeline/QM5_13213/Q10/USDJPY_DWX/aggregate.json` has no ftmo/recommend key) → **FTMO = UNKNOWN (formal)**.
- Est. remaining validation (USDJPY): Q12 (pattern-filter selection, currently held) → Q13 (param opt & freeze) → Q14 (head-to-head). Gold leg dead.

**F2 — QM5_13301 `balke-minute-range-breakout` (GDAXI, M5) is LIVE.**
- Source: "implementation as built", Codex, 2026-08-12 (`framework/EAs/QM5_13301_balke-minute-range-breakout/SPEC.md:5`). Balke range breakout re-expressed on an M5 clock.
- Mechanics: fixed GMT+3 clock; on M5 bar at range end scans the full 03:00–06:00 M5 window; if 0.4–2.5× H1-ATR(14) submits two-sided buy-stop/sell-stop (no TP), one set/day; opposite cancel on trigger; +1R trail to prior-two H1 lows/highs; 18:00 flat + range-boundary touch exit (`SPEC.md:13-30`).
- Compiled ex5: 2026-08-22.
- Runtime gate: **GDAXI.DWX** to Q08 PASS (PF 1.35, 551 trades), Q09 rows show FAIL with 0 trades (portfolio/infra branch), **Q10 PASS** (PF 1.28, 742 trades, DD 14.5%). Highest contiguous valid: **Q10** (Q09 mixed). NDX not run.
- Blocker: `NEWS_CALENDAR_TAINTED` holds at Q09_NEWS and Q10_NEWS (`work_item_holds`, since 2026-08-23 / 2026-09-04).
- Live status: **deployed to DXZ** — baselines `QM5_13301_GDAXI_DWX.json`, kill-switch `ks_state_13301_133010010.state`, EA log, deals in journal.
- DXZ suitability: **already live**; stronger single-EA profile than 13213 (PF 1.28–1.35, DD 14.5%). FTMO: UNKNOWN (no Q10 FTMO reco populated).
- Est. remaining validation: resolve calendar-tainted hold → Q11 → Q12–Q14.

**F3 — QM5_13036 `balke-go-long-regime` (NDX/GDAXI, M15) — NOT live, marginal edge.**
- Source: `YT-BALKE-FXBOT-2026-07` YouTube seed (`framework/EAs/QM5_13036_balke-go-long-regime/SPEC.md:5`; card `artifacts/cards_approved/QM5_13036_balke-go-long-regime.md`). Distinct mechanic from the range-breakout: time-window long-only index regime (SMA200 regime, ATR SL) with per-index entry/exit HHMM windows.
- Compiled ex5: 2026-08-03.
- Runtime gate: **GDAXI.DWX** Q02→Q10 PASS, Q10_NEWS = REVIEW_REQUIRED; **NDX.DWX = Q02 FAIL**. Highest contiguous valid: **Q10** (GDAXI).
- Metrics: Q09/Q10 PASS but **PF 1.04**, net +4,218, 1,352 trades (thin, near-breakeven).
- Blocker: `NEWS_CALENDAR_TAINTED` at Q09_NEWS.
- Live status: **not in T_Live** (no baseline/journal entry found). DXZ suitability: **weak** (PF 1.04 is marginal). FTMO: UNKNOWN, likely unsuitable at this edge.

**F4 — QM5_21501 `balke-gmt3-range-breakout-ppcensus` — census instrument, never deployable.**
- Source: instrumented derivative of QM5_13213, strategy_id unchanged `6e967762-…` (`framework/EAs/QM5_21501…/SPEC.md:5`). SPEC §0 states it "must never reach a book" — open-parameter DL-089 pattern-permission census subject.
- Runtime: USDJPY Q02→Q11 PASS (metrics identical to 13213: net +114,284, PF 1.16, 1,624 trades) — it is a measurement mirror, not an independent candidate.
- Blocker: `NEWS_CALENDAR_TAINTED` at Q09_NEWS. Not a deployment candidate by design (§56 class D duplicate-by-construction of 13213).

**F5 — Balke USDJPY optimisation strand QM5_41097 / 41324 / 41398 / 41405 — recent (Aug–Sep 2026) research rebuilds, all NOT_APPROVED.**
- All share strategy_id `6e967762-…` and parent QM5_21501/QM5_13213; DL-089 optimisation instruments (`framework/EAs/QM5_41097…/SPEC.md`, `…/QM5_41398…/docs/strategy_card.md`, `…/QM5_41405…/docs/strategy_card.md`).
  - **QM5_41097** `…-opt` — DL-089 A1-fixed pp-profile opt; ex5 2026-08-26; 1,094 rows (`OPT_CENSUS`, USDJPY).
  - **QM5_41324** `…-path25-opt` — path-to-25 opt; ex5 2026-09-03; 1,093 `OPT_CENSUS` rows (verdict MEASURED).
  - **QM5_41398** `balke-pattern-repair-opt` — CEO-DEC-BALKE-PATTERN-RECOVERY-20260909 repair sibling of 13213; ex5 2026-09-09; **1,722 rows**; subject of the window sweep.
  - **QM5_41405** `balke-clock-audit-opt` — newest (ex5 2026-09-11); clock/window/buffer audit; 969 rows; card `expected_trades_per_year=75`.
- Every card carries `execution_contract_status: NOT_APPROVED`, "not authorized for a book, T_Live, or AutoTrading" (`…/QM5_41398…/docs/strategy_card.md`, `…/QM5_41097…/SPEC.md:0`).
- **Key recent result:** window sweep stage-A (`docs/research/BALKE_WINDOW_SWEEP_RESULT_2026-09-11.md`) — 420/420 cells MEASURED, verdict **H-WIN KEPT (a better window exists)**: winner **s0_l8 = 00:00–08:00 UTC+3**, OOS pooled costed **PF 1.21**, plateau 2.0× the deployed 03:00–06:00 baseline. The live 13213 therefore runs a **suboptimal window** per the latest evidence.

**F6 — Earlier / dead Balke & USDJPY-range attempts.**
- **QM5_12700** `balke-range-breakout` (USDJPY M15, OWNER-directed port; Codex 2026-06-27) — died **Q07 FAIL** (highest contiguous Q06). ex5 2026-07-14.
- **QM5_1142** `usdjpy-time-range-breakout` (Crabel 1990 / Fisher 2002 ACD — *not* Balke; `SPEC.md:6`) — died **Q04 FAIL** on all 9 tested symbols (AUD/CAD/CHF/JPY crosses + USDJPY); highest contiguous Q03 (USDJPY).
- **QM5_11874** `usdjpy-24hr-range-breakout` — died **Q04 FAIL** (USDJPY/GBPJPY/AUDJPY); highest contiguous Q03.
- **QM5_21001** `balke-gmt3-range-breakout-exit-c1` (promotion challenger) — died **Q06 FAIL**; highest contiguous Q05.
- **QM5_5003** `legend-balke-session` — **0 work_items** (built dir only, never ran).
- **QM5_9936** `ff-range-breakout-gmt3-h1` (the *parent* range breakout Balke was ported from) — USDJPY reached **Q09 PASS**, Q10_NEWS REVIEW_REQUIRED, Q09_PORTFOLIO FAIL_PORTFOLIO; GBPUSD/NDX died Q04/Q02.

### B. Gold Reaper (Wim Schrynemakers)

**F7 — Gold Reaper: investigated, verdict "do NOT clone", never built.**
- Research dossier `docs/research/GOLD_REAPER_BREAKOUT_MINING_2026-07-23.md`: "Do NOT clone Gold Reaper… higher-production-value rebuild of a breakout we already tested and killed (Balke XAU)". Live Gold Reaper (Profalgo) DD 41.7%.
- Seed card `strategy-seeds/cards/QM5_31008_gold-reaper-order-block-mitigation.md`: `status: REJECTED`, `g0_status: REJECTED`.
- Runtime: **QM5_31008 has 0 work_items** and **no `framework/EAs/` dir** — never mechanised into the pipeline.
- Adjacent gold-breakout EAs: **QM5_9460** `gh-gold-orb` (XAU/XAG/WS30/GDAXI) died **Q02 FAIL** on all; **QM5_12425** `gold-orb` has **0 work_items** (dir only). Balke gold leg `QM5_13213 XAUUSD` = Q02 RETIRE.
- §56 class for Gold Reaper: **B/D** — existing-edge (XAU session breakout) that duplicates the already-killed Balke XAU death signature; correctly not pursued as independent diversification.

### C. ORB / opening-range / range-breakout reconstructions

**F8 — Large ORB population, but essentially none advanced past mid-pipeline except the Balke family above.**
- `framework/EAs/` holds ~80+ dirs matching orb/opening-range/range-breakout (e.g. `QM5_10181_tv-xau-ny-orb-retest`, `QM5_10633_et-orb-5m-tqqq`, `QM5_1062_unger-orb-index`, `QM5_1255_zarattini-qqq-orb`, `QM5_10930_grimes-nr7-orb`, `QM5_10954_ftmo-orb-fvg`, `QM5_31002_us-indices-opening-range-breakout`, `QM5_37002_dual-thrust-asymmetric-range-breakout`, `QM5_1099_dax-weekly-donchian50-breakout`, the `9988 tv-opening-range-breakout-dual`, etc.).
- Cross-referencing the 114 EAs that reached a Q08+ PASS (`work_items` query), **the only breakout/range/ORB reconstructions in that set are the Balke lineage (13213, 13036, 13301, 21501) plus the parent 9936**. No standalone ORB reconstruction (Zarattini, Unger ORB, Grimes NR7-ORB, FTMO-ORB-FVG, US-indices ORB) reached Q08+; the ORB cohort predominantly died at Q02–Q04.
- Implication for §55/§57: the "ORB reconstruction" bucket is currently **not a live diversification source**; only the Balke session-range variant survived.

### D. Other recent robust / commercial / reference rebuilds

**F9 — The named commercial/reference rebuild series (QM5_30000–41999) mostly died early.**
- Commercial-author rebuilds present as dirs (Unger, Kaufman KAMA, Larry Williams vol-expansion, Ernest Chan OU stat-arb, GARCH, Kalman, Sokolov, Golubev, Robert Pardo Checkmate `QM5_41002`, Guppy MMA, Babypips Asian-box, CodeTrading, ForexFactory 100-pips) — see `ls framework/EAs | grep -E '^QM5_3|^QM5_41'`.
- Max gate reached in the 30000–41999 band (`work_items`): the highest are **QM5_41219** `cum-rsi2-commodity-requal8` (Q11) and **QM5_41221** `ohlc-daily-squeeze-reversal-d1-requal8` (Q11) — these are **internal survivor-optimisation requal instruments, not commercial reference rebuilds**. **QM5_41161** `tv-mon-ls-opt` reached Q10_NEWS; **QM5_36002** `nnfx-kijunsen-absolute-strength-damiani` reached Q08. The remainder cap at Q05–Q08.
- Conclusion: no *commercial/reference* rebuild besides Balke is close to a book; the recent (Sep 2026) high-gate work in this ID band is internal optimisation/requal, outside §55's "commercial/reference" scope.

### E. §56 classification (deterministic evidence)

| EA | §56 class | Deterministic evidence |
|---|---|---|
| QM5_13213 (Balke USDJPY H1) | **B — existing edge, better implementation** (of parent QM5_9936) | Rule signature: only `range_start_hour` + exit-hour differ from 9936 (`SPEC.md:15-27`); both session-range straddle. |
| QM5_13301 (Balke GDAXI M5) | **E — materially distinct despite similar label** | Same "Balke range breakout" label but different symbol (GDAXI) and clock (M5 vs H1), no trade overlap possible (disjoint instruments). |
| QM5_13036 (Balke go-long GDAXI/NDX) | **E — materially distinct** | Not a range breakout at all — SMA200 regime long-only time-window (`SPEC.md §1`); shares only the "Balke" author label. |
| QM5_21501 (ppcensus) | **D — duplicate** | Instrumented derivative of 13213, identical strategy_id `6e967762…` and identical Q11 metrics (net/PF/trades match exactly). |
| QM5_41097/41324/41398/41405 | **C — config/parameter variant** | Same strategy_id `6e967762…`, parent 13213; differ only in pattern-permission profile / window / clock inputs (SPECs + cards). |
| Gold Reaper (QM5_31008) | **B/D — existing edge / clone of killed Balke XAU** | Dossier verdict + REJECTED card; Balke XAU already died (Q02 RETIRE). |

**Deterministic overlap gap:** no cross-variant **trade-overlap / return-correlation file** exists in the repo or `D:/QM/reports` linking these EAs' deal streams. The classifications above rely on **rule signatures + strategy_id + shared metrics + disjoint symbols**, which is sufficient for A/D/E but not for a numeric overlap between USDJPY-on-USDJPY variants (13213 vs the 41xxx opt siblings). The tool that *could* compute it: **`tools/strategy_farm/window_sweep.py`** (already does per-cell deal-list comparison — the balke pattern-recovery decision mandates "seven annual control deal-list comparisons", `decisions/2026-09-09_balke_pattern_recovery.md`), fed with the per-run `summary.json` deal lists under `D:/QM/reports/work_items/<id>/...`; a small deal-list correlation over `ea_metrics.detail_json` / those summaries would produce the numeric trade-overlap and return-correlation §56 asks for.

---

## Drift table (doc/vault says vs runtime says vs path)

| Doc/vault says | Runtime says | Path |
|---|---|---|
| `portfolio_candidates`: QM5_13213 USDJPY & QM5_13301 GDAXI = `EVIDENCE_STALE` (2026-08-22) | Both are **deployed live** in DXZ (baselines, kill-switch state, EA logs, deals) | `portfolio_candidates` row vs `C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/baselines/QM5_13213_USDJPY_DWX.json`, `journal/live_deals_normalized.csv` |
| SPEC 13213: designed for USDJPY **and XAUUSD** ("Balke's best-performing symbol") | XAUUSD leg = **Q02 RETIRE** (dead); only USDJPY survives | `framework/EAs/QM5_13213…/SPEC.md:44` vs `work_items` (QM5_13213, XAUUSD.DWX, Q02 RETIRE) |
| Deployed Balke 13213 window = 03:00–06:00 GMT+3 | Window sweep 2026-09-11: **better window s0_l8 = 00:00–08:00 UTC+3**, OOS costed PF 1.21 vs baseline plateau 0.78 | `docs/research/BALKE_WINDOW_SWEEP_RESULT_2026-09-11.md` |
| Memory/vault: 13036 = Balke go-long GDAXI+NDX candidate | NDX = Q02 FAIL; GDAXI only reached Q10 at **PF 1.04** (near-breakeven) | `MEMORY.md` vs `ea_metrics` (QM5_13036) |
| Q10 = "News Impact + FTMO Recommendation" (gate_manifest v4 / CLAUDE.md) | Q10 aggregates for 13213/13036/13301 carry **no FTMO recommendation field** (news-impact only) | `CLAUDE.md` vs `D:/QM/reports/pipeline/QM5_13213/Q10/USDJPY_DWX/aggregate.json` |

---

## Open questions strictly requiring OWNER

- None strictly required for the census. (Downstream, whether to re-window live 13213 to the swept optimum and whether to lift the calendar-tainted / pattern-repair holds are OWNER-gated ROT actions, but they are decisions for the implementing phases, not blockers to this read-only census.)

---

## Recommended actions for implementing phases (concrete paths)

1. **Reconcile the DB drift:** update `portfolio_candidates` for QM5_13213/USDJPY and QM5_13301/GDAXI off `EVIDENCE_STALE` to reflect their live-book status (they are in `C:/QM/mt5/T_Live/.../baselines/`). Owner of write: pipeline/portfolio tooling, not this auditor.
2. **Resolve the two blockers on the live Balke lineage:** (a) the machine-wide `NEWS_CALENDAR_TAINTED` pin `86b2c0b5…` blocks 13213/13036/13301/21501 at Q09_NEWS/Q10_NEWS — re-seat calendar bundle then re-run; (b) the `BALKE_PATTERN_REPAIR_REVIEW_PENDING` hold on 13213 Q12 (CEO-DEC-BALKE-PATTERN-RECOVERY-20260909) awaits the independent review of QM5_41398. Evidence: `work_item_holds`, `decisions/2026-09-09_balke_pattern_recovery.md`.
3. **Act on the window-sweep finding:** the swept optimum (`s0_l8` 00:00–08:00 UTC+3, OOS PF 1.21) beats the live 13213 window; route a Q13-style re-freeze/head-to-head of the re-windowed Balke vs the deployed baseline before any live re-window (ROT). Source: `docs/research/BALKE_WINDOW_SWEEP_RESULT_2026-09-11.md`, instruments `framework/EAs/QM5_41398_balke-pattern-repair-opt/`, `…/QM5_41405_balke-clock-audit-opt/`.
4. **Compute the §56 numeric overlap** for the USDJPY Balke variants (13213 vs 41097/41324/41398/41405) using `tools/strategy_farm/window_sweep.py` deal-list comparison over `D:/QM/reports/work_items/<id>/.../summary.json`, to confirm class C/D quantitatively.
5. **Close out Gold Reaper and the dead ORB cohort** as documented dead-ends (no rebuild): keep `QM5_31008` REJECTED; do not re-enqueue `QM5_9460`/`QM5_12425`. Do not count ORB reconstructions as diversification until one clears Q08 on its own merits.
6. **Retire the DXZ marginal:** flag QM5_13036 (GDAXI, PF 1.04) for the §59 materiality/anti-churn review — it is not currently live and its edge is near-breakeven.

---

*All EA-level facts cross-checked against `work_items`, `work_item_holds`, `ea_metrics`, `portfolio_candidates` (SQLite `?mode=ro`), the EA SPEC/card files under `framework/EAs/`, `strategy-seeds/`, `docs/research/`, and `C:/QM/mt5/T_Live/` baselines/journal. Numbers are quoted from those sources; where a formal artifact is absent (Q10 FTMO recommendation) the field is marked UNKNOWN.*
