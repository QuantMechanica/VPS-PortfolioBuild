# QM5_1607_aa-mom-tol-band - Strategy Spec

**EA ID:** QM5_1607
**Slug:** `aa-mom-tol-band`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7` (`sources/alpha-architect-blog`)
**Last revised:** 2026-08-22

## 1. Strategy Logic

The EA reviews its allocation once per broker-calendar month on a D1 chart using the last completed MN1 bar. Positive 12-month absolute momentum permits a 50%-60% index-risk allocation; non-positive momentum permits 40%-50%. It changes the held allocation only when the prior risk-budget fraction lies outside the permitted band, storing the chosen 40%, 50%, or 60% level in the order comment so the rule survives restarts. Invalid signal inputs close the position. A 3.0 x ATR(20,D1) stop is the catastrophic backstop.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_lookback_months` | 12 | Closed-MN1 lookback for absolute momentum. |
| `strategy_cash_return_12m_pct` | 0.0 | Approved price-only cash-return approximation in percent. |
| `strategy_atr_period` | 20 | D1 ATR period for the initial stop. |
| `strategy_atr_sl_mult` | 3.0 | Initial stop distance in ATR units. |
| `strategy_max_spread_atr_fraction` | 0.10 | Maximum spread as a fraction of D1 ATR at entry. |

## 3. Symbol Universe

The active registry supplies GDAXI.DWX, NDX.DWX, SP500.DWX, UK100.DWX, WS30.DWX, XAUUSD.DWX, EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX, AUDUSD.DWX, USDCAD.DWX, and NZDUSD.DWX. SP500.DWX is backtest-only; any live promotion requires the card's NDX.DWX or WS30.DWX parallel validation.

## 4. Timeframe

The execution timeframe is D1. The framework's single D1 new-bar gate drives the EA, while an internal calendar-month gate permits one review per month. The momentum signal reads completed MN1 bars and the stop reads completed D1 ATR. No second framework new-bar call is used.

## 5. Expected Behaviour

Expected signal reviews are monthly, with approximately 12 potential allocation decisions per year per symbol. The EA is long-only and normally remains invested at 40% or 50% of its configured risk budget; 60% is retained as the upper tolerance boundary. It is mechanical, non-ML, and neither grid nor martingale.

## 6. Source Citation

Andrew Miller, "Portfolio Rebalancing Research: Momentum and Tolerance Bands," Alpha Architect, 2017-05-31, https://alphaarchitect.com/destabilizing-rebalancing/. The approved card is `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1607_aa-mom-tol-band.md` and records R1-R4 PASS with `g0_status: APPROVED`.

## 7. Risk Model

Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. The 40%, 50%, and 60% exposure states scale the framework portfolio weight to the corresponding fraction of the configured risk budget. Live parameters remain a separate governed concern. There is one position per symbol and magic.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-22 | Implement approved monthly momentum tolerance-band controller under V5. |
