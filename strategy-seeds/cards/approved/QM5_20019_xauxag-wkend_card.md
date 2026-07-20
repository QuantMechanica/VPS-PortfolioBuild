---
ea_id: QM5_20019
slug: xauxag-wkend
strategy_id: BOROWSKI-LUKASIK-METALS-2017_S01
source_id: BOROWSKI-LUKASIK-METALS-2017
status: APPROVED
created: 2026-07-20
created_by: Research
last_updated: 2026-07-20
g0_status: APPROVED
strategy_type_flags: [calendar-seasonality, market-neutral-basket, weekend-effect, atr-hard-stop, time-stop, low-frequency]
source_citations:
  - type: academic_paper
    citation: "Borowski, K. and Lukasik, M. (2017), Analysis of Selected Seasonality Effects in the Following Metal Markets: Gold, Silver, Platinum, Palladium and Copper, Journal of Management and Financial Sciences 27, 59-86."
    location: "Sections 4.3 and 5; Tables 5 and 7; https://econjournals.sgh.waw.pl/JMFS/article/download/740/643/"
    quality_tier: B
    role: primary
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
period: H1
expected_trades_per_year_per_symbol: 48
pipeline_phase: Q02
q01_status: PASS
q02_status: QUEUED
q02_work_item_id: 1790413c-1c71-46a4-ac75-3f7e9464249f
review_focus: "Falsify the tiny gold-minus-silver weekend differential after two-leg costs and broker-boundary basis; downstream correlation gate remains unchanged."
---

# XAU/XAG Market-Neutral Weekend Differential

## Hypothesis

The source finds a statistically significant Friday-close to Monday-open
weekend effect in gold but not silver. One equal-notional XAU-long/XAG-short
package tests the differential while suppressing broad precious-metal beta.
The hedge is a transparent QM translation, not a source-tested construction.

## Rules

- Host `XAUUSD.DWX` H1; foreign leg `XAGUSD.DWX`, slots 0 and 1.
- On the genuine broker Friday 21:00 H1 bar, consume one attempt before all
  fallible gates; require synchronized bars, valid symbols and spreads.
- BUY XAU and SELL XAG at equal absolute USD notionals, rounding down only.
- Allocate one combined `RISK_FIXED=1000` budget across both ATR(20) stops at
  `3.0*ATR`; maximum notional mismatch is 20%.
- Close both legs at the first Monday H1 bar. A four-day stale guard, orphan
  repair and stop remain authoritative. Friday close is explicitly disabled
  because weekend exposure is the alpha definition.
- No retry, scale-in, partial close, trailing, ML, grid or martingale.

## Parameters to test

All values are locked: Friday=5, broker hour=21, ATR=20, multiplier=3.0,
notional ratio=1.0, mismatch cap=20%, stale days=4, XAU/XAG spread caps
1500/500 points. No baseline sweep is authorized.

## Source facts and kill criteria

Table 5 reports weekend-test p-values `0.001138788` for gold and `0.323175`
for silver; Table 7 reports gross means `0.0294%` and `0.0223%`. Retire for
fewer than five completed packages/year, zero trades, incorrect timing or leg
direction, nondeterminism, risk/hedge breach, or failure of governed PF/DD and
later correlation gates. CFD boundaries, post-publication decay, gaps,
financing and two-leg costs are explicit kill risks.

## Framework alignment

- no_trade: exact host/timeframe/slot, locked inputs, synchronized symbols.
- trade_entry: restart-safe Friday 21:00 attempt and atomic repairable basket.
- trade_management: composition/notional repair, Monday close, stale close.
- trade_close: shared ATR risk, deterministic package close.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`. No live set, AutoTrading,
T_Live, deploy manifest, portfolio admission or gate change is authorized.
