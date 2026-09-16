# PATTERN_ABLATION Programme — single-filter ablation design (2026-09-16)

**Authority:** OWNER directive 3 §29 / interim §9 (PATTERN_FILTER programme), research+specification slice.
**Status:** DESIGN ONLY — not commissioned, nothing enqueued, no DB writes, no economic validation, no gate-contract edits (Q12 remains ROT).
**Machine-readable plan:** `tools/strategy_farm/config/pattern_ablation.v1.json` (schema `qm.pattern-ablation/v1`, pinned by `tools/strategy_farm/tests/test_pattern_ablation_config.py`).
**Commissioning seat:** Fable (OWNER seat) — no trial enters the farm before Fable signs a commission artifact under `decisions/`.

## 1. Why a fresh ablation programme

- The sealed DL-089 census closed **27/27 programs with `NO_FILTER_CHANGE`** (30 receipts including post-cutoff rows; `docs/research/UNGER_PATTERN_CENSUS_FINDING_2026-09-12.md`). The closing finding is explicit: *"New pattern research needs a new, predeclared causal thesis rather than another pass over these cells."* This programme is that pre-declared causal thesis.
- The 2026-09-09 repair writeup (`docs/ops/evidence/2026-09-09_pattern_filter_repair.md`) fixed predicate 33/34 (three-candle logic), retired the B2/B5 prescreen, and hardened the native harness acceptance chain — the measurement substrate is now trustworthy; the economic re-evaluation was deliberately left open.
- The historical census was a **descriptive 77×2 sweep with no mechanistic hypothesis per cell**. This programme inverts it: one mechanistic hypothesis per base, pre-registered before any measurement, so a positive read-out is evidence *for a mechanism*, not a winner picked from 18,326 cells.

## 2. Hard design rules (non-negotiable)

1. **Exactly ONE predicate per base, one base+predicate trial each.** No stacks, no pairs, no power-set. Combinations are explicitly out of scope (`combinations: []` in the config).
2. **Runs INSIDE the existing Q12 contract, not beside it.** The trial executes in the `OPT_CENSUS` phase under the sealed DL-089 rule (consistency ≥ 2/3 selection years with each ≥ +5% relative return_to_maxdd improvement vs the same-year baseline; ≥ 10 entry trade days per evaluated year fail-closed; anchored walk-forward, minimum 3-year window, test years 2022–2025). Q12 remains the sole authority that decides which filters an EA runs; this programme only supplies pre-registered candidates. Any adoption requires the full sealed census; a positive ablation read-out only *promotes to* that census.
3. **Blacklist semantics.** `QM_PatternProfileMode` v1 is BLACKLIST-only: a firing predicate **blocks its side** (`framework/include/QM/QM_PatternPermission.mqh:258`). Every hypothesis below is phrased as "blacklist entries whose signal bar exhibits pattern P because P marks adverse conditions for this base's entry logic". Whitelist overlays are a physically different experiment (OWNER E0-3) and are not tested here.
4. **Null control mandatory.** Every year measures the no-filter `baseline` arm; every overlay is compared against the same-(base, year) baseline.
5. **Multiple-testing control pre-registered.** Filter families (`pattern_filter.{price-action,trend,volatility,news,session,regime,time}`) are declared before measurement; Benjamini–Hochberg FDR is applied **within** each family at programme level. Trial counting: one hypothesis = (base, predicate) across both directions = 2 declared direction-trials; calendar years are repeated measurement, never trials (DL-089 §5).
6. **Deflation is never silent.** 22 declared direction-trials (11 hypotheses × 2 directions) are logged in `search_history_ledger` under the `pattern_filter.*` families **before** any enqueue and feed Q16 DSR/PBO deflation of any configuration that adopts a filter. Per-program census deflation stays `declared_trial_count = 154`.
7. **Cap discipline.** The historical cap of ≤ 3 filters per direction is a SELECTION parameter, not a Hard Rule (`docs/research/PATTERN_FILTER_CATALOG.md` §22 disposition). This programme tests exactly 1 — it can never bind.
8. **Census fields are descriptive, never verdicts.** Every `census` number cited below (improved cells / mean trade reduction) is the observational DL-089 census aggregate, used only to anchor expectations; it re-weights nothing.

## 3. Trial template (identical for every base)

