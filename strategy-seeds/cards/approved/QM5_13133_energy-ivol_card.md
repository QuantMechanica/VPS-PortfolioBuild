---
ea_id: QM5_13133
slug: energy-ivol
type: strategy
strategy_id: FUERTES-MOMIVOL-2015_XTI_XNG_S02
source_id: FUERTES-MOMIVOL-2015
status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
g0_status: APPROVED
source_citations:
  - type: peer_reviewed_paper
    citation: "Fuertes, Ana-Maria; Miffre, Joelle; and Fernandez-Perez, Adrian (2015). Commodity Strategies Based on Momentum, Term Structure and Idiosyncratic Volatility. Journal of Futures Markets 35(3), 274-297."
    location: "Complete open accepted manuscript; equation (1), Sections 3.1-3.2, Tables 1-3 and 6, Appendices A-B; DOI https://doi.org/10.1002/fut.21656; https://openaccess.city.ac.uk/id/eprint/6418/1/JFM_SSRN_13Jan2014.pdf"
    quality_tier: A
    role: primary
strategy_type_flags: [symmetric-long-short, atr-hard-stop, time-stop, signal-reversal-exit]
markets: [commodities, energy]
timeframes: [D1]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
factor_symbols: [XTIUSD.DWX, XNGUSD.DWX, XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_13133_XTI_XNG_IVOL_D1
period: D1
expected_pf: 1.03
expected_dd_pct: 25.0
expected_trade_frequency: "Approximately 12 completed monthly packages/year after warm-up."
expected_trades_per_year_per_symbol: 12
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
review_focus: "Pure residual-volatility XTI/XNG selection with equal-notional paired sizing; Q09 alone may establish realized orthogonality."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
pipeline_phase: Q02
g0_approval_reasoning: "OWNER mission-directed G0 approval 2026-07-11: peer-reviewed full source, deterministic monthly pure-IVol rank, registered native inputs, no prohibited runtime component, and CLEAN manual dedup before allocation."
copy_of: strategy-seeds/cards/energy-ivol_card.md
---

# Energy Pure IVol Spread

## Hypothesis

Each month, estimate XTI and XNG residual volatility against an equal-weight
XTI/XNG/XAU/XAG commodity factor. Buy the lower-IVol energy leg, short the
higher-IVol leg, and size the package toward equal dollar notional.

## Source

Fuertes, Miffre, and Fernandez-Perez (2015), *Journal of Futures Markets*
35(3), 274-297, DOI `10.1002/fut.21656`. The complete card of record is
`strategy-seeds/cards/energy-ivol_card.md`.

## Rules

Use the source's standalone monthly IVol sort: buy the lower OLS residual-
volatility energy leg, sell the higher one, and hold one broker month. The
factor, estimator, direction, paired carrier, and equal-notional target are
locked.

## 4. Entry Rules

- Use 252 completed D1 log returns and two OLS regressions.
- Trade XTI slot 0 and XNG slot 1; XAU/XAG are read-only factor members.
- Long lower residual volatility and short higher residual volatility.
- Target equal dollar notional, reject more than 20% rounding mismatch, and
  attach frozen ATR(20) times 3.0 hard stops.
- Allow at most one package attempt per broker month, including after restart.

## 5. Exit Rules

- Reset at the next broker month, after 35 days, or on invalid composition.
- Flatten an orphan immediately.
- Friday close is disabled only for the source's monthly hold.

## 6. Filters (No-Trade Module)

Fail closed on wrong host/slot, invalid parameters, incomplete synchronized
history, zero factor variance, invalid OLS residuals, spread/ATR/contract
metadata, notional mismatch, or current-month attempt history.

## 7. Trade Management Rules

Exactly two opposite energy legs; no momentum gate, TP, trail, break-even,
partial close, grid, martingale, pyramid, external data, or ML.

## Parameters To Test

The 252-D1 source window is the Q02 baseline; 21, 63, and 126 D1 are declared
source alternatives. ATR, spread, and mismatch ranges are in the complete card.

## Author Claims

The source explicitly specifies buying the lowest-IVol commodities and selling
the highest-IVol commodities. No source statistic is imported.

## Strategy Allowability Check

- [x] Peer-reviewed, mechanical, native-data, low-frequency, and non-ML.
- [x] Non-duplicate versus momentum-IVol, total-volatility, ratio/spread,
  trend, carry, calendar, higher-moment, BAB, and cumulative-RSI2 logic.

## Framework Alignment

- no_trade: host, estimator, history, spread, ATR, notional, and attempt guards.
- trade_entry: monthly pure-IVol rank and paired equal-notional orders.
- trade_management: monthly/stale exits and orphan/composition cleanup.
- trade_close: broker hard stops plus framework close helper.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one logical basket setfile.
No live, deploy, portfolio-gate, `T_Live`, or AutoTrading mutation is authorized.
