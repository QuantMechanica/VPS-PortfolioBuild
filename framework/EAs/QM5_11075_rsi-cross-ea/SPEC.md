# QM5_11075_rsi-cross-ea - Strategy Spec

**EA ID:** QM5_11075
**Slug:** rsi-cross-ea
**Source:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

This EA trades H1 RSI re-entry crosses. It opens long when the latest completed RSI(14) bar is above 20 after the previous completed bar was at or below 20. It opens short when the latest completed RSI(14) bar is below 80 after the previous completed bar was at or above 80. Long positions close when RSI crosses back down through 80; short positions close when RSI crosses back up through 20. ATR(100) defines the baseline stop and target at 2x ATR and 3x ATR.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_rsi_period | 14 | 2+ | RSI period applied to close. |
| strategy_rsi_oversold | 20.0 | 0-100 | Oversold threshold for long re-entry and short exit. |
| strategy_rsi_overbought | 80.0 | 0-100 | Overbought threshold for short re-entry and long exit. |
| strategy_atr_period | 100 | 1+ | ATR period used for SL and TP distances. |
| strategy_atr_sl_mult | 2.0 | >0 | Stop-loss distance in ATR multiples. |
| strategy_atr_tp_mult | 3.0 | >0 | Take-profit distance in ATR multiples. |
| strategy_max_spread_points | 50 | 0+ | Spread fuse in points; zero disables the fuse. |
| strategy_use_trading_hours | false | true/false | Enables the optional source trading-hours filter. |
| strategy_start_hour | 7 | 0-23 | Broker hour when optional trading window starts. |
| strategy_end_hour | 19 | 0-23 | Broker hour when optional trading window ends. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card R3 names this liquid DWX FX pair for RSI/ATR H1 testing.
- GBPUSD.DWX - Card R3 names this liquid DWX FX pair for RSI/ATR H1 testing.
- USDJPY.DWX - Card R3 names this liquid DWX FX pair for RSI/ATR H1 testing.
- USDCAD.DWX - Card R3 names this liquid DWX FX pair for RSI/ATR H1 testing.

**Explicitly NOT for:**
- Non-DWX broker symbols - Build and backtest registries require the `.DWX` research symbol form.
- Non-FX baskets - The approved card R3 universe is limited to the four listed FX symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) through framework entry gating |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | Not specified in card; held until RSI exit cross, ATR SL/TP, or Friday close. |
| Expected drawdown profile | Conservative fixed-risk mean-reversion profile with ATR-bounded losses. |
| Regime preference | Mean-reversion after RSI 20/80 extremes. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Source type:** GitHub repository and article
**Pointer:** EarnForex RSI-EA, GitHub repository and MQL5 source, https://github.com/EarnForex/RSI-EA
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11075_rsi-cross-ea.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-07 | Initial build from card | 67894e6d-c551-4d97-a37b-6c86ec6031b4 |
