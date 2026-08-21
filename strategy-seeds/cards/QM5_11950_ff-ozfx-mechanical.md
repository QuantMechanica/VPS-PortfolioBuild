---
ea_id: 11950
slug: ff-ozfx-mechanical
g0_status: APPROVED
r1_track_record: forex_factory_legendary
source_id: forex_factory_legendary
r2_mechanical: true
r3_data_available: true
r4_ml_forbidden: true
expected_trades_per_year_per_symbol: 50
target_symbols: ["EURUSD.DWX"]
last_updated: 2026-08-21
g0_approval_reasoning: "R1 traceable (FF Ozfx); R2 now closed-form (AC zero-cross + Stoch(5,3,3) cross entries, single-position staged 20% partial closes replacing 5-lot to honor 1-pos-per-magic, 100-pip SL) via respecification; R3 EURUSD.DWX governed; R4 mechanical, no ML."
expected_pf: 1.2
expected_dd_pct: 14.0
---

# FF — Ozfx Mechanical System (Daily)

Source: ForexFactory legendary "Ozfx" daily trend system (lineage `forex_factory_legendary`).
Target symbols: EURUSD.DWX

## Thesis
Daily trend entries on Accelerator + Stochastic alignment, managed with a staged scale-out.

## Indicator Definitions (closed bar [1], D1)
- `AC = Accelerator Oscillator` (Williams AC).
- `Stoch = Stochastic(5,3,3)` main (`%K`) and signal (`%D`).

## Entry Rules
- **Buy:** `AC[1] > 0` AND `AC[2] <= 0` (AC crosses into positive territory) AND `%K[1] > %D[1]` AND `%K[2] <= %D[2]` (Stoch bullish cross).
- **Sell:** `AC[1] < 0` AND `AC[2] >= 0` AND `%K[1] < %D[1]` AND `%K[2] >= %D[2]`.
- One position per magic.

## Exit & Management (single position, staged partial closes)
- **Initial size** opened at full risk; **Stop Loss:** fixed 100 pips for the whole position.
- **Scale-out (partial closes of the ONE position, not separate orders):**
  - At +50 pips: close 20% of the position and move the stop to break-even.
  - At +100 pips: close 20%.
  - At +150 pips: close 20%.
  - At +200 pips: close 20%.
  - Final 20% (runner): close on the opposite entry signal.
- **Position Sizing:** RISK_FIXED (backtest) / RISK_PERCENT (live) tied to the 100-pip stop.

## Respecification Provenance (2026-08-21)
- **Defective passage:** "The 5-Lot Rule ... Move remaining 4 lots to Break Even" — implied 5 separate positions, which would breach 1-position-per-magic.
- **Correction:** the "5-lot" scale-out is re-expressed as **one position with four 20% partial closes** (at +50/+100/+150/+200 pips) plus a 20% runner, which is faithful to the source's scale-out intent AND compatible with HR14 1-position-per-magic (partial closes of a single position). The AC-zero-cross and Stoch(5,3,3)-cross entries are given explicit closed-form conditions; 100-pip SL and sizing pinned. No new mechanics invented.

## Edge Lab FTMO Block
- Drawdown: <=5% daily / <=10% total.
- News Blackout: Mandatory.
- Horizon: Swing (Daily hold).
- No Martingale/Grid/Averaging.
- Mechanical/No-ML.
