---
source_id: QM-RESEARCH-2026-0012
title: NY pre-open session-range breakout on USDJPY (H-V4, 13213 mechanics, 15:30-server anchor, M30 range grid) — revision 2
source_type: internal_research
source_author: Claude
source_model: claude-fable-5-1
created: 2026-09-21
originating_task_id: fable-velocity-hv4-20260921
status: draft
parent_source_ids: []
source_artifact: QM-RESEARCH://2026-0012
---

# NY pre-open session-range breakout on USDJPY (H-V4, 13213 mechanics, 15:30-server anchor, M30 range grid) — revision 2

## Research provenance

Authored by Fable (Claude, claude-fable-5-1) on 2026-09-21 from the **pre-registered family-F1 sweep**
(`docs/research/velocity/VELOCITY_FAMILY_F1_SESSION_RANGE_SWEEP_2026-09-21.md`; registration committed
before the run at `60de323f25`, results at `270c9a4c98`) under the Velocity-book programme
(`docs/ops/evidence/2026-09-20_velocity_book/README.md`, OWNER 2026-09-20). **Revision 2 (2026-09-21, Fable)**
answers the cross-vendor critique `d7ed93cd` (Codex, `docs/ops/evidence/2026-09-20_velocity_book/hv4_critique_d7ed93cd.md`,
commit `83a61cccb3`): a bounded source revision — no parameter change, no new sweep, no new cell; the frozen
spec is made single-valued for a builder and the replacement claim is downgraded to a pre-registered
hypothesis (see the revision table at the end).

