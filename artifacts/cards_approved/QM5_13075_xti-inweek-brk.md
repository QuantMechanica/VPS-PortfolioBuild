---
ea_id: QM5_13075
slug: xti-inweek-brk
source_id: CRABEL-WTI-WEEK-ORB-2026
g0_status: APPROVED
status: APPROVED
pipeline_phase: Q02
target_symbols: [XTIUSD.DWX]
period: D1
expected_trades_per_year_per_symbol: 12
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_pf: 1.10
expected_dd_pct: 18.0
expected_trade_frequency: "D1 WTI inside-week compression breakout; estimate 8-18 trades/year after range-compression, SMA, close-location, spread, and one-entry-per-week filters."
strategy_type_flags: [narrow-range-breakout, trend-filter-ma, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
single_symbol_only: true
logical_symbol: QM5_13075_XTI_INWEEK_BRK_D1
source_citation: "Crabel, Toby. Day Trading with Short-Term Price Patterns and Opening Range Breakout. Traders Press, 1990."
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-09: R1 PASS Crabel short-term price-pattern/opening-range breakout source packet; R2 PASS deterministic D1 WTI inside-week compression breakout with ATR/SMA/close-location confirmation, ATR stop/target, failed-breakout and max-hold exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
created: 2026-07-09
---

# QM5_13075 XTI Inside-Week Compression Breakout

Approved structural card for a single-symbol `XTIUSD.DWX` D1 WTI sleeve.

Source lineage:

- Crabel, Toby. *Day Trading with Short-Term Price Patterns and Opening Range
  Breakout*. Traders Press, 1990.

Mechanization: identify a completed broker week whose full range is inside the
prior week, then trade a next-week D1 close outside that inside-week high/low.
Entries require ATR range quality, SMA trend confirmation, close-location
confirmation, one entry per broker week, one magic slot, and a fixed-risk
backtest setfile. Exits use ATR hard stop/target, failed-breakout close, SMA
failure close, max hold, and framework Friday close. No external runtime data,
ML, grid, martingale, live manifest, portfolio gate, or AutoTrading changes.

Build/Q02 evidence:

- Q01 build validation: `artifacts/qm5_13075_build_result.json`.
- Q02 baseline screening: `artifacts/qm5_13075_q02_enqueue_20260709.json`.