| Element | Spec |
|---|---|
| Arms | `baseline` (NO_FILTER), `buy_{pid}`, `sell_{pid}` — one predicate id, both directions |
| Years | 2019–2025, one backtest per arm per year (single years = repeated measurement) |
| Walk-forward | Sealed DL-089 anchored/expanding windows: select 2019–21 → test 2022; … expand → test 2025 (min window 3 years; test years never in selection) |
| Success measure | return_to_maxdd relative improvement ≥ +5% vs same-(base, year) baseline (the sealed measure) |
| Selection rule | consistency ≥ 2/3 of selection years; WF subset stability per plan §2; activity floor ≥ 10 entry trade days/year pro-rata — a breach in ONE year makes the filter inadmissible **before** any return consideration |
| Measurements | trade count/reduction; per-trade expectancy delta; max DD delta; return_to_maxdd; regime-conditional effect (trend/range/high-vol); portfolio marginal effect (DXZ + FTMO book correlation & tail) |
| Kill criteria | **(a)** relative per-trade expectancy drop > 5% vs base in ≥ 2/3 of the 7 years (any single year > 10% = immediate kill); **(b)** trade reduction > 20% in any year without a ≥ +5% relative return_to_maxdd gain that same year; **(c)** activity-floor breach in any year → inadmissible; **(d)** WF subset-stability failure → inadmissible for adoption |
| Positive read-out | promotes the predicate to a **full DL-089 census program** for that base; the sealed selection rule decides adoption; Q16 deflation runs over the total declared trials |

**Execution inside today's lane (important):** `opt_census.enqueue()` pins `planned_trials == 1085` (155 arms × 7 years), so each trial currently executes as its own full census program — the ablation read-out is then restricted to the pre-registered single predicate per direction, and the other measured cells carry the sealed 154-trial deflation. A reduced 3-arm plan (21 cells/base) is possible in principle but needs a code-change decision by Fable (open question Q3 below); nothing here assumes it.

## 4. Selected bases and predicates (11 trials)

Canonical pool: 26 contiguous Q02→Q14 pairs (`docs/ops/evidence/2026-09-15_continuous_book_evolution/audit/candidate_universe.csv`, via `D:/QM/reports/state/book_evolution_{dxz,ftmo}.json` qualified pools) + the FTMO-gap direction (CAMP-2026-0001 / H-CW class). Selection order: dense intraday bases first (FTMO shape), then D1 value sleeves; one predicate each.

### ABL-001 — QM5_13213 `balke-gmt3-range-breakout` · USDJPY.DWX · H1
**Base identity.** Qualified pool row 18; live DXZ sleeve (0.0431% risk); the DL-089 pilot family (original census subject 13213/41097). Entry: H1 stop breakout of the completed 03:00–06:00 GMT+3 range, both sides, evening resolution 18:00, ATR range filter 0.4×–2.5× (`framework/EAs/QM5_13213_balke-gmt3-range-breakout/SPEC.md`).
**Predicate: 44 — Wide Range Bar** (`volatility/wide-range`, Unger-related; census 88/235 improved, mean trade reduction −6.2%).
**Mechanism.** Blacklist entries whose 06:00 GMT+3 order-placement bar (the completed final range bar) is a wide-range bar: an expanded final range bar means the breakout is already underway (chase location) or the range formed on news displacement; Balke's edge is quiet-range resolution, so WRB-triggered entries have degraded follow-through.
**Expected trade reduction: 2–12%.** Kill criteria: §3 (a)–(d).

### ABL-002 — QM5_13013 `grimes-trendday-v2` · NDX.DWX · M15
**Base identity.** Qualified pool row 16; live DXZ sleeve (0.379%); session-flat M15 index intraday (16:30–22:45, hard session close) — the closest *qualified* analogue of the H-CW FTMO profile. Entry: M15 close above the first-4-bar opening range AND prior D1 high after a compressed D1 setup (≤ 0.65× ATR20), 3R target, session-flat exit.
**Predicate: 84 — Trend Exhaustion** (`regime/exhaustion`; census 89/247 improved, −7.5%).
**Mechanism.** Blacklist M15 breakout entries when the deterministic exhaustion regime fires on the signal bar: a trend-day breakout attempted into an exhaustion-flagged tape is a failed-breakout candidate (the compressed D1 is a terminal coil, not a trend-day base).
**Expected trade reduction: 3–13%.**

