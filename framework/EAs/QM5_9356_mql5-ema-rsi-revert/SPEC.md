# QM5_9356_mql5-ema-rsi-revert - Strategy Spec

**EA ID:** QM5_9356
**Slug:** `mql5-ema-rsi-revert`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

This EA trades M15 mean reversion around EMA(50). It buys when the last closed bar closes below EMA(50) and RSI(14) is at or below 30, and sells when the last closed bar closes above EMA(50) and RSI(14) is at or above 70. The take-profit is the EMA mean when valid, with a 2.0 ATR fallback, and the stop is placed beyond the wider of recent structure and 2.0 ATR. The EA enforces one open position per magic and a three-closed-bar cooldown after each signal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 50 | >= 2 | EMA period used as the mean-reversion anchor. |
| `strategy_rsi_period` | 14 | >= 2 | RSI period used for oscillator extremes. |
| `strategy_atr_period` | 14 | >= 2 | ATR period used for stop and fallback target distances. |
| `strategy_rsi_oversold` | 30.0 | 0-100 | Long-entry and short-exit RSI threshold. |
| `strategy_rsi_overbought` | 70.0 | 0-100 | Short-entry and long-exit RSI threshold. |
| `strategy_atr_sl_mult` | 2.0 | > 0 | ATR multiplier for stop distance. |
| `strategy_atr_tp_mult` | 2.0 | > 0 | ATR multiplier for fallback take-profit distance. |
| `strategy_structure_lookback` | 5 | >= 1 | Recent high/low lookback for structure stops. |
| `strategy_cooldown_bars` | 3 | >= 0 | Closed bars to wait after a signal before another signal can act. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX symbol with DWX OHLC coverage for EMA, RSI, and ATR.
- `GBPUSD.DWX` - card-listed FX symbol with DWX OHLC coverage for EMA, RSI, and ATR.
- `XAUUSD.DWX` - card-listed metals symbol with DWX OHLC coverage for EMA, RSI, and ATR.
- `GDAXI.DWX` - matrix-listed DAX custom symbol used for the card's `GER40.DWX` target.

**Explicitly NOT for:**
- `GER40.DWX` - card-listed DAX name is not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX equivalent.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` |
| Typical hold time | Intraday to short multi-bar hold until EMA mean, opposite signal, SL, or ATR fallback target. |
| Expected drawdown profile | Mean-reversion drawdown clusters during strong one-way moves. |
| Regime preference | Mean-revert / oscillator-extreme conditions. |
| Win rate target (qualitative) | Medium to high relative to trend-following systems, with smaller average winners. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** `MQL5 article`
**Pointer:** `https://www.mql5.com/en/articles/16700`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9356_mql5-ema-rsi-revert.md`

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
| v1 | 2026-06-25 | Initial build from card | d3058d35-e272-4236-a415-f51a958c46ab |
