---
ea_id: QM5_13110
slug: xng-svol-brk
type: strategy
strategy_id: SUENAGA-XNG-SEASVOL-2008_S01
source_id: SUENAGA-XNG-SEASVOL-2008
status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
g0_status: APPROVED
source_citation: "Suenaga, H., Smith, A., and Williams, J. C. Volatility Dynamics of NYMEX Natural Gas Futures Prices. Journal of Futures Markets 28(5), 2008, 438-463. DOI 10.1002/fut.20317."
source_citations:
  - type: paper
    citation: "Suenaga, Hiroaki; Smith, Aaron; and Williams, Jeffrey C. (2008). Volatility Dynamics of NYMEX Natural Gas Futures Prices. Journal of Futures Markets 28(5), 438-463."
    location: "Full paper; especially pp. 438-442, 447-452, and 461-462; DOI https://doi.org/10.1002/fut.20317"
    quality_tier: A
    role: primary
strategy_type_flags: [n-period-max-continuation, vol-regime-gate, atr-hard-stop, time-stop, symmetric-long-short, friday-close-flatten]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
single_symbol_only: true
logical_symbol: QM5_13110_XNG_SVOL_BRK_H4
period: H4
timeframes: [H4, D1]
expected_trade_frequency: "Once-weekly eligible H4 natural-gas range expansion during the source volatility windows; estimate 10-24 completed trades/year before Q02 validation."
expected_trades_per_year_per_symbol: 16
expected_pf: 1.05
expected_dd_pct: 24.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Source-seasonal symmetric XNG volatility expansion, distinct from the incumbent RSI pullback; Q09 alone may establish orthogonality."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine, cfd_futures_basis]
g0_approval_reasoning: "Mission-directed G0 approval on 2026-07-10: peer-reviewed primary source, deterministic source-window H4/D1 range expansion, registered data, and no ML or external runtime feed."
copy_of: strategy-seeds/cards/xng-svol-brk_card.md
---

# Approved Card Copy

The complete approved card of record is
`strategy-seeds/cards/xng-svol-brk_card.md`. It defines a once-weekly,
symmetric `XNGUSD.DWX` H4 close-confirmed breakout of the previous D1 range in
the source volatility windows, with `RISK_FIXED=1000` backtest risk.

## Rules

See the complete card of record.

## 4. Entry Rules

See the complete card of record.

## 5. Exit Rules

See the complete card of record.

## 6. Filters (No-Trade Module)

See the complete card of record.

## 7. Trade Management Rules

See the complete card of record.

## Parameters To Test

See the complete card of record. Expected density is 10-24 trades/year.

## Author Claims

The paper establishes seasonal natural-gas volatility, not breakout returns.

## Initial Risk Profile

High; Q02 is the only strategy evidence.

## Strategy Allowability Check

- [x] Mechanical, source-backed, no ML/grid/martingale/external feed.

## Framework Alignment

See the complete card of record.

## Risk

No `T_Live`, AutoTrading, deploy manifest, live setfile, or portfolio gate.