### ABL-003 — QM5_10706 `tv-mon-ls` · GBPUSD.DWX · H1
**Base identity.** Qualified pool row 6; live DXZ sleeve (0.053%); DL-089 near-miss program (BUY-hour 52 failed 2/4-vs-3 stability — motivates a shape-based, not hour-based, second look). Entry: fade failed breaks of the prior Monday range — H1 close back inside the Monday box after a wick sweep beyond it (`SPEC.md`).
**Predicate: 18 — Spinning Top** (`price-action/single-bar-indecision`, Unger-related; census 74/238 improved, −9.4%).
**Mechanism.** Blacklist sweep-fade entries whose close-back-inside bar is a spinning top: an indecision-body close carries no rejection conviction; the WolfWeb fade is valid only when the rejection bar is decisive.
**Expected trade reduction: 4–15%.**

### ABL-004 — QM5_10700 `tv-liq-break` · XAUUSD.DWX · H1
**Base identity.** Qualified pool row 4; DXZ v2 new sleeve (0.089% burn-in); census program with `stable=false` (no reproducible filter found — the finding doc demands a fresh causal thesis). Entry: H1 close through the prior liquidity high/low after a confirmed pivot contraction (two lower highs + two higher lows).
**Predicate: 83 — Regime Transition** (`regime/transition`; census 49/249 improved, −9.7%).
**Mechanism.** Blacklist liquidity-break entries fired while the regime classifier flags a transition bar: contraction breaks triggered in trend birth/death chop are noise breakouts, not orderly continuation.
**Expected trade reduction: 4–15%.**

### ABL-005 — QM5_11660 `pp-wedge` · NDX.DWX · H4
**Base identity.** Qualified pool row 9 (PRE60 news temporal, CONFIG_LOCKED). Entry: H4 wedge-continuation (both envelope trends rising for long / falling for short) with structural invalidation exits.
**Predicate: 79 — Ranging** (`regime/trend-strength`; census 96/220 improved, descriptive trade-count +3.6% — an anomaly under blacklist semantics; the predicate fires rarely on H4, so the expected reduction is low).
**Mechanism.** Blacklist continuation entries when the trend-strength classifier says ranging: a wedge-continuation signal in a ranging tape is a coin flip; the edge requires a trending regime.
**Expected trade reduction: 0–8%.**

### ABL-006 — QM5_10513 `mql5-ichimoku` · XAUUSD.DWX · D1
**Base identity.** Qualified pool row 3; live DXZ sleeve (0.305%). Entry: D1 Tenkan/Kijun cross with cloud-side confirmation.
**Predicate: 79 — Ranging** (same census cell as ABL-005).
**Mechanism.** Replicates the ABL-005 mechanism on a different strategy class/symbol (regime-family replication): crosses in a ranging tape are whipsaw fuel; cloud confirmation does not rescue direction in chop.
**Expected trade reduction: 0–8%.**

### ABL-007 — QM5_11881 `connors-rsi2-mean-reversion` · GBPUSD.DWX · D1
**Base identity.** Qualified pool row 11; the farm's best-replicated MR class. Entry: D1 RSI(2) pullback fade with SMA(200) direction filter and mid-line exits.
**Predicate: 60 — Vol Expansion** (`volatility/vol-state`; census 80/234 improved, −5.2%).
**Mechanism.** Blacklist RSI(2) fade entries fired during volatility expansion: dips that keep expanding are knife acceleration, not exhaustion; the MR edge lives in quiet tapes.
**Expected trade reduction: 2–11%.**

### ABL-008 — QM5_41219 `cum-rsi2-commodity-requal8` · XAUUSD.DWX · D1
**Base identity.** Qualified pool row 25; requal8 port of the heaviest live commodity sleeve (12567 at 0.7465% DXZ risk). Entry: D1 long when close > SMA200 and RSI(2)[1]+RSI(2)[2] < 35; news blackout on entries. **Precondition:** its `q10_news_verdict` carries a REVIEW_REQUIRED flag in candidate_universe.csv — commission only after that flag is dispositioned.
**Predicate: 88 — Zscore High** (`regime/statistical-zscore`; census 50/253 improved, −10.9%).
**Mechanism.** Blacklist long entries when the D1 close sits at a high statistical z-score: a cum-RSI2 dip signal firing while price is still statistically extended is an early-knife long in an overbought market, not a discounted entry.
**Expected trade reduction: 5–17%.**

