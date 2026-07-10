---
ea_id: QM5_13113
slug: energy-mom-ivol
type: strategy
strategy_id: FUERTES-MOMIVOL-2015_XTI_XNG_S01
source_id: FUERTES-MOMIVOL-2015
status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
g0_status: APPROVED
source_citations:
  - type: paper
    citation: "Fuertes, Ana-Maria; Miffre, Joelle; and Fernandez-Perez, Adrian (2015). Commodity Strategies Based on Momentum, Term Structure and Idiosyncratic Volatility. Journal of Futures Markets 35(3), 274-297."
    location: "Complete open accepted manuscript; Sections 3.1-4.1 and 5.1, Table 7 p.34, Appendix A p.40; DOI https://doi.org/10.1002/fut.21656; https://openaccess.city.ac.uk/id/eprint/6418/1/JFM_SSRN_13Jan2014.pdf"
    quality_tier: A
    role: primary
strategy_type_flags: [market-neutral-basket, momentum, vol-regime-gate, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy]
timeframes: [D1]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
factor_symbols: [XTIUSD.DWX, XNGUSD.DWX, XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_13113_ENERGY_MOM_IVOL_D1
period: D1
expected_pf: 1.08
expected_dd_pct: 18.0
expected_trade_frequency: "6-10 completed monthly packages/year before Q02."
expected_trades_per_year_per_symbol: 8
risk_class: medium-high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
review_focus: "Market-neutral XTI/XNG momentum-plus-IVol selection, distinct from outright commodity RSI and energy trend signals; Q09 alone may establish realized orthogonality."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
pipeline_phase: Q02
g0_approval_reasoning: "OWNER mission-directed G0 approval 2026-07-10: peer-reviewed open source, deterministic monthly momentum/IVol double screen, registered DWX inputs, no external runtime feed or prohibited model, and CLEAN repository dedup before allocation."
copy_of: strategy-seeds/cards/energy-mom-ivol_card.md
---

# Energy Momentum–IVol Double Screen

## Hypothesis

Commodity momentum and residual volatility carry distinct information. The
two-leg carrier buys the XTI/XNG momentum winner only when it is also the
lower-IVol energy leg, shorts the other, and stays flat on rank conflict.

## Source

Fuertes, Miffre, and Fernandez-Perez (2015), *Journal of Futures Markets*
35(3), 274-297, DOI `10.1002/fut.21656`. The full card of record is
`strategy-seeds/cards/energy-mom-ivol_card.md`.

## Rules

At the first D1 bar of each month, compute 63-D1 momentum for XTI and XNG. Fit
each energy return series on an equal-weight XTI/XNG/XAU/XAG return factor and
rank the OLS residual standard deviations. Open a two-leg package only if the
momentum winner is also the lower-IVol leg.

## 4. Entry Rules

- Host `XTIUSD.DWX` D1, magic slot 0; XNG is traded at slot 1.
- XAU and XAG are read-only factor members.
- Open equal fixed-risk legs only on monthly rank agreement.
- Any failed second leg triggers immediate orphan flattening.

## 5. Exit Rules

- Reset both legs at the next monthly rebalance.
- Flatten after 35 days or whenever the package is broken.
- Each leg has an ATR(20) times 3.0 hard stop.
- Friday close is card-disabled to preserve the source's one-month hold.

## 6. Filters (No-Trade Module)

Fail closed on wrong host/slot, invalid parameters, missing four-symbol history,
zero factor variance, invalid residuals, bad ATR/lot metadata, or excess spread.

## 7. Trade Management Rules

Two traded legs only; no pyramid, grid, martingale, partial close, trailing
stop, break-even move, live input, or discretionary override.

## Parameters To Test

The Q02 baseline is the paper's three-month window (63 D1 bars). Source-declared
alternatives are 21, 126, and 252 D1 bars. ATR and spread-cap ranges are defined
in the complete card.

## Author Claims

The source reports distinct momentum and IVol information and stronger combined
long-short portfolios in its futures sample. It does not validate this two-leg
DWX carrier.

## Initial Risk Profile

Medium-high translation and basket-execution risk. Backtests use
`RISK_FIXED=1000`, split equally across the legs.

## Strategy Allowability Check

- [x] Structural, mechanical, source-backed, and low frequency.
- [x] No prohibited model, external runtime feed, grid, or martingale.
- [x] Non-duplicate: residual-volatility agreement is mandatory, unlike the
  existing XTI/XNG momentum, ratio, spread, compression, and carry EAs.

## Framework Alignment

- no_trade: host, parameter, history, OLS, spread, ATR, and lot guards.
- trade_entry: monthly momentum/IVol agreement and paired entry.
- trade_management: monthly reset, stale exit, and orphan cleanup.
- trade_close: per-leg ATR stops and package flattening.

## Risk

This is a four-proxy/two-traded-leg carrier test, not a replication. Q02 must
reject it below five packages/year or on invalid basket/economic evidence. No
live, portfolio-gate, deploy-manifest, `T_Live`, or AutoTrading mutation is
authorized.
