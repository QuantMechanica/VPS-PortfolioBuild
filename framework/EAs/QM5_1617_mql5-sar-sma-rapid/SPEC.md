# QM5_1617_mql5-sar-sma-rapid - Strategy Spec

**EA ID:** QM5_1617
**Slug:** `mql5-sar-sma-rapid`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (`sources/mql5-articles`)
**Last revised:** 2026-08-22

## 1. Strategy Logic

On each completed M15 bar, the EA detects a Parabolic SAR side reversal and filters it with SMA(60). It buys when the current SAR is below the current bar low, the previous SAR was above the previous bar high, and SMA(60) is below Ask. The sell rule is the exact mirror. The framework's new-bar gate provides the source's one-signal-per-bar rule, and one position per magic prevents stacking. Each entry carries the source's fixed 150-point stop and 100-point take profit; there is no discretionary strategy exit.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_sar_step` | 0.02 | Default Parabolic SAR acceleration step. |
| `strategy_sar_maximum` | 0.20 | Default Parabolic SAR maximum acceleration. |
| `strategy_sma_period` | 60 | Close-price simple moving average filter. |
| `strategy_stop_points` | 150 | Source stop distance in symbol points. |
| `strategy_take_profit_points` | 100 | Source take-profit distance in symbol points. |

## 3. Symbol Universe

The card names EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, GDAXI.DWX, and NDX.DWX. The governed portable registry also supplies SP500.DWX, UK100.DWX, WS30.DWX, USDCHF.DWX, AUDUSD.DWX, USDCAD.DWX, and NZDUSD.DWX for the full mechanical OHLC/indicator basket. Every symbol has a distinct active magic slot.

## 4. Timeframe

The base and only signal timeframe is M15. All SAR, SMA, high, and low values use completed bars at shifts one and two. The framework calls the entry hook only after `QM_IsNewBar()` succeeds.

## 5. Expected Behaviour

This is a high-cadence but bar-based M15 reversal strategy, not HFT. Trades close only through the attached fixed stop or take profit, the framework Friday sweep, or a framework risk/compliance control. It has one position per symbol/magic and no averaging, grid, or martingale behavior.

## 6. Source Citation

Allan Munene Mutiiria, "Implementing a Rapid-Fire Trading Strategy Algorithm with Parabolic SAR and Simple Moving Average (SMA) in MQL5," MQL5, 2024-08-29, https://www.mql5.com/en/articles/15698. The approved card is `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1617_mql5-sar-sma-rapid.md` and records R1-R4 PASS with `g0_status: APPROVED`.

## 7. Risk Model

Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`; the framework sizes from the fixed 150-point stop. Live sizing remains separately governed. News freshness stays fail-closed at 336 hours, and all entry requests flow through the V5 risk and compliance layers.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-22 | Implement the approved SAR/SMA rapid-reversal card under V5. |
