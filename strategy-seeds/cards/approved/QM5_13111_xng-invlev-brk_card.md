---
ea_id: QM5_13111
slug: xng-invlev-brk
type: strategy
strategy_id: KRISTOUFEK-XNG-INVLEV-2014_S01
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
    location: "Complete paper; especially Data and Results pp. 5-7, Table 4, and Conclusion pp. 7-8; DOI https://doi.org/10.1016/j.eneco.2014.06.009"
    quality_tier: A
    role: primary
  - type: paper
    citation: "Carnero, M. Angeles and Perez, Ana. (2019). Leverage effect in energy futures revisited. Energy Economics 82, 237-252."
    location: "Replication and sensitivity analysis; DOI https://doi.org/10.1016/j.eneco.2017.12.029"
    quality_tier: A
    role: supplement
strategy_type_flags: [vol-regime-gate, atr-hard-stop, time-stop, symmetric-long-short, friday-close-flatten]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
single_symbol_only: true
logical_symbol: QM5_13111_XNG_INVLEV_BRK_H4
period: H4
timeframes: [H4, D1]
expected_trade_frequency: "Once-weekly-capped XNG H4 expansion after a large same-session positive impulse; estimate 8-20 completed trades/year before Q02 validation."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.05
expected_dd_pct: 24.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Positive-return-conditioned, direction-neutral XNG volatility expansion, distinct from the incumbent RSI pullback; Q09 alone may establish orthogonality."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine, cfd_futures_basis]
g0_approval_reasoning: "Mission-directed G0 approval on 2026-07-10: peer-reviewed primary paper plus replication, deterministic positive-impulse H4 range expansion, registered data, and no ML or external runtime feed."
copy_of: strategy-seeds/cards/xng-invlev-brk_card.md
---

# Approved Card Copy

The complete approved card of record is
`strategy-seeds/cards/xng-invlev-brk_card.md`. It defines a once-weekly-capped,
direction-neutral `XNGUSD.DWX` H4 range break after a positive same-session
impulse, with `RISK_FIXED=1000` backtest risk.

## Hypothesis

Natural gas exhibits an inverse return/volatility asymmetry; a large positive
impulse is used only as a short-lived volatility regime, while a later
completed H4 range break discovers direction.

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

See the complete card of record. Expected density is 8-20 trades/year.

## Author Claims

The paper establishes a natural-gas inverse leverage effect, not breakout
returns; the replication limitation is retained.

## Initial Risk Profile

High; Q02 is the only strategy evidence.

## Strategy Allowability Check

- [x] Mechanical, source-backed, no ML/grid/martingale/external feed.

## Framework Alignment

See the complete card of record.

## Risk

No `T_Live`, AutoTrading, deploy manifest, live setfile, or portfolio gate.

