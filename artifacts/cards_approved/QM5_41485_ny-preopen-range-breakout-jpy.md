---
ea_id: QM5_41485
slug: ny-preopen-range-breakout-jpy
type: strategy
source_id: QM-RESEARCH-2026-0012
source_type: internal_research
source_artifact: QM-RESEARCH://2026-0012
source_hash: 2120bd972a80cc0abf4024f9e6bdf96717c71599e46f7a5396e1439c5bd8bcb8
source_author: Claude
source_model: claude-fable-5-1
research_trial_count: 314
parent_ea_id: QM5_13213
parent_slug: balke-gmt3-range-breakout
candidate_role: VELOCITY_SLEEVE
lineage_status: RETIRED
retired_at: 2026-09-21
retired_reason: pre-registered holdout bar failed (Q04 folds 2023-2025 pf_net 1.004/0.724/0.916); harness release-tick modelling artefact
book_decision: OWNER-DEC-FTMO-BOOK-PORTFOLIO-20260921
concepts:
  - "[[concepts/session-range-breakout]]"
  - "[[concepts/session-flat-intraday]]"
indicators:
  - "[[indicators/atr]]"
target_symbols: [USDJPY.DWX, EURUSD.DWX]
primary_target_symbols: [USDJPY.DWX]
period: M30
timeframe: M30
expected_trade_frequency: "One bracket per symbol per weekday at most: harness 0.85 trades per business day on USDJPY (C2), 0.79 (C3) and 0.62 on EURUSD (C3), i.e. roughly 200-215 trades per year per USDJPY arm and 150-165 per year on EURUSD, with entries on at least 116 distinct days per year."
expected_trades_per_year_per_symbol: 210
expected_pf: 1.25
expected_dd_pct: 6.25
g0_status: APPROVED
review_status: REVIEW_PENDING
g0_authority: "FABLE (OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917); cross-vendor critiques d7ed93cd (round 1, REVISE) and afb38e9a (round 2, APPROVE_BUILD on USDJPY C2 / USDJPY C3 / EURUSD C3); candidate role VELOCITY_SLEEVE per OWNER-DEC-FTMO-BOOK-PORTFOLIO-20260921"
g0_approval_reasoning: "Fable G0 approval of the H-V4 velocity-sleeve card (QM-RESEARCH-2026-0012 revision 2, sealed reviewed; Codex critiques d7ed93cd REVISE -> afb38e9a APPROVE_BUILD on USDJPY C2 / USDJPY C3 / EURUSD C3); OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917; role VELOCITY_SLEEVE per OWNER-DEC-FTMO-BOOK-PORT"
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-09-21
card_sha256: 76df573e63a79d6b6d3a330d6605fbbfec36ed4540695ca0c989861f7b32f61f
---

# H-V4: New-York pre-open session-range breakout (13213 mechanics, :30-aligned M30 lattice)

Target symbols: USDJPY.DWX, EURUSD.DWX (primary: USDJPY.DWX). Candidate role: `VELOCITY_SLEEVE` — this card is
evaluated by its marginal contribution to FTMO_BOOK (OWNER-DEC-FTMO-BOOK-PORTFOLIO-20260921), never as an
FTMO solution on its own.

## Source
- Source: [[sources/QM-RESEARCH-2026-0012]] (`QM-RESEARCH://2026-0012`, revision 2, sealed `reviewed`) — Fable-originated
  hypothesis H-V4 from the pre-registered family-F1 sweep `docs/research/velocity/VELOCITY_FAMILY_F1_SESSION_RANGE_SWEEP_2026-09-21.md`
  (registration commit 60de323f25 before the run; results 270c9a4c98; 0 factory hours; M1 `.hcc` harness validated bar-for-bar
  against the terminal's own export).
- Parent mechanism: QM5_13213 `balke-gmt3-range-breakout` (René Balke ForexFactory range breakout, OWNER-verified port, qualified
  through Q14 on USDJPY H1). H-V4 keeps the mechanics byte-for-byte and moves only the session anchor and range lattice.
- Cross-vendor critiques (Codex, read-only): round 1 `docs/ops/evidence/2026-09-20_velocity_book/hv4_critique_d7ed93cd.md`
  (REVISE, 12 build-contract points), round 2 `docs/ops/evidence/2026-09-20_velocity_book/hv4_critique_round2_afb38e9a.md`
  (APPROVE_BUILD on USDJPY C2, USDJPY C3, EURUSD C3). The critic receipt is sealed in the research artifact.
- Offline statistics (block bootstrap, paired tests) were used in research only; every rule below is fully mechanical.

## Structural cause
USDJPY's dominant intraday impulse is the New-York pre-open (08:30 America/New_York = 15:30 server on the Darwinex NY-close
clock): the range formed in the two to three hours before the US macro-release slot compresses the Tokyo/London information,
and a stop-order breakout of that range in either direction, held with a stop at the opposite edge and closed flat before the
US close, captures the directional resolution. The same geometry is the qualified 13213 edge on the Tokyo range; the
pre-registered sweep measured the NY pre-open anchor at roughly twice the R per business day of the Tokyo anchor on USDJPY
(paired difference not yet significant — a pre-registered replacement test decides at Q02), while EURUSD carries the effect
only on this anchor.