No ML/statistical search instrument was used; the sweep is a deterministic closed-bar simulation of ONE frozen
mechanism (the qualified incumbent QM5_13213) over a fixed grid of 36 symbols × 3 session anchors × range
lengths N ∈ {2, 3, 4} hours on the factory's own `.DWX` M1 custom history (0 factory hours), read through
`tools/strategy_farm/session_tools/hcc_m1_reader_0921.py` and simulated by
`tools/strategy_farm/session_tools/velocity_family_f1_sweep_0921.py`. Every figure below is copied from
`sweep_extract.json` (sealed next to this file; produced by
`tools/strategy_farm/session_tools/velocity_hv4_sweep_extract_20260921.py`, which copies the cited cells
verbatim from the sweep output and records that file's sha256) or — for the critic's sensitivity runs — from
`critique_d7ed93cd_extract.json` (verbatim copy of the critic's tables, with the critique file's sha256).

**Calibration (revised wording).** The harness was reconciled on ONE control cell against a real tester
report: USDJPY × Tokyo window (13213's own configuration) versus the Q02 of the byte-identical lineage
QM5_41484 (work item `652e0768`): 904 vs 888 trades (+1.8 %), E[R] +0.070 vs +0.053 (+0.018R), median hold
421 vs 419 min, 881 of 886 common trade days in the same direction; the per-trade difference on common days
is only +0.007R, the rest comes from 18 simulation-only days (+9.376R). This validates sign and mechanics for
the A3 cell. **The "≈ +0.02R optimism" is an A3-only planning heuristic, not a universal correction:** the
C2/C3 and EURUSD cells trade another session, interact far more often with the news blackout and have
different intraminute paths; the arm-specific harness-to-tester gap is established only by the Q02 tester.

`research_trial_count = 314` is the honest multiplicity denominator: every grid cell evaluated in the sweep
(see "Universe reconciliation").

## Prescreen outcome (read this first)

Selection SEL = 2018-07-02..2022-12-30 (1,175 business days), validation VAL = 2023-01-02..2025-12-31
(783 bd). R at RISK_FIXED 1000, after registry commission, `.DWX` spread 0. Arms are the range length N;
anchor C = range ending 08:30 America/New_York = **15:30 server** (see the clock note in the spec).

| symbol | cell | SEL n | /bd | E[R] | PF | worst-yr DD | R/bd | VAL n | /bd | E[R] | PF | DD | R/bd | rule |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| USDJPY | **C2** (primary) | 998 | 0.85 | **+0.141** | **1.302** | 20.83R | **+0.120** | 632 | 0.81 | **+0.144** | **1.295** | **25.04R** | **+0.116** | survivor |
| USDJPY | **C3** (second arm) | 926 | 0.79 | +0.123 | 1.288 | 20.65R | +0.097 | 596 | 0.76 | +0.141 | 1.319 | 22.20R | +0.107 | survivor |
| USDJPY | C4 | 818 | 0.70 | +0.085 | 1.213 | 23.2R | +0.059 | 538 | 0.69 | +0.090 | 1.215 | 19.9R | +0.062 | survivor |
| USDJPY | A3 (= 13213 incumbent window) | 904 | 0.77 | +0.070 | 1.167 | 19.94R | +0.054 | 577 | 0.74 | +0.104 | 1.242 | 19.3R | +0.077 | survivor (control) |
| USDJPY | A2 / A4 | 1072 / 831 | 0.91 / 0.71 | +0.095 / +0.083 | 1.201 / 1.205 | 24.3 / 16.6R | +0.087 / +0.059 | 685 / 515 | | +0.087 / +0.131 | 1.186 / 1.319 | | +0.077 / +0.086 | survivors |
| USDJPY | B2 / B3 / B4 (London) | 1086 / 1017 / 944 | 0.92 / 0.87 / 0.80 | +0.096 / +0.124 / +0.110 | 1.181 / 1.248 / 1.230 | 28.4 / 20.5 / 19.1R | +0.088 / +0.107 / +0.088 | 668 / 613 / 549 | | −0.001 / +0.064 / +0.047 | 0.999 / 1.128 / 1.097 | | −0.001 / +0.050 / +0.033 | B2 fails VAL; B3/B4 survivors |
| EURUSD | **C3** (secondary slot) | 729 | 0.62 | +0.076 | 1.181 | 24.68R | +0.047 | 512 | 0.65 | +0.105 | 1.225 | 15.75R | +0.069 | survivor |
| EURUSD | C2 | 896 | 0.76 | +0.073 | 1.154 | 27.5R | +0.055 | 589 | 0.75 | +0.094 | 1.190 | 17.9R | +0.071 | fails the 25R DD bar only |
| EURUSD | C4 | 527 | 0.45 | +0.085 | 1.218 | 14.9R | +0.038 | 383 | 0.49 | +0.082 | 1.180 | 15.6R | +0.040 | survivor (low density) |
| EURUSD | A2..A4, B2..B4 | | | −0.042..−0.083 | 0.86..0.93 | | | | | | | | | all negative on SEL |

Drawdowns are quoted exactly (no rounding to the bar): USDJPY C2's validation worst-year drawdown is **25.04R**.

Per-year net R, USDJPY C2: 2018 +24.8, 2019 +12.0, 2020 +13.7, 2021 +51.8, 2022 +38.8 (SEL 141.1R);
2023 +5.2, 2024 +59.2, 2025 +26.7 (VAL 91.0R). Every year positive. Median hold 284 min; exits on SEL: stop
377, trail-stop 202, flat 319, Friday close 92, both-edges-same-bar 8.

Unadjusted 20-business-day block-bootstrap intervals for absolute R/bd (critic, `critique_d7ed93cd_extract.json`):
USDJPY C2 SEL 0.120 [0.049, 0.191], VAL 0.116 [−0.001, 0.247]; USDJPY C3 SEL 0.097 [0.036, 0.157], VAL 0.107
[0.015, 0.211]; EURUSD C3 SEL 0.047 [−0.008, 0.102], VAL 0.069 [−0.012, 0.159].

**Outcome (revised claim):** the family does not transfer as a class (indices, EUR/CHF/CAD crosses, AUDNZD,
GBPNZD negative; XAUUSD only positive in 2023-25), but on USDJPY every one of the nine cells is positive on
SEL and eight survive VAL. **The ABSOLUTE edge of the USDJPY NY pre-open arms is credible for a canary**
(SEL R/bd intervals exclude zero for C2 and C3). **The "≈ 2× the incumbent" statement is descriptive
arithmetic, not an established improvement:** after a paired, dependence-preserving comparison against A3
and a max-of-8 multiplicity correction it is not significant (see "Multiplicity"). H-V4 is therefore carried
as (a) a canary-worthy absolute hypothesis and (b) a pre-registered REPLACEMENT hypothesis versus 13213's
window, to be decided by tester evidence, not by the harness. EURUSD C3 is a marginal secondary finding
(intervals touch zero in both periods) carried only behind USDJPY. **Disposition requested: cross-vendor
critic round 2 (Codex); on APPROVE_BUILD a new EA identity cloned from 13213 (reserved: QM5_41485
`ny-preopen-range-breakout-jpy`) and a USDJPY Q02 canary per arm.** No card, build or factory row exists at
the time of sealing.

## Structural cause

USDJPY's intraday information flow is concentrated around the 08:30 New York macro-release / pre-open hour
(US data prints, Treasury-yield repricing, JPY carry-book adjustment into the US session). A completed 2-3 h
range immediately before that anchor bounds the pre-release consolidation; a stop-order breakout of that range
at the anchor converts the release into a directional trade with a stop equal to the range width and no fixed
target — exactly the risk geometry that already qualified on USDJPY at the Tokyo window (QM5_13213, Q02..Q14).
The sweep says the **anchor**, not the mechanism, was the limiting factor. On EURUSD the London-open anchor
(H-V1's premise) and the Tokyo anchor are both negative; only the NY pre-open range is positive, consistent
with the pair's US-session macro sensitivity rather than a London microstructure effect.

## Mechanical spec — frozen, single-valued, buildable from this section alone (revision 2)

Everything is QM5_13213 (`framework/EAs/QM5_13213_balke-gmt3-range-breakout/`) with the frozen deltas marked
**Δ**. Where 13213 and the harness differ, the **incumbent's behaviour is the frozen one** and the harness
deviation is documented. Bounded integer/double inputs only; no ML, no grid, no martingale, no averaging.

- **Clock / venue (Δ0).** The Darwinex tester/live server clock is the NY-close convention: GMT+2 while US
  DST is off, GMT+3 while it is on — i.e. **server time = America/New_York local time + 7 h, all year**. The
  economic anchor 08:30 America/New_York is therefore the fixed server time **15:30** in every season and the
  flat time 16:00 New York is **23:00 server**; no EU/US DST divergence window affects this hypothesis. **These
  fixed server times are valid for the Darwinex (DXZ) venue only.** An FTMO build must derive both times
  through the named governed session-clock helper (`QM_SessionClock`, the same helper the FTMO kill-switch
  initializer work `d6189118` needs for Prague midnight) from the economic anchor, and no FTMO set file is
  admitted before that helper exists and is unit-tested for both stable seasons and both DST divergence
  windows.
- **Runtime / new-bar contract (Δ1a).** Chart and set-file timeframe **M30**. Strategy logic runs once per
  completed M30 bar behind an explicit `QM_IsNewBar(_Symbol, PERIOD_M30)` gate (order management and exits
  remain per tick as in 13213). All 60-minute-bar semantics of 13213 (range bars, ATR bars, trail bars) are
  evaluated on a **60-minute grid aligned to :30 server time** (grid bars 13:30-14:30, 14:30-15:30, …). Each
  grid bar is the **shift-1 pairing of two consecutive completed M30 bars** (`iOpen/iHigh/iLow/iClose` on
  PERIOD_M30 at shifts ≥ 1; grid open = first half's open, close = second half's close, high/low = max/min).
  **Completeness rule:** if either M30 half-bar of ANY required grid bar (the N range bars and the 14 ATR bars)
  is missing (holiday, feed gap), the day is rejected — no orders. *Harness deviation (documented, not
  sign-flipping):* the harness accepted a bucket built from a single M30 half on 3 USDJPY and 2 EURUSD
  candidate days over the whole span; an independent two-M30 reconstruction otherwise matched the harness on
  48,870/48,870 USDJPY and 48,846/48,846 EURUSD grid bars.
- **Δ1b Range.** Range = the **N completed grid bars ending at 15:30 server**: arm **C2: N = 2** (13:30-15:30
  server = 06:30-08:30 New York; primary), arm **C3: N = 3** (12:30-15:30; second frozen arm). Range high `RH`,
  low `RL`, width `W = RH − RL`.
- **Filter (unchanged).** `ATR(14)` = simple 14-bar average of the true range on the same :30-aligned grid,
  read on the last completed grid bar before 15:30 (14:30-15:30). Skip the day when `W < 0.4 × ATR` or
  `W > 2.5 × ATR` (`strategy_min_range_atr_mult` / `strategy_max_range_atr_mult`).
- **Orders and OCO (Δ1c, contract made explicit).** At the first eligible tick at or after 15:30 server (see
  the news rule): send a buy stop at `RH` with SL `RL` and a sell stop at `RL` with SL `RH`, no take profit,
  sized by the framework risk module on the stop distance `W` (RISK_FIXED 1000 in backtests, RISK_PERCENT
  live). **Both send results are retained.** If only one send succeeds, the survivor is cancelled and no trade
  is taken that day (fail-closed); a day is never traded one-sided. One-cancels-other: on the first fill the
  peer pending order is removed on the fill transaction or, at the latest, on the next tick (13213
  `Strategy_ManageOpenPosition`: `Strategy_RemoveOurPendingOrders("BALKE_RANGE_OPPOSITE_TRIGGERED")`). Exactly
  **one position per symbol per day**; after any exit no re-entry that day. *Harness model (documented):* fills
  at the level on the touching M1 bar; both edges touched in the same M1 bar = full loss at the stop; OCO
  atomic after the first fill; no gaps, spread, stop-level rejection, lot rounding or slippage — the real-tick
  tester (Model 4) is therefore a necessary measurement, not a formality.
- **News rule (Δ1d, frozen as measured).** The framework high-impact blackout (`QM_NEWS_TEMPORAL_PRE30_POST30`,
  DXZ compliance profile) applies to placement. If the anchor tick is inside a blackout, placement is retried
  at the **first eligible time in the window [15:30, 16:30) server**; **no placement at or after 16:30** that
  day (day state `news_blocked`). Because the framework caches the tester news verdict per chart bar
  (`QM_NewsFilter.mqh:1974-1987`), the EA's effective retry grid is the M30 bar open (15:30, 16:00) — this is
  the frozen contract; the harness retried at minute resolution (documented deviation). *Bound:* the critic's
  strict sensitivity that blocks every day whose anchor is inside a blackout (no delayed placement at all)
  still clears every pre-registered bar: USDJPY C2 SEL n=865 / +0.189R / PF 1.413, VAL n=577 / +0.164R /
  1.338; C3 SEL 797 / +0.172R / 1.416; EURUSD C3 SEL 612 / +0.095R / 1.229 (`critique_d7ed93cd_extract.json`).
  Blackouts during an open position do not close it (as in 13213).
- **Management (unchanged = incumbent behaviour, Δ-wording corrected).** On every tick with an open position:
  `risk_dist = |open_price − CURRENT SL|` (13213 lines 350-367 — the current stop, re-read every evaluation;
  **not** a latched initial risk); once `moved ≥ strategy_trail_trigger_r (1.0) × risk_dist`, trail the SL to
  the lower (long) / higher (short) of the **two most recently completed grid bars** whenever that improves it.
  Exit on the stop (initial or trailed) and at the flat time. *Sensitivity (critic):* latching the initial
  width `W` instead changes E[R] by at most ±0.004R and PF by ≤ 0.011 on every arm (table in
  `critique_d7ed93cd_extract.json`) — not sign-flipping, but the incumbent's current-SL basis is the single
  frozen definition.
- **Δ2 Flat and market gaps.** The **first available tick at or after 23:00 server** (16:00 New York) closes
  any open position and cancels untriggered pending orders; the framework Friday close
  (`qm_friday_close_hour_broker = 21`) closes earlier on Fridays and blocks later entries — unchanged. On a
  holiday early close or feed gap the position is closed at the **first available tick after the flat time**
  (buildable without a calendar). *Harness deviation (documented):* the harness exited retrospectively at the
  final pre-flat bar close for gaps longer than six hours; this affects one VAL trade per arm (and one EURUSD
  SEL trade) — not sign-flipping.
- **Δ3 Inputs.** Minute-resolution anchor inputs replace 13213's integer hours: `strategy_range_end_hour = 15`,
  `strategy_range_end_minute = 30`, `strategy_range_bars = N` (2 or 3), `strategy_exit_hour = 23`,
  `strategy_exit_minute = 0`, `strategy_grid_offset_minutes = 30`, `strategy_news_retry_window_minutes = 60`
  (defaults frozen per arm in the set file). No other logic changes; `strategy_atr_period = 14`,
  `strategy_range_scan_bars = 36`, `strategy_trail_trigger_r = 1.0`, news inputs and Friday close as in 13213.
- **Symbol slots.** USDJPY (slot 0: arm C2; slot 1: arm C3) and EURUSD (slot 2: arm C3 only — EURUSD C2 fails
  the pre-registered 25R drawdown bar at 27.5R and is not carried). Chart symbol drives the strategy; symbols
  are inputs, never literals (OWNER 2026-09-06).

## Density, cost, drawdown (measured)

- Density: USDJPY C2 0.85 trades/bd (SEL) / 0.81 (VAL); C3 0.79 / 0.76; EURUSD C3 0.62 / 0.65. Day states
  over the whole 2018-07..2025 span for USDJPY C2: 1,631 trade days, 145 one-side-only, 107 no-fill,
  97 ATR-filtered, 280 news-delayed and 91 news-blocked placement days, 33 no-range.
- Cost: commission = `max(0.005 % of notional round trip, 5 USD per lot round trip)` (registry forex class);
  per trade at RISK_FIXED 1000: USDJPY C2 median **0.035R** (SEL), C3 0.031R, EURUSD C3 0.026R. Gross E[R]
  for USDJPY C2 is +0.181R on SEL. `.DWX` spread is 0 in this history (stated, not assumed away); the tester
  runs real ticks with the modelled spread and slippage.
- Drawdown (exact): worst calendar-year drawdown USDJPY C2 20.83R (SEL) / **25.04R** (VAL), C3 20.65 / 22.20R,
  EURUSD C3 24.68 / 15.75R — at 1 %/trade that is 21-25 % of a 100k account; at the FTMO sizing of
  0.25 %/trade it is 5.2-6.3 %, inside the 10 % max-loss headroom with margin.

## Universe reconciliation (registration vs harness)

The registration (§3 of the sweep document) stated "369 cells = 41 symbols × 3 × 3" with "33 FX symbols".
That FX count was a **counting error at registration time**: the custom-history store
(`D:/QM/mt5/T*/Bases/Custom/history/`) holds exactly **28 FX** symbol directories (AUDCAD, AUDCHF, AUDJPY,
AUDNZD, AUDUSD, CADCHF, CADJPY, CHFJPY, EURAUD, EURCAD, EURCHF, EURGBP, EURJPY, EURNZD, EURUSD, GBPAUD, GBPCAD,
GBPCHF, GBPJPY, GBPNZD, GBPUSD, NZDCAD, NZDCHF, NZDJPY, NZDUSD, USDCAD, USDCHF, USDJPY), 2 metals (XAUUSD,
XAGUSD), 6 indices (GDAXI, JPN225, NDX, SP500, UK100, WS30) and 3 energy symbols (XBRUSD, XNGUSD, XTIUSD)
that were never part of the registered family (no session-anchor claim) and were not enumerated. The harness
therefore enumerated the complete registered universe that exists: **36 symbols** (28 + 2 + 6), not 41; there
are no five omitted FX symbols. JPN225 has no usable M1 history and GDAXI × A × 4 produced no trades, giving
**314 cells with trades**. `research_trial_count = 314` is unchanged and is the honest denominator.

## Multiplicity (revised) and the replacement hypothesis

314 cells were searched. 27 pass the selection rule versus 17.4 expected by the per-cell centred block
bootstrap null; 13 survive validation versus 5.5 expected; USDJPY C2 has chance-pass probabilities 0.05 (SEL),
0.27 (VAL), 0.0135 (joint). The per-cell null ignores that the cells of one symbol share days and ranges
(eight of the 13 survivors are USDJPY cells), so these sums are **not** a family-level test.

**Critic's dependent test (verbatim, `critique_d7ed93cd_extract.json`):** paired daily-R differences of each
USDJPY cell versus A3, cross-cell dependence preserved, 5,000 circular blocks of 20 business days —
C2 − A3 SEL **+0.066 R/bd, 95 % [−0.030, +0.160], max-of-8 p = 0.164**; VAL **+0.040 [−0.095, +0.182],
p = 0.547**; C3 − A3 SEL +0.043 [−0.045, +0.132], p = 0.246; VAL +0.030 [−0.087, +0.150], p = 0.470.
**Consequence:** the descriptive "roughly twice the R/bd of the incumbent" is true as arithmetic but is not a
statistically established improvement over A3 after choosing among eight alternatives. What the evidence
supports: the absolute edge of C2/C3 (unadjusted SEL R/bd intervals exclude zero; mechanism tester-qualified
on the symbol; 9/9 SEL-positive cells; control-cell calibration; rule/floor/cap/grid pre-registered). What it
does not yet support: that C2 or C3 should REPLACE 13213's window. That is now a **pre-registered hypothesis**
with its own test (falsification criterion 8). EURUSD C3 (one anchor, PF 1.18, 0.62/bd, intervals touching
zero) is a secondary slot only.

## Falsification criteria (pre-registered for the Q02 canary and beyond)

Q02 canary USDJPY, tester window 2018-07-02..2022-12-31, RISK_FIXED 1000, real ticks, each arm a separate
frozen set file:
1. Arm C2: retire if trades < 800, or net E[R] < +0.08R after costs, or PF < 1.15. Calibration alarm (distinct
   from retirement): trade count more than ±15 % from the harness (998) or E[R] below +0.09R — investigate the
   build before any further step.
2. Arm C3: retire if trades < 740, or E[R] < +0.07R, or PF < 1.15 (calibration alarm at ±15 % of 926 trades /
   E[R] below +0.08R).
3. EURUSD C3: retire the slot if E[R] < +0.04R or PF < 1.10 or trades < 580.
4. **Build-regression bar (not fresh holdout evidence):** the 2023-2025 window must retain ≥ 70 % of the
   selection-period R/bd for each surviving arm (harness VAL/SEL ratios: C2 0.97, C3 1.10, EURUSD C3 1.46).
   This rule was added to the sealed source AFTER the validation results were observed (it is absent from the
   pre-sweep registration) and is therefore a pre-registered regression check for the tester build, not
   independent holdout evidence.
5. **Q05 drawdown (exact, no rounding).** Authoritative field: the Q05 report's maximal equity drawdown at
   RISK_FIXED 1000 over the Q05 window (`drawdown` of the run summary, in USD; 1R = 1,000 USD). Bar: retire the
   arm if it exceeds **25R** (25 % at 1 %/trade; 6.25 % of a 100k account at the FTMO sizing of 0.25 %/trade,
   inside the 10 % max-loss headroom). The harness worst calendar-year drawdown of C2 on the validation period
   is **25.04R — at the bar**. Consequently: if the tester's Q05 prints above 25R for C2, **C2 retires and C3
   (harness VAL 22.20R) is the fallback arm**; both arms are built and measured as separate frozen arms from
   the start so that this decision needs no second build.
6. Tail tests (Q08 dependence panel): daily-P/L correlation with **QM5_13213** (same symbol; expected high
   overlap) — if |r| ≥ 0.5 H-V4 is a REPLACEMENT/upgrade candidate for 13213's window, not an additional
   sleeve, and the book layer must choose one; no artifact may claim independent book capacity before Q08
   measures it. With 10706 (GBPUSD H1) and 10700 (XAUUSD) |r| > 0.30 or lower-decile-day co-occurrence > 2×
   the independence baseline blocks joint carding, as for the H-CW/H-MR panel
   (`docs/ftmo/FTMO_PORTFOLIO_GAP_CURRENT.md` §3).
7. Q04/Q08 activity criterion: ≥ 10 distinct entry days in every scored year (harness: ≥ 116 per year).
8. **Replacement hypothesis test (pre-registered, new in revision 2).** At Q02, from the tester trade
   streams of the new arm and of 13213's existing qualified Q02 stream (same symbol, same window
   2018-07-02..2022-12-31, same RISK_FIXED): form the paired daily-R difference (new arm − 13213) and bootstrap
   its mean with a 20-business-day circular block bootstrap, 5,000 resamples, seed 20260921. H-V4 is a
   supported REPLACEMENT of 13213's window only if the 95 % interval of the mean difference excludes zero for
   the primary arm (C2; if C2 retires under criterion 5, C3). Otherwise H-V4 may still qualify on its
   absolute bars and the book layer decides between the two windows under criterion 6.
No parameter search is authorised on this artifact; N and the anchor are frozen, Q13 handles optimisation for
survivors.

## Distinct from 13213 / 41484 / 41097 / 41398 / 41405 / 10706 / 10700 / retired 0009-0011

- **QM5_13213 (Balke GMT+3 range breakout, USDJPY H1, qualified through Q14):** identical mechanics; the
  **evidence-based delta** is the anchor and range grid — the 2-3 h range before 15:30 server (08:30 New
  York) on a :30-aligned grid instead of the 03:00-06:00 GMT+3 Tokyo range, flat 23:00 server instead of
  18:00 GMT+3 — measured at +0.141R / +0.120 R/bd versus +0.070R / +0.054 R/bd for the incumbent window in the
  same harness (same symbol, same period, same costs; paired difference not yet significant, criterion 8).
  H-V4 is a candidate upgrade of 13213's window (tail test 6), not a second copy.
- **QM5_41484 (Balke FX fan-out, RETIRED 2026-09-20):** the same Tokyo window transplanted onto nine other FX
  symbols, all flat-to-negative. **Evidence-based delta:** H-V4 does not transplant the window; it changes the
  anchor on the symbol where the mechanism is proven, and adds EURUSD only on the one anchor (NY) where the
  sweep measured expectancy (EURUSD Tokyo/London anchors are negative, as 41484 already found).
- **QM5_41097 (legacy Balke USDJPY pre-v3 census) and QM5_41398 (Balke USDJPY winsweep) and QM5_41405
  (Balke-2 matrix):** parameter and filter censuses of the SAME Tokyo window (the census frontier holdout
  showed in-sample winners do not beat the baseline OOS). **Evidence-based delta:** H-V4 does not search
  parameters inside the Tokyo window; it moves the session anchor, which no census cell varied.
- **QM5_10706 (GBPUSD H1, not session-gated, 46 % overnight) and QM5_10700 (XAUUSD, 58 % overnight):**
  different symbols and always-on mechanisms; H-V4 is a single-window, 0 %-overnight breakout. Joint-tail
  check pre-registered (criterion 6).
- **Retired QM-RESEARCH-2026-0009 (H-V1 London-open range EURUSD/GBPUSD), 0010 (H-V2 XAUUSD NY pre-open
  range), 0011 (H-V3 JPY-cross gap fade):** those used 60-minute ranges with fixed 1.5-2.0× targets and were
  falsified on cost. **Evidence-based delta:** H-V4 keeps the 13213 geometry (multi-hour range, stop = range
  width, no fixed target, two-bar trail, session flat) that survives commission, and — unlike 0010 — applies
  the NY pre-open anchor to USDJPY/EURUSD where the sweep measured it, not to gold where it did not.

## Revision 2 (2026-09-21) — changes vs critique d7ed93cd

| # | critic point | resolution in this revision |
|---|---|---|
| 1 | M30 pairing / completeness not stated; harness accepted single-half buckets | Runtime contract: M30 chart/set, `QM_IsNewBar(PERIOD_M30)` gate, shift-1 pairing, day rejected on any missing half-bar; harness deviation (3 USDJPY / 2 EURUSD days) documented |
| 2 | News retry window unstated (harness: one hour, minute resolution) | Frozen: retry in [15:30, 16:30) server, none at/after 16:30; EA retry grid = M30 bar open (framework per-bar cache); strict-blackout sensitivity cited as the bound |
| 3 | Trail: "initial risk" vs incumbent current-SL basis | Frozen to the incumbent (current SL re-read every evaluation, 13213:350-367); "initial risk" removed; sensitivity table cited |
| 4 | Holiday/gap exit: retrospective pre-flat close is not buildable | Frozen: first available tick at or after the flat time; harness deviation (one trade per arm) documented |
| 5 | OCO guarantee / one-send failure undefined | Both send results retained; one-sided day = cancel survivor, no trade (fail-closed); peer removed on fill transaction or next tick; one position per symbol per day |
| 6 | 15:30/23:00 only valid on the DXZ clock | Stated; FTMO build requires the governed `QM_SessionClock` helper (shared with d6189118) before any FTMO set |
| 7 | C2 VAL DD 25.04R vs "retire above 25R" | No rounding; authoritative Q05 field defined; C2 at the bar → C3 is the fallback arm; both arms built as separate frozen arms |
| 8 | 41 registered symbols vs 36 enumerated | Registration miscounted FX (33 claimed, 28 exist); universe reconciled symbol by symbol; 314 unchanged |
| 9 | 70 % holdout rule added after VAL was seen | Relabelled as a pre-registered build-regression bar, not fresh holdout evidence |
| 10 | +0.02R calibration is A3-only | Wording revised: planning heuristic; arm-specific gap only from the Q02 tester |
| 11 | "2× incumbent" not supported after dependent multiplicity | Claim downgraded to a pre-registered replacement hypothesis; critic's paired result quoted verbatim; criterion 8 pre-registers the paired Q02 test; absolute edge retained for the canary |
| 12 | — | This table; title suffixed "— revision 2"; `critique_d7ed93cd_extract.json` sealed as a computed output |

## Source manifest

```qm-source-manifest
# Auto-generated by research_source.seal; do not hand-edit.
research.json:                  81e23abd25a2ef626835b90007727a728818c22618c5283a94b4cf73f07f7831
lineage.json:                   e335665710b9f746a142ca008f681fc980388ba04f4270867aa630c58db4ed25
critic_receipt.json:            1907e0897bb7b718a0ef44ce01ad7db68bdc99583245ebb9ba33195d8cda2ac5
sweep_extract.json:             247c595106904451c162f5ed6296abe09790d46f01195d26e8b8bde7a1b6e6ea
critique_d7ed93cd_extract.json: 4f6a73a6ad3619d4ed8c729c9446ee206246de32ed079f06a8083262a543dd6b
```
