# Survivor Optimization Program — 2026-08-12

Status: **DRAFT for OWNER review**. Author: Claude (multi-agent analysis, 12 agents:
5 fact-finders, 4 adversarial lever critiques, 1 idea generator, 1 synthesis, 1 funnel
re-verification). Trigger: OWNER 2026-08-12 — "Warum verhungern so viele Q06→Q10, wie
optimieren wir die 34 weiter (Unger-Tagesfilter, SL/TP, MTF, FVG-Kombos, weitere
Symbole)?"

Evidence substrate: read-only backup DB
`D:/QM/strategy_farm/state/backups/farm_state_before_xti_cohort_block_20260812T164553Z.sqlite`
(live DB never held >1s). Every numeric claim below carries its SQL or file path.

---

## 1. Funnel diagnosis — why the pipeline "starves" Q06→Q10 (it doesn't — it kills)

OWNER's dashboard numbers **reproduce exactly** as distinct `(ea_id,symbol)` sleeves
holding a PASS-family verdict per gate:

| Gate | Reached | Passed | Genuine-fail | Infra/other-only |
|---|---:|---:|---:|---:|
| Q05 Stress MEDIUM | 599 | 283 | 278 | 38 |
| Q06 Stress HARSH | 289 | **255** | 25 | 9 |
| Q07 Multi-Seed | 255 | **179** | 35 | 41 |
| Q08 Davey | 192 | **19** (strict PASS) | 164 | 9 |
| Q09_PORTFOLIO | 101 | **34** (PASS_PORTFOLIO) | 61 | 6 |
| Q10 Full-History | 35 | **34** | 1 | 0 |

(Q09_NEWS has no PASS verdict — its advance token is REVIEW_REQUIRED, distinct
cleared = 18. All counts: backup DB, SQL in §8.)

**Finding 1 — "Q08 = 19" is correct but misleading, not a bug.** Q08 emits
`PASS / FAIL_SOFT / FAIL_HARD / INFRA_FAIL`. A `FAIL_SOFT` (hard sub-gates clean,
soft/low-sample sub-gates missed) is **deliberately routed onward to the Q09 portfolio
track** (`framework/scripts/q08_davey/aggregate.py:113`; corroborated by
`tools/strategy_farm/analyze_q04_survivor_cohort.py:376`,
`keep_verdicts = PASSISH | {"FAIL_SOFT"}`). The dashboard's "19" counts only strict
all-10-sub-gates-clean PASS. The **admitted** post-Q08 cohort is
`Q08 ∈ {PASS, FAIL_SOFT}` = **92** distinct sleeves. The monotone funnel is:

```
Q06 255  →  Q07 179 (70.2%)  →  Q08 admitted 92 (51.4%)  →  Q10 survivors 34
```

Of the 34 Q10 survivors, only 16 hold a strict Q08 PASS; 30/34 are covered by
PASS∪FAIL_SOFT; 2 basket-logical sleeves (12778/AUDUSD, 13117/EURGBP) have no Q08 row
of their own. The Q07→Q08 conversion is **51%, not 10%** — the "10%" is an artifact of
counting only strict PASS.

**Finding 2 — there is no queue starvation at Q06–Q08.** Row status at Q08: done 532,
failed 44, active 1, **pending 0** — the gate is drained. Live backlog across Q06–Q10
is ≤3 sleeves anywhere. The collapse is **genuine merit kill**, exactly as the gates
are designed to do (funnel audit 2026-06-09: deaths are legitimate).

**Finding 3 — what actually kills.**
- **Q07 Multi-Seed** (vault: 5 fixed seeds 42/17/99/7/2026; PASS requires cross-seed
  PF variance < 20% of mean AND **no single seed PF < 1.0**): the merit kill is the
  min-PF-floor rule — ~20 sleeves died to one seed under 1.0 (seeds [7]: 6, [2026]: 5,
  [17]: 5, [99]: 4) + 6 to the 20-trade seed floor. This kills seed/tick-ordering
  fragility — an edge that only exists under one tick sequence is not an edge.