## Price signature
A completed multi-hour range ending exactly at 15:30 server whose width is between 0.4 and 2.5 ATR(14) on the same lattice; the
first close-through of the range edge after the anchor continues into the US session; the move is captured with a stop at the
opposite range edge, trailed behind the last two completed lattice bars once one initial risk is earned, and closed at 23:00
server (16:00 New York) at the latest.

## Persistence
The effect rests on the recurring pre-open inventory build-up and release around the US macro slot, defended by the range
filter, the framework high-impact news blackout and the hard session flat rather than by any fitted parameter; selection
2018-07..2022-12 and validation 2023..2025 are both positive in every calendar year on USDJPY (harness).

## Mechanics
Everything is QM5_13213 with three frozen deltas (Δ). The incumbent behaviour is the frozen one wherever the harness differed.

### Entry
- Runtime M30; strategy logic once per completed M30 bar behind `QM_IsNewBar(_Symbol, PERIOD_M30)`; order management and exits per tick.
- Range = the N completed 60-minute lattice bars ending at 15:30 server on a lattice aligned to :30 server time (lattice bar = shift-1
  pairing of two consecutive completed M30 bars; if either half of any required range or ATR bar is missing the day is rejected).
  Arm C2: N = 2 (13:30-15:30 server); arm C3: N = 3 (12:30-15:30 server). Range high RH, low RL, width W = RH − RL.
- Filter: skip the day when W < 0.4 × ATR(14) or W > 2.5 × ATR(14), ATR on the same 30-minute-offset 60-minute lattice read on the last completed
  lattice bar before 15:30.
- At the first eligible tick at or after 15:30 server: buy stop at RH (SL RL) and sell stop at RL (SL RH), no take profit,
  one-cancels-other. Both send results are retained; if only one send succeeds the survivor is cancelled and no trade is taken
  that day. Exactly one position per symbol per day; no re-entry after any exit.
- News: framework high-impact blackout (`QM_NEWS_TEMPORAL_PRE30_POST30`, DXZ profile) applies to placement; if the anchor is inside
  a blackout, placement is retried only in [15:30, 16:30) server (effective retry opportunities: the M30 bar opens 15:30 and 16:00);
  no placement at or after 16:30 that day.

### Exit
- Exit on the stop (initial or trailed), on the opposite range edge via the stop, or at the flat time: the first available tick at
  or after 23:00 server (16:00 New York) closes any open position and cancels untriggered pending orders. Framework Friday close
  (`qm_friday_close_hour_broker = 21`) closes earlier on Fridays and blocks later entries. On a holiday early close or feed gap the
  position is closed at the first available tick after the flat time. No overnight hold, no weekend carry.

### Stop loss
- Initial stop = the opposite range edge (stop distance = W, bounded by the 2.5 × ATR cap).

### Take profit
- None (fixed target explicitly absent, as in 13213).

### Trailing logic
- On every tick with an open position: risk_dist = |open_price − CURRENT SL| (re-read each evaluation, not a latched initial risk);
  once open profit ≥ 1.0 × risk_dist (`strategy_trail_trigger_r`), trail the SL to the lower (long) / higher (short) of the two most
  recently completed lattice bars whenever that improves it.

### Position sizing
- Framework risk module on the stop distance W: RISK_FIXED 1000 / RISK_PERCENT 0 in backtests, RISK_PERCENT live; book weight is
  set by the FTMO_BOOK layer, never by the EA.

