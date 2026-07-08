---
ea_id: QM5_11911
slug: larry-williams-smash-day-d1
source_id: c2f8e3d5-4a91-5b67-9c48-a3b7d6e4f2c9
source_citation: "Larry Williams, 'Inner Circle Workshop Trading Method' (~1998 seminar manual), 'THE FAILURE DAY FAMILY' section. Williams: 1987 World Cup Trading Championship all-time-record winner."
title: "Larry Williams Smash Day Reversal D1"
edge_type: intra_bar_exhaustion_reversal
period: D1
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCAD.DWX, USDCHF.DWX, AUDUSD.DWX, NZDUSD.DWX, EURJPY.DWX, GBPJPY.DWX, AUDJPY.DWX]
risk_mode_backtest: RISK_FIXED
risk_fixed: 1000
risk_mode_live: RISK_PERCENT
risk_percent: 0.5
expected_trades_per_year_per_symbol: 30
status: cards_ready
r1_verdict: PASS
r1_reasoning: "Single source_id (sister card to QM5_11910 from same Williams seminar source); one source per card satisfied."
r1_note: "R2/R4 — Larry Williams 1987 World Cup Trading Champ"
r2_verdict: PASS
r2_reasoning: "Bullish/bearish Smash Day conditions with ATR formalization, stop-order entry, prior-bar SL, 2:1 TP, and 10-bar timeout are mechanically implementable."
r3_verdict: PASS
r3_reasoning: "DWX forex majors directly testable on MT5."
r4_verdict: PASS
r4_reasoning: "Bar-structure price rules only; no ML, no PnL-adaptive logic, one position per symbol."
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
strategy_params:
  timeframe: D1
  trend_direction_bars: [higher_high, higher_low]
  intra_bar_close_below_open_for_bullish_smash: true
  intra_bar_close_above_open_for_bearish_smash: true
  close_open_distance_atr_mult: 0.5
  entry_method: stop_order_at_smash_bar_extreme
  order_validity_bars: 5
g0_status: APPROVED
g0_approval_reasoning: "R1 single source_id/citation; R2 mechanical D1 Smash Day stop-entry/reversal rules with exits, cadence plausible >2/y/sym despite frontmatter 30 needing Q02 confirmation; R3 DWX FX majors testable; R4 deterministic no ML/grid/multi-position."
last_updated: 2026-05-25
---

# QM5_11911 — Larry Williams Smash Day Reversal (D1)

## Setup

Single-bar reversal pattern. A daily bar that prints the structure of
trend continuation (higher high, higher low, higher close than the
prior bar — apparent strength) but reverses INTRA-BAR (closes
substantially below its own open — internal weakness). The next-day
break of the Smash Day's high triggers a long entry; the contradiction
between the bar's external strength and internal weakness suggests
buyers and sellers are unevenly trapped.

The mirror Bearish Smash: lower high + lower low + lower close, but
close substantially above open. Next-day break of the Smash Day's low
triggers a short entry.

Distinct from QM5_11904 (Failure Test 2B) which requires a swing-pivot
breach. The Smash Day is structural-vs-internal and doesn't reference
prior pivots.

## Pattern Definitions

For a closed D1 bar at index t:

- **Bullish Smash Day**:
  - `high[t] > high[t-1]` AND `low[t] > low[t-1]` AND `close[t] > close[t-1]`
  - AND `open[t] - close[t] > 0.5 × ATR(14)` (close is substantially
    below open — Williams' "substantially" formalized as 0.5 × ATR).
- **Bearish Smash Day**:
  - `high[t] < high[t-1]` AND `low[t] < low[t-1]` AND `close[t] < close[t-1]`
  - AND `close[t] - open[t] > 0.5 × ATR(14)` (close substantially above
    open).

## Entry Rules

Detected at the close of each D1 bar:

1. **Bullish Smash setup**: Pattern conditions met on bar t.
2. **Long entry trigger**: Place buy-stop pending order at
   `high[t] + 1 pip`. Valid for the next 5 D1 bars.
3. **Bearish Smash setup (mirror)**: Sell-stop at `low[t] - 1 pip`,
   valid 5 D1 bars.
4. **Order cancellation**: If the order is not triggered within 5 bars,
   cancel.
5. **One position per symbol** at a time.

## Exit Rules

- **Initial stop loss (long)**: at the LOW of the Smash Day minus 5
  pips (the Smash Day's low is the structural invalidation level).
- **Initial stop loss (short)**: at the HIGH of the Smash Day plus 5
  pips.
- **Take profit**: 2.0 × initial pip-risk in trade direction (2:1 R:R).
- **Hard timeout**: close at D1 bar 10 (~2 weeks) if no other exit
  fires. Williams describes the pattern as catching short-term reversals.
- **Risk**: backtest RISK_FIXED `risk_fixed = 1000`; live RISK_PERCENT
  `risk_percent = 0.5`.

## Universe

target_symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCAD.DWX, USDCHF.DWX,
AUDUSD.DWX, NZDUSD.DWX, EURJPY.DWX, GBPJPY.DWX, AUDJPY.DWX

D1 forex majors. Williams designed for futures but the pattern is a
universal price-action structure applicable to any liquid market.

## Source

source_citation: Larry Williams, "Inner Circle Workshop Trading
Method," seminar manual (~1998), section "THE FAILURE DAY FAMILY,"
SMASH DAY subsection. Williams is 1987 World Cup Trading Championship
all-time-record winner ($10K → $1.147M) and Wiley-published author. The Smash Day is a
trade-school formalization of bar internals — extending the bar's
shape (relative to prior bar) into the bar's OPEN vs CLOSE relationship
(the "external" trend signal vs the "internal" exhaustion signal).