- **Q08 Davey** (vault: 10 sub-gates — correlation, DSR+MC+FDR, tail dependence,
  seasonal, neighborhood, chopping block, PBO, edge decay, runs test, regime — binary
  AND): terminal kill = `FAIL_HARD`, 135 rows / 163 sleeves terminally dead at Q08.
- **Q09_PORTFOLIO**: 61 sleeves dead at `FAIL_PORTFOLIO` — standalone-clean but
  redundant against the book (DL-083 correlation gates doing their job).

**Finding 4 — the recyclable residue (free throughput, no optimization needed).**
"Infra-stuck" sleeves ran, hit an infra error (ACTIVE_TIMEOUT, launch_fault,
invalid report), never got a merit verdict, and are **not queued**: Q07 **41** sleeves
(ACTIVE_TIMEOUT 34, launch_fault 8, seeds_invalid_evidence 6 at row level), Q06 9,
Q08 9 (`phase_runner_invalid_report` 174 rows + `q08_zero_trade_baseline` 22 rows),
Q09_NEWS 15. **The only genuine waiting frontier is Q09_NEWS** (3 pending +
18 PENDING_RUNNER rows + 24 INFRA_FAIL rows) — consistent with the live-book news
backfill program already running (ticket 3260d15d).

**Answer to OWNER's question in one line:** between Q06 and Q10 nothing starves in a
queue — 76 die at Q07 mostly to single-seed fragility, ~100 admitted-but-soft die at
Q08-hard/Q09-portfolio to statistical validation and book redundancy, and ~60 sleeves
across Q06–Q09 are recyclable infra residue we can harvest without touching a single
strategy parameter.

---

## 2. The survivor census — what the 34 actually are

Cohort: 34 distinct `(ea_id,symbol)` whose furthest phase is Q10 verdict PASS.
22 of the 24 live FINAL-24 sleeves are inside the 34; **2 live anomalies are not
Q10-clean** (QM5_10440/NDX: Q10 FAIL; QM5_12567/XNGUSD: Q08 FAIL_HARD, furthest Q09)
— both already flagged fail-closed in
`docs/research/INVVOL_WEIGHTING_PROPOSAL_2026-08-04.md`. 12 of the 34 are
Q10-pass-but-not-live; 11422/USDCAD + 13036/GDAXI are held pending news A/B.

Clusters (directory slugs + SPEC.md reads; full table in the census evidence):

- **Symbol concentration: XAUUSD = 9/34 (26%)**, EURUSD 4, GDAXI 4, NDX 3; a single
  XAU shock hits a quarter of the book.
- **Grimes pullback bloc = 6 sleeves** (10911, 10919, 10938, 10939, 12989, 13013) —
  same H1 pullback mechanic across 5 symbols, co-drawdown risk.
- **Near-duplicate pairs:** 10142+11132 (both SP500 D1 Connors-RSI2) and 13036+13301
  (both GDAXI Balke breakout).
- **XAU breakout trio** (10123 Donchian / 10403 Turtle / 10128 Bollinger) + **XAU
  trend quartet** (10145 TSM / 10183 Carver / 10513 Ichimoku / 1556 mom12): all
  long-gold-biased; effective independent XAU bets are far fewer than 9 (10123/10145
  already failed portfolio admission at corr ~0.91,
  `docs/research/GOLD_REAPER_BREAKOUT_MINING_2026-07-23.md`).
- **Orthogonal corner worth protecting:** event/calendar (12969 Gotobi, 13128
  pre-FOMC, 20048 WTI pre-holiday, 10706 Monday-LS), cointegration pairs
  (12778, 13117), H4 reversals (1328 Brooks, 1567 DeMark).

**Census verdict: the book's upside is in trimming XAU-trend/Grimes redundancy and
up-weighting the event/RV corner — not in adding more directional trend on the same
3–4 symbols.** This ranking governs every workstream below.

In-flight population: **19 sleeves at Q09** (15 PASS_PORTFOLIO + 4 NEED_MORE_DATA,
furthest-phase measure, incl. the RV basket legs of 12778/13117) plus the 12
Q10-pass-not-live — already built, already gate-clean.

---