### Session rules
- Server time = America/New_York local time + 7 h all year on the Darwinex clock (GMT+2 while US DST is off, GMT+3 while on), so the
  15:30 / 23:00 server anchors are fixed for the DXZ venue. An FTMO build must derive both times through the governed `QM_SessionClock`
  helper (the same helper the kill-switch initializer work d6189118 needs); no FTMO set file is admitted before that helper exists and
  passes its stable-season and DST-divergence tests.

### Filters
- Range width 0.4-2.5 × ATR(14) on the :30-offset lattice; framework high-impact news blackout; Friday close; completeness rule on the lattice bars.

## Deterministic risk contract
- One position per symbol per day, hard stop at the opposite range edge capped at 2.5 × ATR, flat at 23:00 server at the latest,
  no scaling-in, no adverse-add mechanics, single position. Joint exposure across the slots and the account-level Daily/Max Loss headroom are
  governed by the account-level FTMO governor and the book layer, not by this EA.

## Indicators and required data
- ATR(14) as a simple average of the true range on the :30-aligned 60-minute lattice built from M30 bars; M30 OHLC history for the
  range; tick data for the real-tick tester (Model 4) at Q02.

## Timeframe
M30 chart/set-file timeframe (strategy on completed M30 bars; 60-minute lattice semantics via shift-1 M30 pairs).

## Symbols
Target symbols: USDJPY.DWX (slot 0: arm C2, primary; slot 1: arm C3, second frozen arm), EURUSD.DWX (slot 2: arm C3 only — EURUSD C2
fails the pre-registered 25R drawdown bar at 27.5R and is not carried). Chart symbol drives the strategy; symbols are inputs, never
literals (OWNER 2026-09-06). Each arm is a separate frozen set file; N and the anchor are not build-time or Q02 search dimensions.

## Parameter ranges
Frozen per arm in the set file (bounded inputs, no optimisation authorised on this card):
- `strategy_range_end_hour = 15`, `strategy_range_end_minute = 30`, `strategy_range_bars = 2` (C2) / `3` (C3),
  `strategy_exit_hour = 23`, `strategy_exit_minute = 0`, `strategy_grid_offset_minutes = 30`, `strategy_news_retry_window_minutes = 60`,
  `strategy_atr_period = 14`, `strategy_min_range_atr_mult = 0.4`, `strategy_max_range_atr_mult = 2.5`, `strategy_trail_trigger_r = 1.0`,
  `strategy_range_scan_bars = 36`; news inputs and `qm_friday_close_hour_broker = 21` as in 13213; `qm_news_stale_max_hours ≤ 336`.

## Expected frequency
Harness (M1 closed-bar, commission-only, `.DWX` spread 0; harness ≈ +0.02R optimistic versus the 13213 control cell, an A3-only
planning heuristic): USDJPY C2 SEL 2018-07..2022-12 n=998 / 0.85 per bd / E[R] +0.141 / PF 1.30 / worst-year DD 20.8R / +0.120 R/bd;
VAL 2023-25 n=632 / +0.144 / PF 1.30 / DD 25.04R / +0.116 R/bd. USDJPY C3 SEL +0.123 / PF 1.29 / 0.79 per bd; VAL +0.141 / PF 1.32 /
DD 22.2R. EURUSD C3 SEL n=729 / 0.62 per bd / +0.076 / PF 1.18; VAL +0.105 / PF 1.23. The Q02 tester is the measurement of record.

## Invalidation conditions
- The tester does not reproduce the harness within the calibration tolerance (trade count ±15 %, E[R] within +0.03R of the harness
  minus the planning optimism) — investigate the build before any further step (calibration alarm, distinct from retirement).

## Falsification / kill criteria
Q02 canary USDJPY, tester window 2018-07-02..2022-12-31, RISK_FIXED 1000, real ticks, each arm a separate frozen set file:
1. Arm C2: retire if trades < 800, or net E[R] < +0.08R after costs, or PF < 1.15. Calibration alarm (distinct from retirement):
   trade count more than ±15 % from the harness (998) or E[R] below +0.09R — investigate the build before any further step.
