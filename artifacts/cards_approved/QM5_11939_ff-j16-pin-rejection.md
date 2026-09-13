---
ea_id: 11939
slug: ff-j16-pin-rejection
g0_status: APPROVED
r1_track_record: forex_factory_legendary
source_id: forex_factory_legendary
r2_mechanical: true
r3_data_available: true
r4_ml_forbidden: true
expected_trades_per_year_per_symbol: 50
target_symbols: ["EURUSD.DWX"]
last_updated: 2026-09-13
g0_approval_reasoning: "Card review 2026-09-13 (Claude): H4 pin-bar reversal, mechanical closed-form (60pct wick/20pct body/level-penetration), limit entry at 50pct retracement, SL 5 pips beyond wick extreme is correctly on the adverse side of entry (not inside), TP fixed 1:2R; charter-compliant FTMO block, single symbol E"
expected_pf: 1.2
expected_dd_pct: 10.0
g0_rejection_reason: "R2 FAIL: the fixed 5-pip stop is internally inconsistent with a D1/H4 pin-bar entry at the 50% wick retracement (stop lands inside the entry), and the timeframe is an unresolved D1-or-H4 choice; closing it needs redesign, not disambiguation."
---

# FF — James16 Pin Bar Rejection (Mechanical Variant)

Source: ForexFactory James16 price-action thread, mechanical variant (lineage `forex_factory_legendary`).
Target symbols: EURUSD.DWX

## Thesis
High-probability reversals from pin bars (long-wick rejection candles) that reject a dynamic S/R level.

## Level Construction (closed bar [1], on H4)
- `HHO = max(Open of the H1 bars over the previous 24 hours)`.
- `LLO = min(Open of the H1 bars over the previous 24 hours)`.

## Pin-Bar Definition (signal candle = last closed H4 bar [1])
- `Range = High[1] - Low[1]` (`Range > 0`).
- `Body = |Close[1] - Open[1]|`.
- **Bearish pin (Short):** upper wick `= High[1] - max(Open[1],Close[1])` is `>= 0.60*Range`; `Body <= 0.20*Range`; and `High[1] > HHO` (wick penetrates resistance).
- **Bullish pin (Long):** lower wick `= min(Open[1],Close[1]) - Low[1]` is `>= 0.60*Range`; `Body <= 0.20*Range`; and `Low[1] < LLO` (wick penetrates support).

## Entry Rules
- Place a **Limit Order at the 50% retracement of the pin wick**:
  - Short limit at `High[1] - 0.5*(High[1] - max(Open[1],Close[1]))`.
  - Long limit at `Low[1] + 0.5*(min(Open[1],Close[1]) - Low[1])`.
- Valid for the next 1 H4 bar; cancel if unfilled. One position per magic.

## Exit & Management
- **Stop Loss:** 5 pips beyond the pin-bar wick extreme (`High[1]` for Shorts, `Low[1]` for Longs).
- **Take Profit:** fixed 1:2 risk-to-reward (`2 * SL_distance`).
- **Position Sizing:** RISK_FIXED (backtest) / RISK_PERCENT (live) tied to the stop distance.

## Respecification Provenance (2026-08-21)
- **Defective passage:** timeframe "Daily (D1) or H4"; S/R "Highest H1 Open and Lowest H1 Open of the previous 24 hours".
- **Correction:** timeframe resolved to a single **H4**; the 24-hour HHO/LLO level made an explicit closed-form window; pin geometry (60% wick / 20% body / level penetration), the 50%-wick limit entry, 5-pip SL and 1:2 TP already mechanical and restated as formulas. No new mechanics invented.

## Edge Lab FTMO Block
- Drawdown: <=5% daily / <=10% total.
- News Blackout: Mandatory.
- Horizon: Swing (H4).
- No Martingale/Grid/Averaging.
- Mechanical/No-ML.
