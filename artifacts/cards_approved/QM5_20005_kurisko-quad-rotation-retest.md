---
strategy_id: KURISKO-QUADROT-2026
source_id: OWNER-DIRECTIVE-2026-07-17_KURISKO-QUADROT
ea_id: QM5_20005
slug: kurisko-quad-rotation-retest
type: strategy
status: APPROVED
g0_status: APPROVED
source_citation: "John Kurisko (DayTradingRadio), 'Quad Rotation' four-stochastic day-trading methodology, publicly taught since ~2010s. Mechanization spec provided verbatim by OWNER 2026-07-17 (session directive): 4x stochastic confluence + horizontal market-structure breakout/retest replacing Kurisko's discretionary diagonal trendlines."
sources:
  - "OWNER session directive 2026-07-17 (verbatim mechanization spec)"
concepts:
  - quad-stochastic-oversold-overbought-confluence
  - consolidation-range-breakout-retest
  - limit-order-at-broken-structure
  - fast-oscillator-exit
indicators:
  - stochastic-9-3-3
  - stochastic-14-3-3
  - stochastic-44-3-3
  - stochastic-60-10-3
  - atr-range-scaling
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX]
primary_target_symbols: [SP500.DWX]
logical_symbol: QM5_20005_SP500_QUAD_ROTATION_M5
period: M5
timeframes: [M5]
expected_trade_frequency: "Quad-zone coincidence at a structural retest gates hard; at most one position at a time, one armed direction (no OCO). Declared 40 trades per year per symbol."
expected_trades_per_year_per_symbol: 40
expected_pf: 1.15
expected_dd_pct: 15.0
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
risk_class: medium
ml_required: false
single_symbol_only: true
priority_track: true
last_updated: 2026-07-17
neighborhood_note: "Stochastic periods (9/14/44/60, 3/10 smoothing) and range_bars are discrete lattice params — perturb +/-1 lattice step at Q08, never +/-pct (Q08_NEIGHBORHOOD_PARAM_TYPE_AWARE_SPEC_2026-07-17). Zone thresholds 20/80 and ATR mults are level params, +/-pct valid."
g0_approval_reasoning: "OWNER direct mechanization mandate 2026-07-17, G0 (Claude): R1 Kurisko/DayTradingRadio quad-rotation methodology publicly taught for years, no audited numbers published - pipeline judges (13033/Mulham precedent). R2 mechanical after in-card codifications (Donchian range def, breakout buffer, retest-"
---

# QM5_20005 Kurisko Quad Rotation — Structure Retest (M5, SP500 + NDX)

## Source