2. Arm C3: retire if trades < 740, or E[R] < +0.07R, or PF < 1.15 (calibration alarm at ±15 % of 926 trades / E[R] below +0.08R).
3. EURUSD C3: retire the slot if E[R] < +0.04R or PF < 1.10 or trades < 580.
4. Build-regression bar (not fresh holdout evidence): the 2023-2025 window must retain ≥ 70 % of the selection-period R/bd for each
   surviving arm (harness VAL/SEL ratios: C2 0.97, C3 1.10, EURUSD C3 1.46). This rule was added to the sealed source AFTER the
   validation results were observed and is therefore a pre-registered regression check for the tester build, not independent
   holdout evidence.
5. Q05 drawdown (exact, no rounding). Authoritative field: the Q05 report's maximal equity drawdown at RISK_FIXED 1000 over the Q05
   window (`drawdown` of the run summary, in USD; 1R = 1,000 USD). Bar: retire the arm if it exceeds 25R (25 % at 1 %/trade; 6.25 %
   of a 100k account at the FTMO sizing of 0.25 %/trade, inside the 10 % max-loss headroom). The harness worst calendar-year drawdown
   of C2 on the validation period is 25.04R — at the bar. Consequently: if the tester's Q05 prints above 25R for C2, C2 retires and C3
   (harness VAL 22.20R) is the fallback arm; both arms are built and measured as separate frozen arms from the start.
6. Tail tests (Q08 dependence panel): daily-P/L correlation with QM5_13213 (same symbol; expected high overlap) — if |r| ≥ 0.5 H-V4
   is a REPLACEMENT/upgrade candidate for 13213's window, not an additional sleeve, and the book layer must choose one; no artifact
   may claim independent book capacity before Q08 measures it. With 10706 (GBPUSD H1) and 10700 (XAUUSD) |r| > 0.30 or
   lower-decile-day co-occurrence > 2× the independence baseline blocks joint carding (`docs/ftmo/FTMO_PORTFOLIO_GAP_CURRENT.md` §3).
7. Q04/Q08 activity criterion: ≥ 10 distinct entry days in every scored year (harness: ≥ 116 per year).
8. Replacement hypothesis test (pre-registered): at Q02, from the tester trade streams of the new arm and of 13213's existing
   qualified Q02 stream (same symbol, same window, same RISK_FIXED), the paired daily-R difference (new arm − 13213) is
   bootstrapped with a 20-business-day circular block bootstrap, 5,000 resamples, seed 20260921; H-V4 is a supported REPLACEMENT of
   13213's window only if the 95 % interval of the mean difference excludes zero for the primary arm (C2; if C2 retires under
   criterion 5, C3). Otherwise H-V4 may still qualify on its absolute bars and the book layer decides between the two windows.

## Q08/Q11 crisis and news risk
Session-bounded intraday exposure (flat by 23:00 server), single position per symbol, hard stop = range edge capped at 2.5 × ATR;
the framework high-impact blackout gates placement (a blackout during an open position does not close it, as in 13213). The
critic's strict no-retry news sensitivity still clears every pre-registered bar (USDJPY C2 SEL n=865 / +0.189R / PF 1.41).

## FTMO fit
The account-level FTMO governor, not this EA, enforces the FTMO limits at book level — 5 % of the daily starting balance (Maximum Daily Loss) and 10 % total drawdown (Maximum Loss); this sleeve contributes a bounded per-trade loss (stop = range width, at most 2.5 × ATR), a session-flat H1-class hold and the fail-closed news blackout, so the event windows those limits protect stay closed. Expected drawdown at the FTMO sizing of 0.25 %/trade is 6.25 % of a 100k account (the Q05 bar of 25R at 1 %/trade). Candidate role VELOCITY_SLEEVE: 0 % overnight, ≈ 0.85 opportunities per business day on USDJPY, hold ≈ 4.7 h median, exits before the
US close. Evaluated by marginal contribution to FTMO_BOOK (OWNER-DEC-FTMO-BOOK-PORTFOLIO-20260921): ΔP_FIRST_NET_FTMO_PAYOUT_LCB,
Δ breach probabilities, Δ time-to-target, Δ drawdown, Δ density and Δ tail dependence against the current book — and, because the
symbol and mechanism class are shared with the deployed sleeve QM5_13213, explicitly as a possible upgrade of that sleeve's window
(criteria 6 and 8), not as additive capacity.