## 3. Workstreams (ordered by expected value per unit effort)

Only levers that survived adversarial critique appear. Universal rules live in the
Anti-Overfit Charter (§6). Lane constraint: Codex quota-dead until Mon 18.08 00:03Z;
Claude headless-Sonnet build lane available now; agy for research; backtests never
throttled.

### WS-1 — Harvest before optimizing: recycle + admit what is already clean
- **Priority HIGH, overfit ~0 (no fitting anywhere).**
- **Scope:** (a) the **~60 infra-stuck sleeves** (Q07: 41 — ACTIVE_TIMEOUT/launch_fault
  class, staged-recovery requeue per operating rules; Q06: 9; Q08: 9; Q09_NEWS: 15);
  (b) the 4 Q09 NEED_MORE_DATA verdicts; (c) drain the Q09_NEWS frontier (the one real
  backlog — coordinate with the running news-backfill program, ticket 3260d15d, never
  displace its chain); (d) stage the 19 Q09-in-flight + 12 Q10-pass-not-live for OWNER
  portfolio admission (honor the 11422/13036 news-A/B holds).
- **Validation:** pipeline verdicts only. Admission via the OWNER marginal-contribution
  eval: regime-split return-corr admit <0.15 / reject ≥0.40 (DL-083), ΔSharpe (eps
  0.020, never sole driver), ΔMaxDD/Δworst-day, min-contribution 0.06%/yr at capped
  inverse-vol (DL-082).
- **Effort S–M; lane: factory + Claude + OWNER admission. No Codex dependency —
  runnable now.**

### WS-2 — Correlation-aware cluster caps + retire near-duplicates
- **Priority HIGH, overfit ~0 (selection/allocation only).**
- **Scope:** portfolio overlay on top of inverse-vol (INVVOL is correlation-blind by
  design — a cluster cap complements it). Cap aggregate long-XAU-beta / Grimes-bloc /
  GDAXI weight; retire or hold one leg of 10142+11132 and 13036+13301; thin the XAU
  breakout trio + trend quartet to representatives.
- **Validation:** regime-split return-corr matrix over the 34 (backup DB `ea_metrics` +
  `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/*.csv`); apply only via
  incumbent head-to-head ("apply only if not worse", INVVOL addendum); any live change
  fail-closed behind OWNER-signed manifest.
- **Effort M; lane: Claude + OWNER. Runnable now; ideally after WS-1 admissions so the
  cap is computed on the final roster.**

### WS-3 — Exit surgery, second wave (the legitimate residue of "SL/TP optimieren")
- **Priority HIGH, overfit MEDIUM. Precedent: Tier A exit surgery produced 6 validated
  v2s (`docs/research/EXIT_SURGERY_SCAN_2026-07-04.md`).**
- **Scope:** exit-only, two pre-declared sub-levers: (a) extend/loosen mechanical
  time/ceiling exits where a bar-count or R-cap truncates winners (Grimes H1 bloc:
  30-bar / EMA20-cross / 1.5R exits); (b) MAE-calibrated breakeven-lock/trailing on
  high-DD sleeves (13213 DD22.8%, 10706 19.9%, 10692 14.9%, 10911 14.8%, 13301 14.5%,
  11422 13.3%).
- **Hard caveat:** SL-tightening (Tier B) is **CLOSED** — winner MAE median 0.0–0.29×
  stop (`docs/research/EXIT_SURGERY_TIER_B_MAE_VERDICT_2026-07-06.md`); under
  RISK_FIXED a tighter stop enlarges size → more fragile at Q06. Any breakeven must sit
  above the winner-MAE **tail** (p75/p90), never the median — MAE capture per sleeve is
  mandatory before proposing.
- **Validation:** new ea_id v2, full Q02→Q10 cascade, RISK_FIXED $1000; must beat the
  incumbent on robust gates (Q04 WF-net, Q06 HARSH, Q08 Davey), never on in-sample Q02;
  frequency floor re-checked first; one exit param per sleeve, ledgered.
- **Effort S–M per sleeve, M–L across shortlist; lane: Claude headless-Sonnet builds
  now, one EA at a time.**

