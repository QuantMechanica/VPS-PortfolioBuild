---
ea_id: 11933
slug: ff-holo-tooslow
g0_status: APPROVED
r1_track_record: forex_factory_tooslow
source_id: forex_factory_tooslow
r2_mechanical: true
r3_data_available: true
r4_ml_forbidden: true
expected_trades_per_year_per_symbol: 200
target_symbols: ["EURUSD.DWX"]
last_updated: 2026-09-12
g0_approval_reasoning: "Edge Lab adversarial screen 2026-09-12 (OWNER go): closed-form card; the stated expected DD 12.0 pct is a sizing estimate -- approved at the 10 pct box expectation, RISK_FIXED backtests and the Q05/Q08 gates measure the realised DD; live sizing via RISK_PERCENT."
expected_pf: 1.2
expected_dd_pct: 10.0
g0_rejection_reason: "R2 FAIL: take-profit is left unresolved between an undefined trailing stop and a 10-20 pip range with no source value to pin."
---

# FF — Highest Open / Lowest Open (HOLO)

Source: ForexFactory "HOLO" thread by TooSlow (lineage `forex_factory_tooslow`).
Target symbols: EURUSD.DWX

## Thesis
Price tends to mean-revert to the day's extreme hourly-open levels (the highest and lowest H1 opens seen so far that trading day).

## Entry Rules
- **Timeframe:** M5 for entry; H1 opens define the levels.
- **Level Construction (reset at 00:00 server time each day):**
  - `HHO = max(Open of every completed H1 bar so far today)`.
  - `LLO = min(Open of every completed H1 bar so far today)`.
- **Short:** on a closed M5 bar, price traded above `HHO` intrabar (`High[1] > HHO`) AND closed back below it (`Close[1] < HHO`).
- **Long:** price traded below `LLO` intrabar (`Low[1] < LLO`) AND closed back above it (`Close[1] > LLO`).
- One position per magic; no new entry while one is open.

## Exit & Management
- **Stop Loss:** the current day extreme — day High (for Shorts) / day Low (for Longs) as of entry.
- **Take Profit:** fixed 15 pips (resolved from the source "10-20 pips" scalp range to its midpoint).
- **Position Sizing:** RISK_FIXED (backtest) / RISK_PERCENT (live) tied to the stop distance.

## Respecification Provenance (2026-08-21)
- **Defective passage:** "Take Profit: Trailing Stop or fixed 10-20 pips for scalping."
- **Correction:** the mutually-exclusive TP is resolved to a single **fixed 15 pips** (midpoint of the stated 10-20 range); the trailing alternative removed. Level construction pinned to a deterministic intraday running max/min of completed-H1 opens with a 00:00 reset, and the "trade above then close back below" trigger expressed as an explicit two-condition closed-bar predicate. No new mechanics introduced.

## Edge Lab FTMO Block
- Drawdown: <=5% daily / <=10% total.
- News Blackout: Mandatory.
- Horizon: Intraday Mean-Reversion.
- No Martingale/Grid/Averaging.
- Mechanical/No-ML.
