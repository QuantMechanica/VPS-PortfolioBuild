# QM5_1606_aa-gvmt-robust - Strategy Spec

**EA ID:** QM5_1606
**Slug:** `aa-gvmt-robust`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7` (`sources/alpha-architect-blog`)
**Last revised:** 2026-08-22

## 1. Strategy Logic

The EA performs one rebalance review per broker-calendar month on a D1 chart, using only the last completed MN1 bar. It combines positive 12-month time-series momentum and a close-above-12-month-SMA signal. Both positive select 100% of the configured strategy risk budget, one positive selects 50%, and neither selects cash. Changes are implemented by closing the prior allocation and opening the new long allocation on that monthly review. A 3.0 x ATR(20,D1) stop is the catastrophic backstop; the monthly signal is the primary exit.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_lookback_months` | 12 | Closed-MN1 lookback for momentum and SMA. |
| `strategy_cash_return_12m_pct` | 0.0 | Approved price-only cash/T-bill approximation in percent. |
| `strategy_atr_period` | 20 | D1 ATR period for the initial stop. |
| `strategy_atr_sl_mult` | 3.0 | Initial stop distance in ATR units. |
| `strategy_max_spread_atr_fraction` | 0.10 | Maximum spread as a fraction of D1 ATR at entry. |

## 3. Symbol Universe

The active registry supplies GDAXI.DWX, NDX.DWX, SP500.DWX, UK100.DWX, WS30.DWX, XAUUSD.DWX, EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX, AUDUSD.DWX, USDCAD.DWX, and NZDUSD.DWX. SP500.DWX is backtest-only; any live promotion requires the card's NDX.DWX or WS30.DWX parallel validation.

## 4. Timeframe

The execution timeframe is D1. The framework's single D1 new-bar gate drives the EA, while an internal calendar-month gate permits one review per month. Signals read completed MN1 bars; the stop reads completed D1 ATR. No second framework new-bar call is used.

## 5. Expected Behaviour

Expected signal reviews are monthly, with approximately 12 potential allocation decisions per year per symbol. Positions are long-only, held across weeks, and reduced to half exposure or cash as the two trend signals weaken. This is a mechanical risk-on/risk-off trend strategy, not an intraday or high-frequency system.

## 6. Source Citation

Wesley Gray, PhD, "The Global Value Momentum Trend Philosophy," Alpha Architect, 2017-06-06, https://alphaarchitect.com/the-value-momentum-trend-philosophy/. The approved card is `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1606_aa-gvmt-robust.md` and records R1-R4 PASS with `g0_status: APPROVED`.

## 7. Risk Model

Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. A 50% signal scales the framework portfolio weight to half of the configured risk budget; a 100% signal uses the full configured weight. Live parameters remain a separate governed concern. There is one position per symbol and magic, no grid, no martingale, and no ML.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-22 | Implement approved GVMT robust monthly blend under V5. |