### WS-4 — Vol-regime entry gate on high-frequency/high-DD sleeves (the surviving slice of the Unger day-filter idea)
- **Priority MEDIUM, overfit MEDIUM-HIGH. Verdict of the adversarial critique:
  PURSUE_CONDITIONAL — the broad/DOW form is REJECTED (§4).**
- **Eligibility pre-filter (binding, arithmetic):** full-history trades **≥150** (3×
  the ~45 absolute floor, so a cut cannot breach it) AND DD **≥~12%**. Qualifiers:
  13213 (1624tr/22.8%), 10692 (686tr/14.9%), 13301 (742tr/14.5%), 10911 (331tr/14.8%),
  10706 (284tr/19.9%); the XAU-vol-gate variant additionally 10128/10145/10183. The
  near-floor half of the book (10919=30tr, 12989=51, 1556=53, 13128=57, 1328=58, …) is
  excluded on arithmetic alone — a permission filter's primary effect is cutting
  trades, and thin/zero trades is the pipeline's #1 death class (MIN_TRADES_NOT_MET
  = 3432, `decisions/2026-07-25_q02_pf_floor_120_to_110.md`).
- **Design:** exactly **one** pre-registered, thesis-backed predicate with ≤1 tunable
  threshold per sleeve — e.g. prior-closed-D1 ATR-ratio regime gate or NR4/NR7 squeeze
  precondition (both 0–1 params, from the portable Unger vocabulary, §5). Evaluated on
  **bar[1] (last closed D1)** — the reference's bar[0] forming-candle read repaints and
  is inadmissible. Judged on **ΔMaxDD/Δworst-day, not PF**. Maps onto the open house
  thesis "the vol-gate IS the edge" (GOLD_REAPER_BREAKOUT_MINING_2026-07-23.md).
- **Validation:** Lane-1 pre-declared ablation (same ea_id, base params LOCKED,
  filter-OFF vs ON, precedent QM5_10513 ablation_00..04), re-graded from Q02 —
  entry-filter changes invalidate all prior PASS evidence
  (`framework/V5_FRAMEWORK_DESIGN.md:31`). Threshold picked on IS/DEV then FROZEN;
  filtered must beat unfiltered on ≥2/3 anchored OOS folds and on Q04/Q06/Q08, never
  Q02. Calendar/session anchors are STRUCTURAL non-perturbable at Q08.5
  (`decisions/2026-07-15_q08_neighborhood_calendar_params.md`); the one tunable
  threshold must land on a plateau. Full trial ledger to Q07 DSR/PBO. Promotion as v2
  requires beating the live incumbent at BOOK level OOS (corr ≤0.40, DL-083).
- **Effort:** S per EA to wire (§5 Option A), M–L total; lane Claude-Sonnet builds now.
- **Ranks below WS-3 and the INVVOL head-to-head** — all three target the same DD
  goal, WS-4 is the priciest and most overfit-prone.

### WS-5 — Monte-Carlo tail-risk resizing at the live/portfolio layer only
- **Priority MEDIUM, overfit MEDIUM.** Bootstrap each sleeve's realized returns to set
  live risk budgets / tune the INVVOL clamp toward a tail target (worst-day/DD
  percentile). Extends ratified practice (FTMO bootstrap LB; INVVOL walk-forward).
  **Hard boundary:** backtests stay RISK_FIXED $1000 (Hard Rule 4) — this lever lives
  only at the live 0.5% layer + Q13. Apply only via incumbent head-to-head.
  Effort M; Claude + OWNER manifest; runnable now.

### WS-6 — Thesis-gated cross-asset survivor ports (BLOCKED until Codex returns 18.08)
- **Priority conditional; universe-shotgun REJECTED.** Port a proven mechanic to
  **1–2 thesis-backed, uncorrelated carriers** (locked params, new ea_id, full
  Q02→Q10). Same-asset-class ports mostly add correlation, not orthogonality
  (10123/10145 corr ~0.91 portfolio-fail); symbol-conditionality is real (Balke:
  USDJPY OOS PF 1.20 vs XAU 1.03 RETIRE,
  `docs/research/BALKE_RANGEBREAKOUT_WALKFORWARD_2026-07-14.md`-family evidence).
