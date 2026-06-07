# QM5_11119_ma-cross-alert - Strategy Spec

**EA ID:** QM5_11119
**Slug:** ma-cross-alert
**Source:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

This EA trades a completed-bar simple moving average crossover on H4. A long entry is opened when SMA(25) was below SMA(50) on the prior completed H4 bar and is above SMA(50) on the latest completed H4 bar. A short entry is opened on the opposite crossover. Positions close on the opposite SMA crossover, after 20 H4 bars, or by the framework Friday close and broker stop handling.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_fast_sma_period | 25 | >0 and < slow period | Fast SMA period applied to H4 close. |
| strategy_slow_sma_period | 50 | > fast period | Slow SMA period applied to H4 close. |
| strategy_atr_period | 14 | >0 | ATR period used for stop distance. |
| strategy_atr_sl_mult | 2.5 | >0 | Stop distance multiplier applied to ATR(14). |
| strategy_max_hold_h4_bars | 20 | >=0 | Maximum holding time in H4 bars; 0 disables the time stop. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card R3 basket member; liquid FX major with DWX OHLC and ATR data.
- GBPUSD.DWX - card R3 basket member; liquid FX major with DWX OHLC and ATR data.
- USDJPY.DWX - card R3 basket member; liquid FX major with DWX OHLC and ATR data.
- XAUUSD.DWX - card R3 basket member; liquid gold market with DWX OHLC and ATR data.

**Explicitly NOT for:**
- Symbols outside the card R3 basket - not registered for this EA and not part of the approved portability set.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Expected trade frequency | SMA(25/50) crosses on H4 should occur several times per quarter per liquid symbol; conservative estimate 35 trades/year/symbol. |
| Typical hold time | Up to 20 H4 bars, unless an opposite SMA cross exits earlier. |
| Expected drawdown profile | Trend-following crossover profile with whipsaw losses in sideways regimes. |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Source type:** GitHub source repository
**Pointer:** EarnForex, Moving-Average-Crossover-Alert, `MQL5/Indicators/MQLTA MT5 Moving Average Crossover Alert.mq5`, function `IsSignal`, https://github.com/EarnForex/Moving-Average-Crossover-Alert
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11119_ma-cross-alert.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-07 | Initial build from card | 2c7451b2-d094-4f74-b25a-fcce6b3d3520 |
