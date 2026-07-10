---
ea_id: QM5_13112
slug: xti-levbrk
type: strategy
strategy_id: KRISTOUFEK-XTI-LEV-2014_S02
source_id: KRISTOUFEK-ENERGY-LEV-2014
status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
g0_status: APPROVED
source_citation: "Kristoufek, Ladislav. Leverage effect in energy futures. Energy Economics 45 (2014), 1-9. DOI 10.1016/j.eneco.2014.06.009."
source_citations:
  - type: paper
    citation: "Kristoufek, Ladislav. (2014). Leverage effect in energy futures. Energy Economics 45, 1-9."
    location: "Complete paper; especially Data and Results pp. 6-7, Figure 3, and Conclusion pp. 7-8; DOI https://doi.org/10.1016/j.eneco.2014.06.009"
    quality_tier: A
    role: primary
strategy_type_flags: [vol-regime-gate, atr-hard-stop, time-stop, friday-close-flatten]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13112_XTI_LEVBRK_H4
period: H4
timeframes: [H4, D1]
expected_trade_frequency: "Once-weekly-capped WTI H4 downside continuation after a large completed negative D1 impulse; estimate 6-14 completed trades/year before Q02 validation."
expected_trades_per_year_per_symbol: 9
expected_pf: 1.05
expected_dd_pct: 22.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Negative-shock WTI downside-trend exposure, distinct from the incumbent commodity RSI pullback and ordinary symmetric WTI momentum; Q09 alone may establish orthogonality."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine, cfd_futures_basis]
g0_approval_reasoning: "Mission-directed G0 approval on 2026-07-10: peer-reviewed primary paper, deterministic negative-D1-impulse H4 downside continuation, registered data, and no ML or external runtime feed."
copy_of: strategy-seeds/cards/xti-levbrk_card.md
---

# QM5_13112 Approved Build Input

Canonical card: `strategy-seeds/cards/xti-levbrk_card.md`.

This approved input represents an expected 6-14 trades/year from a
once-weekly-capped, short-only `XTIUSD.DWX` H4 continuation below a large
completed negative D1 impulse. Backtests use `RISK_FIXED=1000` and
`RISK_PERCENT=0`.

## Rules

See the canonical card.

## 4. Entry Rules

See the canonical card.

## 5. Exit Rules

See the canonical card.

## 6. Filters (No-Trade Module)

See the canonical card.

## 7. Trade Management Rules

See the canonical card.

## Parameters To Test

See the canonical card. Expected density is 6-14 trades/year.

## Author Claims

The paper establishes standard crude-oil leverage, not breakout returns.

## Initial Risk Profile

High; Q02 is the first strategy-evidence gate.

## Strategy Allowability Check

- [x] Structural, mechanical, source-backed, no ML or external runtime feed.

## Framework Alignment

See the canonical card.

## Risk

No live or portfolio mutation is authorized.