## Concepts
- [[concepts/session-range-breakout]], [[concepts/session-flat-intraday]], [[indicators/atr]].

## R1-R4 assessment
- R1 PASS — internal research source QM-RESEARCH-2026-0012 (revision 2, sealed, cross-vendor critic Codex APPROVE_BUILD); parent
  mechanism QM5_13213 qualified through Q14 on USDJPY; pre-registered sweep with control-cell calibration.
- R2 PASS — fully mechanical, bounded inputs, no discretionary element.
- R3 PASS — USDJPY.DWX and EURUSD.DWX custom history (M1 2017-2026) present in the factory; real-tick tester available.
- R4 PASS — no ML, no scaling-in, no adverse-add mechanics; offline statistics used for research only.

## Framework Alignment
- Symbols are inputs (HR annex 2026-09-06); live builds use the live news filter, never the backtest archive (principle 8);
  RISK_FIXED for backtests / RISK_PERCENT live; magic = ea_id × 10000 + slot; no gate criteria touched.

## Pipeline history
- 2026-09-21: QM-RESEARCH-2026-0012 minted (revision 1), critique d7ed93cd REVISE, revision 2 sealed (9de5d9a43a), critique afb38e9a
  APPROVE_BUILD; identity QM5_41485 reserved (da8431753d); card approved by Fable; build and USDJPY Q02 canary follow.

## Related strategies
- Distinct from QM5_13213 (Balke GMT+3 range breakout, USDJPY H1): identical mechanics; the evidence-based delta is the anchor and
  range lattice — the 2-3 h range before 15:30 server (08:30 New York) on a 30-minute-offset 60-minute lattice instead of the 03:00-06:00 GMT+3 Tokyo
  range, flat 23:00 server instead of 18:00 GMT+3 — measured at +0.141R / +0.120 R/bd versus +0.070R / +0.054 R/bd for the incumbent
  window in the same harness; H-V4 is a candidate upgrade of 13213's window, not a second copy.
- Distinct from QM5_41484 (Balke FX fan-out, RETIRED 2026-09-20): the same Tokyo window transplanted onto nine other FX symbols was
  flat-to-negative; the evidence-based delta is that H-V4 changes the anchor on the symbol where the mechanism is proven and adds
  EURUSD only on the one anchor where the sweep measured expectancy.
- Distinct from QM5_41097 / QM5_41398 / QM5_41405 (Balke censuses of the same Tokyo window): H-V4 moves the session anchor, which
  no census cell varied.
- Distinct from QM5_10706 (GBPUSD H1, 46 % overnight) and QM5_10700 (XAUUSD, 58 % overnight): different symbols, always-on
  mechanisms; joint-tail check pre-registered (criterion 6).
- Distinct from the retired QM-RESEARCH-2026-0009 / 0010 / 0011 (60-minute ranges with fixed targets, falsified on cost): H-V4 keeps
  the 13213 geometry that survives commission.

## Lessons Learned
- A 60-minute pre-open range with a range-width stop cannot carry commission plus spread (H-V1/H-V2); the multi-hour range with no
  fixed target can. Every Velocity hypothesis now runs the 30-second M1 prescreen before a card; the tester remains the measurement
  of record and the book layer remains the judge of value.

## Retired 2026-09-21 (Fable) - pre-registered holdout bar failed

Tester Q02 2018-07..2022-12 (ffe3a8dc) cleared every pre-registered bar (875 trades, E[R] +0.151R, PF 1.31, DD 18.3R), but the
out-of-sample folds failed: Q03 2024 PF 0.73 (-23.5R), Q04 folds 2023/2024/2025 pf_net 1.004 / 0.724 / 0.916 -> FAIL. The
trade-by-trade reconciliation (`docs/ops/evidence/2026-09-20_velocity_book/qm5_41485_2024_reconciliation.md`) shows the harness
validation numbers were a modelling artefact (bid-only M1 fills at the 15:30 release tick that a real-tick tester rejects or fills
against the trader; 52 % of the 2024 gap), not an EA defect. Card action per OWNER-DEC-FTMO-BOOK-PORTFOLIO-20260921: RETIRE, no
book value; the EURUSD C3 arm was retired earlier the same day (PF 1.08 < 1.10, DD 40.9R). The card_sha256 above binds the
approved bytes before this note; no further intake is authorised.