### ABL-009 — QM5_11422 `williams-18ma-outside-bar-entry-d1` · USDCAD.DWX · D1
**Base identity.** Qualified pool row 8; DL-089 repair priority 3 (490 unmeasured B2/B5 cells). Entry: D1 stop breakout of the two-bar extreme when both lows/highs sit on one side of SMA(18) and neither setup bar is an inside bar. The setup already excludes inside bars, so a pattern gate at the *trigger bar* is a non-redundant shape layer.
**Predicate: 3 — Doji** (`price-action/single-bar-indecision`, Unger-related; census 80/232 improved, −8.3%).
**Mechanism.** Blacklist stop-breakout entries on a doji trigger bar: a directionless decision bar at the close-through-trigger means the setup had no follow-through conviction; doji-triggered breaks are the classic failed-breakout population.
**Expected trade reduction: 3–14%.**

### ABL-010 — QM5_9641 `bandy-cci-extreme-fade-mr-index` · WS30.DWX · D1
**Base identity.** Qualified pool row 27; DXZ v2 new sleeve (0.373%, PRE60_POST60). Entry: D1 long-only CCI(20) extreme fade with SMA(200) filter.
**Predicate: 100 — Quarter End** (`time/calendar`; census 56/235 improved, −10.5%).
**Mechanism.** Blacklist CCI-extreme fades entered at quarter-end: quarter-end index rebalancing flows manufacture CCI extremes that persist (flow-driven distortion), breaking the statistical-fade premise exactly on the days the predicate flags.
**Expected trade reduction: 4–16%.**

### ABL-011 — QM5_41475 `cash-window-index-continuation-h1` (H-CW) · NDX.DWX · H1 — CONDITIONAL
**Base identity.** **FTMO-gap priority #1**: the session-flat H-CW class is the only deeply-validated FTMO-shaped pocket (CAMP-2026-0001; 9-of-10 index intraday Q10 passes; approved card `artifacts/cards_approved/QM5_41475_cash-window-index-continuation-h1.md`). **The base does not exist in the pipeline yet** (G0, build-only authorization 2026-09-15). NDX is the lead symbol; GDAXI/SP500 are expansion slots after the lead read-out.
**Predicate: 98 — Volume Climax** (`volatility/volume-climax`; census 33/255 improved, −11.2%).
**Mechanism.** Blacklist cash-window continuation entries whose H1 signal bar is a tick-count climax bar: climax-shaped signal bars mark event-driven displacement that mean-reverts within the session; complements the card's first-session-bar range shock filter with a per-signal-bar tape-shape gate (DWX tick-count proxy, not traded volume).
**Expected trade reduction: 5–17%.**
**Activation.** Per symbol: only after the H-CW base owns a done/PASS Q02 row and a hash-bound build. Pre-registering the hypothesis NOW keeps the causal thesis ahead of the data — exactly what the census-closing finding demands.

## 5. Explicit non-selections (full pool disposition)

Every one of the 26 qualified pairs + 3 frontier rows is either selected above or dispositioned here (also encoded in `explicit_non_selections` in the config, pinned by test):

| EA | Slug | Disposition |
|---|---|---|
| QM5_21501 | balke-…-ppcensus | Derivative of ABL-001, not independent (2026-09-09 repair); its open census/33-34 re-measurement is the separate Balke recovery lineage |
| QM5_11421 / QM5_41221 | ohlc-daily-squeeze-reversal(-requal8) | Mutual duplicates; squeeze family better covered by ABL-009 |
| QM5_11910 | larry-williams-18ma-2outside-bars-d1 | Same Williams-18MA family/mechanism as ABL-009 |
| QM5_10145 | tsm-meanret | D1 trend; hypotheses covered with stronger mechanisms (ABL-005/006/007) |
| QM5_10403 | et-turtle20x | D1 trend breakout represented by ABL-001/002 intraday breakouts |
| QM5_11708 | anon-market-squeeze-d1 | Short-only; the DL-089 near-miss here was an *hour*-filter phenomenon, not a pattern predicate |
| QM5_12710 / 12849 / 13054 / 20048 / 20266 | energy TSMOM/calendar sleeves | Calendar-driven entries: entry-bar shape predicates have no mechanism |
| QM5_12855 | brent-nov-fade | Calendar sleeve: a time predicate on a calendar strategy is tautological; the one time slot goes to ABL-010 |
| QM5_21505 | xag-weekly-lowvol-momentum | Internal volume-rank filter already; marginal pattern layer |
| QM5_21507 | qs-kama-trend-xau | Trend family already replicated (ABL-005/006) and exhaustion covered (ABL-002) |
| QM5_1537 | aa-vol-sma10 | Calendar-driven symbol rotation; vol family already at 3 trials |
| QM5_10911 / 11294 / 1354 | frontier rows | Below the Q02→Q14 chain — the ablation never runs on unqualified bases |

