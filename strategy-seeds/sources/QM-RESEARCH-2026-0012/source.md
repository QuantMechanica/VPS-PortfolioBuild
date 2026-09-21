---
source_id: QM-RESEARCH-2026-0012
title: NY pre-open session-range breakout on USDJPY (H-V4, 13213 mechanics, 15:30-server anchor, M30 range grid)
source_type: internal_research
source_author: Claude
source_model: claude-fable-5-1
created: 2026-09-21
originating_task_id: fable-velocity-hv4-20260921
status: draft
parent_source_ids: []
source_artifact: QM-RESEARCH://2026-0012
---

# NY pre-open session-range breakout on USDJPY (H-V4, 13213 mechanics, 15:30-server anchor, M30 range grid)

## Research provenance

Authored by Fable (Claude, claude-fable-5-1) on 2026-09-21 from the **pre-registered family-F1 sweep**
(`docs/research/velocity/VELOCITY_FAMILY_F1_SESSION_RANGE_SWEEP_2026-09-21.md`; registration committed
before the run at `60de323f25`, results at `270c9a4c98`) under the Velocity-book programme
(`docs/ops/evidence/2026-09-20_velocity_book/README.md`, OWNER 2026-09-20). No ML/statistical search
instrument was used; the sweep is a deterministic closed-bar simulation of ONE frozen mechanism (the qualified
incumbent QM5_13213) over a fixed grid of 36 symbols × 3 session anchors × range lengths N ∈ {2, 3, 4} hours on
the factory's own `.DWX` M1 custom history (0 factory hours), read through
`tools/strategy_farm/session_tools/hcc_m1_reader_0921.py` and simulated by
`tools/strategy_farm/session_tools/velocity_family_f1_sweep_0921.py`. Every figure below is copied from
`sweep_extract.json` (sealed next to this file; produced by
`tools/strategy_farm/session_tools/velocity_hv4_sweep_extract_20260921.py`, which copies the cited cells
verbatim from the sweep output and records that file's sha256). The harness was calibrated on a control
cell against a real tester report: USDJPY × Tokyo window (13213's own configuration) versus the Q02 of the
byte-identical lineage QM5_41484 (work item `652e0768`): 904 vs 888 trades (+1.8 %), E[R] +0.070 vs +0.053
(+0.018R), median hold 421 vs 419 min, 881 of 886 common trade days in the same direction. **Read every
harness E[R] as ≈ +0.02R above what the tester prints** (zero-spread, zero-slippage fills at the level;
18 simulation-only days).

`research_trial_count = 314` is the honest multiplicity denominator: every grid cell evaluated in the sweep.

## Prescreen outcome (read this first)

Selection SEL = 2018-07-02..2022-12-30 (1,175 business days), validation VAL = 2023-01-02..2025-12-31
(783 bd). R at RISK_FIXED 1000, after registry commission, `.DWX` spread 0. Arms are the range length N;
anchor C = range ending 08:30 America/New_York = **15:30 server** (see the clock note in the spec).

| symbol | cell | SEL n | /bd | E[R] | PF | worst-yr DD | R/bd | VAL n | /bd | E[R] | PF | DD | R/bd | rule |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| USDJPY | **C2** (primary) | 998 | 0.85 | **+0.141** | **1.302** | 20.8R | **+0.120** | 632 | 0.81 | **+0.144** | **1.295** | 25.0R | **+0.116** | survivor |
| USDJPY | **C3** (second arm) | 926 | 0.79 | +0.123 | 1.288 | 20.7R | +0.097 | 596 | 0.76 | +0.141 | 1.319 | 22.2R | +0.107 | survivor |
| USDJPY | C4 | 818 | 0.70 | +0.085 | 1.213 | 23.2R | +0.059 | 538 | 0.69 | +0.090 | 1.215 | 19.9R | +0.062 | survivor |
| USDJPY | A3 (= 13213 incumbent window) | 904 | 0.77 | +0.070 | 1.167 | 19.9R | +0.054 | 577 | 0.74 | +0.104 | 1.242 | 19.3R | +0.077 | survivor (control) |
| USDJPY | A2 / A4 | 1072 / 831 | 0.91 / 0.71 | +0.095 / +0.083 | 1.201 / 1.205 | 24.3 / 16.6R | +0.087 / +0.059 | 685 / 515 | | +0.087 / +0.131 | 1.186 / 1.319 | | +0.077 / +0.086 | survivors |
| USDJPY | B2 / B3 / B4 (London) | 1086 / 1017 / 944 | 0.92 / 0.87 / 0.80 | +0.096 / +0.124 / +0.110 | 1.181 / 1.248 / 1.230 | 28.4 / 20.5 / 19.1R | +0.088 / +0.107 / +0.088 | 668 / 613 / 549 | | −0.001 / +0.064 / +0.047 | 0.999 / 1.128 / 1.097 | | −0.001 / +0.050 / +0.033 | B2 fails VAL; B3/B4 survivors |
| EURUSD | **C3** (secondary slot) | 729 | 0.62 | +0.076 | 1.181 | 24.7R | +0.047 | 512 | 0.65 | +0.105 | 1.225 | 15.8R | +0.069 | survivor |
| EURUSD | C2 | 896 | 0.76 | +0.073 | 1.154 | 27.5R | +0.055 | 589 | 0.75 | +0.094 | 1.190 | 17.9R | +0.071 | fails the 25R DD bar only |
| EURUSD | C4 | 527 | 0.45 | +0.085 | 1.218 | 14.9R | +0.038 | 383 | 0.49 | +0.082 | 1.180 | 15.6R | +0.040 | survivor (low density) |
| EURUSD | A2..A4, B2..B4 | | | −0.042..−0.083 | 0.86..0.93 | | | | | | | | | all negative on SEL |

Per-year net R, USDJPY C2: 2018 +24.8, 2019 +12.0, 2020 +13.7, 2021 +51.8, 2022 +38.8 (SEL 141.1R);
2023 +5.2, 2024 +59.2, 2025 +26.7 (VAL 91.0R). Every year positive. Median hold 284 min; exits on SEL: stop
377, trail-stop 202, flat 319, Friday close 92, both-edges-same-bar 8.

**Outcome:** the family does not transfer as a class (indices, EUR/CHF/CAD crosses, AUDNZD, GBPNZD negative;
XAUUSD only positive in 2023-25), but on USDJPY every one of the nine cells is positive on SEL and eight
survive VAL, and the New-York pre-open range (C2/C3) carries roughly **twice the R per business day of the
incumbent Tokyo window at equal density** on both periods. EURUSD carries the same NY anchor (C3) at lower
density and is the only positive anchor on that pair. **Disposition requested: cross-vendor critic (Codex),
then on APPROVE_BUILD a new EA identity cloned from 13213 with the grid/anchor change and a USDJPY Q02 canary
first.** No card, build or factory row exists at the time of sealing.

## Structural cause

USDJPY's intraday information flow is concentrated around the 08:30 New York macro-release / pre-open hour
(US data prints, Treasury-yield repricing, JPY carry-book adjustment into the US session). A completed 2-3 h
range immediately before that anchor bounds the pre-release consolidation; a stop-order breakout of that range
at the anchor converts the release into a directional trade with a stop equal to the range width and no fixed
target — exactly the risk geometry that already qualified on USDJPY at the Tokyo window (QM5_13213, Q02..Q14).
The sweep says the **anchor**, not the mechanism, was the limiting factor. On EURUSD the London-open anchor
(H-V1's premise) and the Tokyo anchor are both negative; only the NY pre-open range is positive, consistent
with the pair's US-session macro sensitivity rather than a London microstructure effect.

## Mechanical spec — frozen, buildable from this section alone

Everything is QM5_13213 (`framework/EAs/QM5_13213_balke-gmt3-range-breakout/`) with three frozen deltas
marked **Δ**. Bounded integer/double inputs only; no ML, no grid, no martingale, no averaging.

- **Clock.** The Darwinex tester/live server clock is the NY-close convention: GMT+2 while US DST is off,
  GMT+3 while it is on — i.e. **server time = America/New_York local time + 7 h, all year**. The economic
  anchor 08:30 America/New_York is therefore the fixed server time **15:30** in every season, and the flat
  time 16:00 New York is **23:00 server**; no EU/US DST divergence window affects this hypothesis (London is
  not involved). *FTMO venue note:* the FTMO server clock follows a different convention; the same
  "New York + offset" mapping must be recomputed there (a governed session-clock helper, not a hard-coded
  15:30), exactly as the kill-switch day-anchor work (ticket d6189118) does for Prague midnight.
- **Δ1 Range grid.** All 60-minute-bar semantics of 13213 (range bars, ATR bars, trail bars) are evaluated
  on a **60-minute grid aligned to :30 server time** (bars 13:30-14:30, 14:30-15:30, …), built from pairs of
  completed M30 bars (`iHigh/iLow/iClose` on PERIOD_M30, shift ≥ 1). Range = the **N completed grid bars
  ending at 15:30 server**: arm **C2: N = 2** (13:30-15:30 server = 06:30-08:30 New York; primary), arm
  **C3: N = 3** (12:30-15:30; second frozen arm). All N bars must exist, else no trade that day. Range high
  `RH`, low `RL`, width `W = RH − RL`.
- **Filter (unchanged).** `ATR(14)` = simple 14-bar average of the true range on the same :30-aligned
  60-minute grid, read on the last completed grid bar before 15:30 (14:30-15:30). Skip the day when
  `W < 0.4 × ATR` or `W > 2.5 × ATR` (`strategy_min_range_atr_mult` / `strategy_max_range_atr_mult`).
- **Orders (unchanged).** At the first tick at or after 15:30 server: buy stop at `RH` with SL `RL`, sell
  stop at `RL` with SL `RH`, no take profit, one-cancels-other (the opposite pending order is removed on the
  tick after a fill). One position per symbol per day. Position size from the framework risk module
  (RISK_FIXED 1000 in backtests, RISK_PERCENT live) on the stop distance `W`.
- **Management (unchanged).** Once open profit ≥ `1.0 × |entry − initial SL|` (`strategy_trail_trigger_r`),
  trail the SL to the lower (long) / higher (short) of the **two most recently completed grid bars** whenever
  that improves it. Exit on an opposite range-side touch (the initial SL) and at the flat time.
- **Δ2 Flat.** First tick at or after **23:00 server** (16:00 New York) closes any open position and cancels
  untriggered pending orders. The framework Friday close (`qm_friday_close_hour_broker = 21`) closes earlier on
  Fridays and blocks later entries — unchanged.
- **Δ3 Inputs.** Minute-resolution anchor inputs replace 13213's integer hours: `strategy_range_end_hour = 15`,
  `strategy_range_end_minute = 30`, `strategy_range_bars = N` (2 or 3), `strategy_exit_hour = 23`,
  `strategy_exit_minute = 0`, `strategy_grid_offset_minutes = 30` (defaults frozen per arm in the set file). No
  other logic changes; `strategy_atr_period = 14`, `strategy_range_scan_bars = 36`, news inputs
  (`QM_NEWS_TEMPORAL_PRE30_POST30`, high impact, DXZ compliance profile) and Friday close as in 13213.
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
  runs real ticks with the modelled spread and ±1 point slippage — part of the +0.02R harness optimism.
- Drawdown: worst calendar-year drawdown USDJPY C2 20.8R (SEL) / 25.0R (VAL), C3 20.7 / 22.2R, EURUSD C3
  24.7 / 15.8R — at 1 %/trade that is 21-25 % of a 100k account; at the FTMO sizing of 0.25 %/trade it is
  5-6 %, inside the 10 % max-loss headroom.

## Multiplicity and calibration (honest statement)

314 cells were searched. 27 pass the selection rule versus 17.4 expected by the per-cell centred block
bootstrap null; 13 survive validation versus 5.5 expected; USDJPY C2 has chance-pass probabilities 0.05 (SEL),
0.27 (VAL), 0.0135 (joint). The per-cell null ignores that the cells of one symbol share days and ranges, so
these sums are **not** a family-level test (a symbol-label permutation test is the stronger statement and has
not been run). The USDJPY claim therefore rests on: the mechanism being tester-qualified on the symbol already;
the control-cell calibration; 9/9 positive SEL cells and 8/9 survivors across three anchors and three range
lengths; and the pre-registration of rule, floor/cap and grid before the run. The EURUSD claim is weaker
(one anchor, PF 1.18, 0.62/bd) and is a secondary slot only.

## Falsification criteria (pre-registered for the Q02 canary and beyond)

Q02 canary USDJPY, tester window 2018-07-02..2022-12-31, RISK_FIXED 1000, real ticks:
1. Arm C2: retire if trades < 800, or net E[R] < +0.08R after costs, or PF < 1.15, or the tester deviates from
   the harness by more than the control cell's calibration (trade count beyond ±15 %, E[R] beyond −0.03R of
   the harness value +0.141 minus the +0.02R optimism, i.e. tester < +0.09R is a calibration alarm, < +0.08R a
   retire).
2. Arm C3: same bars scaled to its harness values (trades < 740, E[R] < +0.07R, PF < 1.15).
3. EURUSD C3: retire the slot if E[R] < +0.04R or PF < 1.10 or trades < 580.
4. Holdout: the 2023-2025 window must retain ≥ 70 % of the selection-period R/bd for each surviving arm
   (harness VAL/SEL ratios: C2 0.97, C3 1.10, EURUSD C3 1.46).
5. Q05 drawdown: retire an arm whose max drawdown exceeds 25R at RISK_FIXED 1000 (the harness worst year is
   20.8-25.0R; the 25R bar is the pre-registered family cap).
6. Tail tests (Q08 dependence panel): daily-P/L correlation with **QM5_13213** (same symbol; expected high
   overlap) — if |r| ≥ 0.5 H-V4 is a REPLACEMENT/upgrade candidate for 13213's window, not an additional
   sleeve, and the book layer must choose one; with 10706 (GBPUSD H1) and 10700 (XAUUSD) |r| > 0.30 or
   lower-decile-day co-occurrence > 2× the independence baseline blocks joint carding, as for the H-CW/H-MR
   panel (`docs/ftmo/FTMO_PORTFOLIO_GAP_CURRENT.md` §3).
7. Q04/Q08 activity criterion: ≥ 10 distinct entry days in every scored year (harness: ≥ 116 per year).
No parameter search is authorised on this artifact; N and the anchor are frozen, Q13 handles optimisation for
survivors.

## Distinct from 13213 / 41484 / 41097 / 41398 / 41405 / 10706 / 10700 / retired 0009-0011

- **QM5_13213 (Balke GMT+3 range breakout, USDJPY H1, qualified through Q14):** identical mechanics; the
  **evidence-based delta** is the anchor and range grid — the 2-3 h range before 15:30 server (08:30 New
  York) on a :30-aligned grid instead of the 03:00-06:00 GMT+3 Tokyo range, flat 23:00 server instead of
  18:00 GMT+3 — measured at +0.141R / +0.120 R/bd versus +0.070R / +0.054 R/bd for the incumbent window in the
  same harness (same symbol, same period, same costs). H-V4 is a candidate upgrade of 13213's window (tail
  test 6), not a second copy.
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

## Source manifest

```qm-source-manifest
# Auto-generated by research_source.seal; do not hand-edit.
research.json:       de6f882c697f6d469801ad53ab79f070771fe762ca31e1dcbf00e973dbc09f2d
lineage.json:        e335665710b9f746a142ca008f681fc980388ba04f4270867aa630c58db4ed25
critic_receipt.json: 529e8710554d85fac62d435853a1c03f01bb3170f7efbc283a06b49d698cec14
sweep_extract.json:  247c595106904451c162f5ed6296abe09790d46f01195d26e8b8bde7a1b6e6ea
```
