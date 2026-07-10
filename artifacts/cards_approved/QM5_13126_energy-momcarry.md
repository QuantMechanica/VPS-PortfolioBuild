---
strategy_id: FMR-MOMTS-2010_XTI_XNG_S01
source_id: FMR-MOMTS-2010
ea_id: QM5_13126
slug: energy-momcarry
status: APPROVED
g0_status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
source_citation: "Fuertes, Miffre, and Rallis (2010), Tactical Allocation in Commodity Futures Markets: Combining Momentum and Term Structure Signals, Journal of Banking & Finance 34(10), 2530-2548, DOI 10.1016/j.jbankfin.2010.04.009."
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
period: D1
logical_symbol: QM5_13126_ENERGY_MOMCARRY_D1
expected_trade_frequency: "Approximately 4-8 completed monthly packages/year when independent momentum and carry ranks agree."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.05
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
g0_approval_reasoning: "OWNER mission 2026-07-10: peer-reviewed full source; fixed one-month momentum/carry agreement, paired monthly hold, equal fixed risk, ATR stops; native registered XTI/XNG data; no ML/banned logic; dedup CLEAN before atomic allocation."
---

# XTI/XNG Momentum-Carry Double Screen

## Hypothesis

Trade the XTI/XNG relative winner only when an independent broker-native carry
rank agrees, thereby testing the source's high-roll-return-winner versus
low-roll-return-loser structure in a two-energy CFD carrier.

## Entry Rules

- Run one logical basket from `XTIUSD.DWX` D1 with `XNGUSD.DWX` at slot 1.
- On the first tradable D1 bar of each broker month, rank synchronized last-
  completed-month log returns.
- Independently rank `SYMBOL_SWAP_LONG - SYMBOL_SWAP_SHORT` for the two legs.
- Stay flat on a momentum/carry disagreement, return tie, nonzero carry tie,
  missing history, invalid risk metadata, or excess spread. For all-zero
  `.DWX` tester metadata, use the card-locked `+1` carry rank and still require
  one-month momentum agreement.
- Buy the higher-return/higher-carry leg and short the other leg.
- Split `RISK_FIXED=1000` equally and attach a frozen `ATR(20) * 3.5` stop to
  each leg.
- Close at the next month transition, after 35 days, or on orphan/invalid
  package repair. Friday close is disabled only for the monthly hold.

## Exit Rules

The next month transition, 35-day stale guard, broker hard stop, or invalid
two-leg composition closes the package through framework helpers.

## Risk

The source trades 37 futures and observes front-end roll returns; this port has
two CFDs and uses broker swap as a falsifiable proxy. Because `.DWX` historical
tests expose zero swap, Q02 tests the interaction conditional on a fixed `+1`
carry prior, not historical carry changes. Retire below five completed
packages/year. No source performance or portfolio correlation is imported.

This is distinct from raw XTI/XNG momentum (`QM5_12733`), weekly carry-only
ranking (`QM5_13089`), and 12-month momentum plus price trend (`QM5_13121`):
this card requires a completed-month momentum/carry agreement and renews only
monthly. Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`. No
live artifact, portfolio gate, deploy manifest, T_Live, or AutoTrading change
is approved.

Full canonical card: `strategy-seeds/cards/energy-momcarry_card.md`.
