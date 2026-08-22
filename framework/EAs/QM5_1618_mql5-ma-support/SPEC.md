# QM5_1618_mql5-ma-support - Strategy Spec

**EA ID:** QM5_1618
**Slug:** `mql5-ma-support`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (`sources/mql5-articles`)
**Last revised:** 2026-08-22

## 1. Strategy Logic

On each completed H1 bar, the EA treats SMA(10) as dynamic support/resistance. It buys when the signal-bar low touches or penetrates the SMA while both open and close remain above it; the sell rule is the exact mirror. Entry occurs on the next bar. The stop is beyond the signal-bar extreme by 1.0 x ATR(14), and entries whose structural stop exceeds 2.0 x ATR are skipped. Positions exit on the opposite touch, a completed close through the SMA against the position, the attached stop, or the resolved 2R take profit.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_ma_period` | 10 | Close-price simple moving average. |
| `strategy_atr_period` | 14 | ATR period for structural stop normalization. |
| `strategy_atr_buffer_mult` | 1.0 | ATR buffer beyond the signal-bar extreme. |
| `strategy_max_stop_atr_mult` | 2.0 | Maximum accepted entry-to-stop distance in ATR units. |
| `strategy_take_profit_r` | 2.0 | Deterministic take profit in initial-risk units; zero disables. |
| `strategy_require_ma_slope` | false | Optional continuation variant; disabled for baseline. |

The card defines sweep ranges but not a single baseline buffer, stop cap, or take-profit multiple. The implementation uses the middle of the authorized ATR ranges (1.0 buffer, 2.0 cap) and a conventional 2R deterministic target; the reviewer should explicitly confirm those resolutions.

## 3. Symbol Universe

The card names EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, GDAXI.DWX, and NDX.DWX. Its R3 rule is portable to DWX OHLC symbols, and the governed registry also supplies SP500.DWX, UK100.DWX, WS30.DWX, USDCHF.DWX, AUDUSD.DWX, USDCAD.DWX, and NZDUSD.DWX. Every symbol has a distinct active magic slot.

## 4. Timeframe

The base and only signal timeframe is H1. All OHLC, SMA, and ATR reads use the completed signal bar. The framework's H1 new-bar gate runs before both the close decision and next-bar entry decision, keeping history reads off the per-tick path.

## 5. Expected Behaviour

This is a bar-based pullback-continuation strategy. It trades MA rejection touches, stays flat when the structural stop would exceed the ATR cap, and permits one position per symbol/magic. It is mechanical and uses no HFT, ML, averaging, grid, or martingale technique.

## 6. Source Citation

Oleh Fedorov, "What you can do with Moving Averages," MQL5, 2022-04-28, https://www.mql5.com/en/articles/10479. The approved card is `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1618_mql5-ma-support.md` and records R1-R4 PASS with `g0_status: APPROVED`.

## 7. Risk Model

Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`; the framework sizes from the structural ATR stop. Live sizing remains separately governed. News freshness stays fail-closed at 336 hours, and all entry requests flow through the V5 risk and compliance layers.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-22 | Implement the approved MA support/resistance touch card under V5. |