- Methodology: John Kurisko (DayTradingRadio, publicly taught since the
  2010s; URL https://daytradingradio.com — "Quad Rotation"), four stochastic
  oscillators of increasing period; a tradeable rotation exists when all four
  are simultaneously in the oversold/overbought zone at a structural level.
  Kurisko trades it discretionarily on US equities/indices intraday with
  hand-drawn trendlines. No audited track record published — pipeline judges
  (13033/Mulham precedent).
- Mechanization: OWNER directive 2026-07-17 (verbatim spec in session).
  OWNER's explicit design decision: replace the error-prone diagonal
  trendlines with horizontal market-structure logic (consolidation range →
  breakout → retest of the broken boundary). All numeric codifications below
  are deliberate QM decisions, flagged inline.

## Thesis

After a consolidation range breaks, the broken boundary acts as institutional
re-entry liquidity. A pullback (retest) into that boundary that coincides
with all four stochastics — fast (9,3,3) through slow (60,10,3) — pinned in
the opposite-side zone marks a multi-timescale momentum exhaustion into
structure: the pullback is stretched on every measured timescale exactly at
the level where breakout traders defend. Entry via resting limit order at the
boundary harvests the retest; the fast stochastic re-rotating through the
opposite zone signals the swing is spent.

## Market universe and timeframe

- Symbols: SP500.DWX (primary; Kurisko's home market is S&P/US equities),
  NDX.DWX, WS30.DWX (US large-cap P2 saturation basket). Per-symbol
  instances, single_symbol_only.
- Entry timeframe M5 (OWNER spec: M1–M5 band; M5 chosen — index commission
  ~$4.4/trade is benign at this cadence, M1 real-tick full-history cost and
  noise are not; QM codification).
- All indicator reads and state transitions on closed M5 bars.

## Entry

Closed bars only. State machine per symbol:

1. **Range identification (SCAN)** — QM codification (source leaves the
   range definition discretionary): a consolidation exists when the Donchian
   box of the last `range_bars` (default 36) closed M5 bars has height
   <= `range_max_atr_mult` (default 3.0) x ATR(14, M5). Record range_high /
   range_low. Box must also be >= `range_min_atr_mult` (default 0.8) x ATR
   so degenerate flat boxes in dead sessions don't arm hair-trigger levels.
2. **Breakout (ARMED)**: a closed M5 bar CLOSES beyond the boundary by
   `breakout_buffer_atr` (default 0.10) x ATR(14). Close above range_high →
   long side armed; below range_low → short side armed. One direction only —
   explicitly NO OCO pairing (OWNER spec).
3. **Retest wait (RETEST)**: after an upward breakout, on each closed bar
   while price holds above the boundary:
   - Quad Rotation check: MAIN (%K slowed) line of ALL FOUR stochastics
     (9,3,3 / 14,3,3 / 44,3,3 / 60,10,3) < `zone_oversold` (default 20).
   - While the quad condition is TRUE and no position is open: maintain a
     BUY LIMIT at range_high (the broken boundary). While FALSE: remove our
     pending order. The limit only rests at the level when the confluence
     holds, so a boundary touch without quad confluence cannot fill —
     mechanizes "Entry nur bei exakter Konvergenz" (OWNER spec).
   - Short is the mirror: downward breakout, retest of range_low from below,
     all four stochastics > `zone_overbought` (default 80), SELL LIMIT at
     range_low.
4. **Breakout invalidation** — QM codification: a closed bar back inside the
   range beyond its midpoint, or `retest_window_bars` (default 72 = 6h) with
   no fill, cancels the armed state and returns to SCAN. New ranges are only
   scanned while flat and unarmed.

## Exit

- **Primary (OWNER spec, strict)**: long closes at market when the fastest
  stochastic (9,3,3 MAIN) crosses ABOVE `zone_overbought` (80) on a closed
  bar; short closes when it crosses BELOW `zone_oversold` (20).
- **Fail-safe (OWNER spec)**: hard SL and TP on every order. Inputs
  `sl_points` / `tp_points` (points); at the default 0 they derive
  dynamically at order placement: SL = 2.0 x ATR(14,M5), TP = 4.0 x ATR
  (QM codification — fixed-point defaults cannot be sane across SP500 vs
  NDX scales; per-symbol setfiles may pin explicit points).
- Framework Friday close + news handling on top.

## Risk

- RISK_FIXED backtest / RISK_PERCENT live. Single position, one pending max,
  hard SL always present. Index commission class (DL-072) — benign.

## Filters

- News: framework two-axis default (PRE30_POST30 + DXZ).
- No entries while a position or our pending exists; no range re-scan while
  armed (prevents boundary drift under an active setup).

## Falsification

- Q02 gross PF < 1.20 at card floor kills the symbol; both symbols failing
  closes the quad-rotation family (no re-windowing, no threshold tuning —
  defaults + Q03 grid only).
- Frequency floor: >= 5 trades/yr x window years (economics floor,
  OPERATING_RULES 2026-07-03). The quad confluence is deliberately strict; if
  it fires < floor the mechanization is dead as specified, not loosened.

## Q08–Q11 risks

- Four correlated oscillators = one effective DoF more than it looks;
  PBO/DSR suspicion at Q08 if only one symbol survives.
- Oscillator-confluence + level-retest families have no QM survivor yet
  (9999 dual-stoch died pre-Q04); treat any Q02 pass as fragile until Q04.
- Regime: melt-up tape starves the short side; lumpy annual distribution
  expected for longs-at-support in bull years.

## Implementation notes

- V5 framework skeleton; closed-bar M5; stochastics via QM_Stoch_K (pooled
  handles, MAIN line, STO_LOWHIGH/SMA defaults).
- State machine: SCAN -> ARMED(dir) -> RETEST(dir, limit maintained under
  quad condition) -> IN_TRADE -> DONE/INVALIDATED.
- Limit order via QM_TM_OpenPosition(QM_BUY_LIMIT/QM_SELL_LIMIT); removal
  via QM_TM_RemovePendingOrder. NO paired orders (no OCO — OWNER spec).
- Inputs: stoch1=9/3/3, stoch2=14/3/3, stoch3=44/3/3, stoch4=60/10/3 (all
  flexible inputs per OWNER spec), zone_oversold=20, zone_overbought=80,
  range_bars=36, range_max_atr_mult=3.0, range_min_atr_mult=0.8,
  breakout_buffer_atr=0.10, retest_window_bars=72, sl_points=0, tp_points=0,
  sl_atr_mult=2.0, tp_atr_mult=4.0.
- Set QM_EntryRequest.symbol_slot explicitly on every populate (BUILD rule,
  news-filter-index-defect lesson 2026-07-05).