## 6. Sources

- Catalog & census descriptors: `docs/research/PATTERN_FILTER_CATALOG.md` (77 predicates; 30 sealed receipts all NO_FILTER_CHANGE; §22 ablation design this programme instantiates).
- Sealed Q12 contract: `decisions/DL-089_pattern_filter_wf_census_v3.md`, `docs/research/PATTERN_FILTER_WF_OPT_PLAN_V3_2026-08-21.md` (SHA-pinned), `tools/strategy_farm/config/gate_manifest.v4.json` (Q12 = DL089_PREREGISTERED_PATTERN_FILTER_SELECTION, cap 3/direction), vault `03 Pipeline/Q12 Pattern Filter Selection.md`, `docs/ops/PIPELINE_PHASE_SPEC.md`.
- Gate mechanics: `framework/include/QM/QM_PatternPermission.mqh` (BLACKLIST v1, closed bars, fail-closed), `tools/strategy_farm/opt_census.py` (plan/enqueue/advance/report; `planned_trials==1085`; harness + Q02 preconditions), `tools/strategy_farm/farmctl.py` (`enqueue-pattern-fixture-harness`).
- Defect history: `docs/ops/evidence/2026-09-09_pattern_filter_repair.md` (33/34 fix, B2/B5 retirement, harness acceptance), `docs/research/UNGER_PATTERN_CENSUS_FINDING_2026-09-12.md` (27/27 close), Unger corpus: `docs/research/LIBRARY_MINING_unger-forex-strategies_2026-06.md`, `docs/research/CODEX_UNGER_REFERENCE_PORTABILITY_2026-08-12.md`.
- Pool & value: `candidate_universe.csv` (26 qualified + 3 frontier), `D:/QM/reports/state/book_evolution_{dxz,ftmo}.json`, `docs/ops/evidence/2026-09-15_continuous_book_evolution/audit/{dxz_live_book,ftmo_fitness_candidates}.md`, CAMP-2026-0001 receipt + H-CW card.
- Base entry logic: `framework/EAs/<EA>/SPEC.md` per selected base.

## 7. Open questions for Fable

1. **41219 flag.** Its `q10_news_verdict = REVIEW_REQUIRED_latest_earlier_CONFIG_LOCKED_counts` in candidate_universe.csv — disposition before commissioning ABL-008, or drop the slot?
2. **H-CW timing.** ABL-011 is pre-registered conditional. Confirm the lead symbol (NDX) and that the trial stays dormant until the base's own Q02 PASS — no piggy-backing on the card's G0 approval.
3. **Reduced-arm plan.** Do you want a code change (relax `planned_trials==1085` or add an ablation plan builder) so each base costs 21 cells instead of 1,085? My recommendation: run the first commissioned base as a full census (zero code change, sealed contract end-to-end) and decide on the reduced builder only after the read-out proves the programme worth scaling.
4. **Balke recovery lineage.** ABL-001's base (13213) has a frozen historical census identity (41097). The repair writeup requires a *separate, hash-bound recovery lineage* for any re-measurement. Confirm the new census program runs on the current 13213 identity with a fresh `DL089_QM5_13213_…` program id (not a re-bind of 41097 rows).
5. **Family FDR level.** BH within family at programme level over 11 hypotheses (volatility 3, regime 5, price-action 2, time 1). Accept, or do you want family-level counting to include per-direction multiplicity (22)? The config currently declares 22 direction-trials for Q16 deflation but treats the (base, predicate) pair as ONE hypothesis for FDR — flag if you want stricter.