- **Blocker:** host-gates are hardcoded pervasively (969 host-symbol comparisons across
  571 EA sources; the XTI reroute failed exactly here — 23 EAs, ticket **9ad6d9c0**,
  19 rows BLOCKED_STALE_BUILD_RESULT). Genericization is Codex-class work → builds
  deferred to 18.08; thesis pre-registration (Claude/agy) proceeds now. Carrier
  tradability + custom-history against `dwx_symbol_matrix.csv`; per-symbol venue cost
  (≥2× Q08 cushion); survivor-port purity: a failing port dies, it is not re-fitted.

*Folded under WS-4's discipline, not standalone: spread/cost-aware skip on
marginal-cushion sleeves (10128 PF1.05, 13036 1.04); trend-regime coherence gate on
the Connors-RSI2 sleeves (economically grounded but acute floor risk, all <75tr).*

---

## 4. Rejected / deferred levers (with the evidence that killed them)

- **Time-Range-Breakout + FVG (and confluence combos on closed patterns) — REJECT.**
  FVG confluence was already tested **as a filter** and falsified in-house: QM5_13204
  confluence OFF = 190tr/PF 0.99 → ON = 78tr/PF 0.59; fading it only 0.93
  (`docs/research/VIDEO_zw_J5RP31cA_ANALYSIS_2026-07-12.md` — "the mechanized rules
  identify high-noise zones, not predictable reversal points"). Corroborated by the
  icy-tea HTF-bias degradation and the SMC/ICT/Wyckoff closures. Adding a dead pattern
  as a filter on a live edge = noise-fit DOF. The legitimate "breakout + vol-regime"
  variant is WS-4, not an FVG bolt.
- **Day-of-week masks (the literal "nur an bestimmten Tagen") — REJECT.** 5 binary DOF
  = 32 combos brute-forced on one symbol/TF; no economic thesis; day/session anchors
  earn zero neighborhood credit at Q08.5 (structural non-perturbable); a day-filtered
  v2 is its own incumbent's return stream minus days → self-correlated, Q09-rejected
  at ≥0.40; and it thins the near-floor half of the book into auto-RETIRE. Only the
  thesis-backed vol-regime/squeeze slice survives as WS-4.
- **SL-tightening — CLOSED** (Tier B MAE verdict, see WS-3 caveat).
- **TP re-optimization — DEPRIORITIZE.** Pure re-opt of a Q03-swept param without a
  structural hypothesis; Q07 PBO/DSR + Q08 neighborhood exist to punish exactly this.
- **MTF entry refinement — DEPRIORITIZE.** Entry-logic change = new EA, full cascade;
  3+ new DOF; "waiting for a better fill" thins trades toward the floor; no house
  evidence of an MTF-timing edge; contradicts orthogonality>addition.
- **Session-window tightening on 13213/13301 — REJECT** (tuning a structural anchor =
  curve-fitting; 13213's edge IS its GMT-normalized window).
- **Seasonality month/quarter masks — LOW/trap** (only the 0-param date-math gates
  escape the critique; genuine seasonal edge already lives in the protected event
  corner).
- **HiddenMarkovFilter from the reference — NOT PORTABLE (doctrine breach).** A real
  6-state HMM (Forward + Viterbi + Gaussian emissions) — a probabilistic latent-state
  inference model, forbidden by "no ML in V5" even though pure MQL5; also repaint-class
  and inert (never wired) in the source itself.
- **Directional de-biasing (short leg on long-XAU breakouts) — LOW/defer** (negative
  house prior: Balke XAU short RETIRE; Gold-Reaper Q05-DD death).

---

## 5. Framework work package — the filter layer

**What the Unger reference actually is** (full analysis in the workflow evidence): a
once-per-day, direction-aware permission gate (`CFilterManager.CheckAll()` →
allowBuy/allowSell, WHITELIST/BLACKLIST over ~100 deterministic D1 patterns from
`Patterns.mqh`), cached per day, wrapped around a time-range-breakout. Portable
concepts: the closed-bar daily permission-gate idiom; NR4/NR7/inside/outside/WR
squeeze patterns; prior-day direction/close predicates; ATR-ratio vol-regime gates;
0-param calendar gates (opex third-Friday, quarter-end). **Not portable:** bar[0]
forming-candle evaluation (repaints — must become bar[1]), the 10-slot×100-pattern
sweep methodology (an overfitting engine), the HMM, and the ~11-param SMC context
filter.

**Chosen design: Option A — per-EA `strategy_*` inputs wired into the existing
`Strategy_NoTradeFilter` hook** (the canonical per-tick permission hook every
skeleton-derived EA already has), reusing the dormant no-ML `QM_FilterVolatility.mqh` /
`QM_FilterRegime.mqh` includes per-EA, kept OUT of `QM_Common`:
- Lowest blast radius: no shared-include fleet recompile, no `gen_setfile.ps1` /
  build_check schema change, no factory OFF/ON window; `strategy_*` inputs flow to
  `.set` automatically. Proven pattern: QM5_10513 already stacks session+spread gates
  in `Strategy_NoTradeFilter`.
- Option B (shared `QM_FilterCalendar.mqh`) is the migration target IF ≥2 sleeves
  adopt the same predicate — defer until then. Option C (framework-group injection in
  `QM_Common` OnTick) REJECTED: fleet recompile + OFF/ON + it re-opens the abandoned
  ~2026-05-28 Filters group decision.

**Per-EA steps:** (1) re-derive the sanctioned filter list (vault `Filter Library.md`
is stale pre-Qxx-rewrite) — research lane; (2) bar[0]→bar[1] rework of any ported
predicate; (3) ~10-line predicate in `Strategy_NoTradeFilter`, default-OFF (layer
inert, prior behavior preserved); (4) `strategy_*` rows in the card so gen_setfile
serializes them; (5) serial build discipline (dirs → magic CSV → resolver regen →
verify → compile SERIAL, one EA at a time, clean tree); (6) build_check + run_smoke +
**mandatory review_ea unwired-input grep** (build_check does not catch a dead
permission param — QM5_1355 class); (7) gate re-entry via Lane-1 ablation or Lane-2
v2 — entry-filter changes invalidate prior PASS evidence either way.

---

## 6. Anti-overfit charter (binding on every workstream)

1. **Thresholds fixed on IS/DEV, then FROZEN before OOS.** Knife-edge in-sample optima
   disqualify.
2. **v2 beats v1 on OOS robust gates or dies** — Q04 WF-net / Q06 HARSH / Q08 Davey
   (real venue cost, ≥2× cushion, DL-072/073), never on in-sample Q02.
3. **Neighborhood stability:** tunables must land on a Q08.5 plateau;
   calendar/session/day anchors are structural non-perturbable — never "optimized"
   (`decisions/2026-07-15_q08_neighborhood_calendar_params.md`). INVALID ≠ PASS.
4. **Frequency floor checked FIRST:** full-history trades > max(5×window_years, ~45)
   AND ≥5/yr before any PF/DD comparison; a PF gain never rescues a sub-floor variant.
   Thinning filters carry the ≥150-trade + ≥12%-DD eligibility pre-filter.
5. **Trial ledger to Q07 DSR/PBO:** every predicate/threshold/carrier considered is
   declared; DOF cap 1 filter × ≤1 threshold per sleeve.
6. **Survivor-port purity:** ports lock params; a failing port dies as a port.
7. **Portfolio judgment, not standalone PF:** admission = marginal contribution at
   book level OOS (DL-082/DL-083 thresholds).
8. **Builder ≠ approver; one EA at a time; never auto-swap a live sleeve** —
   challenger eval only at Q09; live changes only via OWNER-signed manifest; backtest
   sizing stays RISK_FIXED $1000.

---

## 7. Sequencing & milestones — first two weeks

**Week 1 (now → 15.08):**
- WS-1: staged-recovery requeue of the infra-stuck residue (Q07's 41 first); run the 4
  NEED_MORE_DATA; stage 19 Q09-in-flight + 12 Q10-not-live for OWNER admission.
- WS-2: regime-split correlation matrix over the 34; cluster-cap + near-duplicate
  retirement proposal to OWNER.
- Prereqs in parallel: sanctioned filter list re-derivation (agy/Claude); WS-4 thesis
  pre-registration + trial ledger; WS-3 MAE capture on the 6 high-DD sleeves.
- **M1:** NEED_MORE_DATA resolved; corr matrix + retirement proposal on OWNER's desk;
  MAE evidence captured; filter thesis pre-registered.

**Week 2 (15.08 → 22.08):**
- WS-3: first 1–2 exit-surgery v2s built (Claude-Sonnet), enter Q02.
- WS-4: first vol-regime Lane-1 ablation on ONE eligible sleeve (13213 or 10692),
  bar[1], default-OFF baseline, review_ea grep, enter Q02.
- WS-5: MC tail-sizing prototype vs the capped-inverse-vol baseline (head-to-head only).
- WS-6: 1–2 transfer theses pre-registered; host-gate genericization handed to Codex
  on return (18.08), riding on the 9ad6d9c0 XTI rework.
- **M2:** ≥1 exit-surgery v2 + ≥1 vol-regime ablation in the funnel at Q02+; WS-2
  decision returned by OWNER; WS-6 unblocked.

**Governing rule:** WS-1/WS-2 (zero-overfit, cheapest, they hit the concentration the
census names as the true upside) precede all per-sleeve optimization. Expected
survivors reaching live from WS-3/4/6: low single digits; the bulk of near-term book
value is WS-1 harvest + WS-2 de-concentration.

---

## 8. Evidence appendix

- Funnel forensics (SQL + per-gate verdict distributions): agent report, key queries
  reproduced in §1; backup DB path in header. Baseline: `SELECT COUNT(DISTINCT
  ea_id||'|'||symbol) FROM work_items WHERE phase='Q10' AND verdict LIKE 'PASS%'` → 34;
  `… phase='Q08' AND verdict='PASS'` → 19; `… verdict IN ('PASS','FAIL_SOFT')` → 92;
  Q08 status: done 532 / failed 44 / active 1 / pending 0.
- Q08 FAIL_SOFT admission: `framework/scripts/q08_davey/aggregate.py:113`;
  `tools/strategy_farm/analyze_q04_survivor_cohort.py:376`.
- Dashboard count semantics: `tools/strategy_farm/dashboards/render_dashboards.py`
  (~938–959 row-level phase_matrix vs ~3737 furthest-gate trajectory model).
- Gate specs: vault `03 Pipeline/Q07 Multi-Seed.md`, `Q08 Davey Statistical
  Validation.md`.
- Census & clusters: backup DB `ea_metrics` (phase='Q10', is_ablation=0) + EA
  directory slugs + SPEC.md reads; live roster from
  `D:/QM/reports/portfolio/invvol_stage1_20260804/daily/*.csv`.
- Unger reference: `C:/Users/Administrator/Downloads/QuantRangePRO - vers2/Hyonix/
  Breakout7/QuantRangePRO - vers2/` (PatternFilter.mqh, Patterns.mqh,
  TimeRangeBreakoutStrategy.mqh, HiddenMarkovFilter.mqh, IFilter.mqh line-level
  citations in the workflow evidence).
- Lever critiques / prior evidence: `docs/research/EXIT_SURGERY_SCAN_2026-07-04.md`,
  `EXIT_SURGERY_TIER_B_MAE_VERDICT_2026-07-06.md`,
  `VIDEO_zw_J5RP31cA_ANALYSIS_2026-07-12.md`,
  `GOLD_REAPER_BREAKOUT_MINING_2026-07-23.md`,
  `INVVOL_WEIGHTING_PROPOSAL_2026-08-04.md`,
  `decisions/2026-07-15_q08_neighborhood_calendar_params.md`,
  `decisions/2026-07-25_q02_pf_floor_120_to_110.md`, DL-071/072/073, DL-082/083.
- Workflow run: 11 agents (wf_29630f92-2d4) + 1 funnel re-verification agent;
  per-agent results in the session workflow journal.
