---
strategy_id: BIANCHI-MOMREV-2015_XTI_XNG_S01
source_id: BIANCHI-MOMREV-2015
ea_id: QM5_13120
slug: energy-momrev
status: APPROVED
g0_status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
source_citation: "Bianchi, Drew, and Fan (2015), Combining Momentum with Reversal in Commodity Futures, Journal of Banking & Finance 59, 423-444, DOI 10.1016/j.jbankfin.2015.07.006."
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
period: D1
logical_symbol: QM5_13120_ENERGY_MOMREV_D1
expected_trade_frequency: "Approximately 5-9 eligible monthly packages/year after warm-up."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.05
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
g0_approval_reasoning: "OWNER mission 2026-07-10: peer-reviewed source, fixed 12/18-month opposite-rank energy package, native XTI/XNG D1 data, no ML or banned indicator, exact dedup clean."
---

# XTI/XNG Momentum-Reversal Double Sort

## Source

Bianchi, Robert J.; Drew, Michael E.; and Fan, John Hua (2015), "Combining
Momentum with Reversal in Commodity Futures", *Journal of Banking & Finance*
59, 423-444. DOI https://doi.org/10.1016/j.jbankfin.2015.07.006. The complete
accepted manuscript was reviewed from the Griffith University repository.

The paper's preferred diversified portfolio first ranks commodities on past
12-month momentum, then uses an 18-month contrarian rank inside the winner and
loser groups, with no skipped month and a one-month hold. Its broad-source
performance and correlation are not claims for this two-CFD carrier.

## Market And Timeframe

- Logical basket: `QM5_13120_ENERGY_MOMREV_D1`.
- Host and slot 0: `XTIUSD.DWX`, D1.
- Companion and slot 1: `XNGUSD.DWX`, D1.
- One decision on the first tradable D1 bar of each broker month.
- Expected frequency: approximately 5-9 paired packages per year; retire at
  Q02 below five completed packages/year.

## Entry Rules

- Reconstruct synchronized completed month-end closes for each symbol at the
  current, 12-month-back, and 18-month-back broker-month boundaries.
- Compute 12- and 18-completed-month log returns for XTI and XNG.
- If XTI is the 12-month winner and 18-month loser, BUY XTI and SELL XNG.
- If XTI is the 12-month loser and 18-month winner, SELL XTI and BUY XNG.
- If both horizon ranks agree, either comparison ties, an endpoint is more
  than ten days stale, or history/arithmetic/spread/ATR is invalid, remain flat.
- Allocate half of `RISK_FIXED=1000` to each leg and attach a frozen
  `ATR(20) * 3.5` stop loss to each position.

## Exit Rules

- Close both legs at the next broker-month transition before reconsidering.
- Close both positions after 35 days as a stale-package time stop.
- Flatten the surviving position immediately after a leg stop or any invalid
  package composition.
- Friday close is disabled only to preserve the source's one-month hold.

## Risk And Allowability

- Backtest setfile only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- No take profit, trailing stop, scale-in, grid, martingale, pyramiding,
  banned indicator, external runtime data, adaptive fit, or ML.
- The two-leg translation loses the source's 27-future diversification and
  does not reproduce futures roll, collateral, or term-structure economics.
- Equal fixed risk and opposite direction do not guarantee beta neutrality;
  Q09 alone may determine portfolio correlation.
- No T_Live, live setfile, AutoTrading change, deploy manifest, or portfolio
  gate change is authorized.

The full approved research card is
`strategy-seeds/cards/approved/QM5_13120_energy-momrev_card.md`.
