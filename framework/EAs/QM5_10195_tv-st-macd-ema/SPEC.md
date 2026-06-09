# QM5_10195_tv-st-macd-ema - Strategy Spec

**EA ID:** QM5_10195
**Slug:** `tv-st-macd-ema`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA evaluates completed H1 bars. It opens a long position when Supertrend is up, the MACD line is above the MACD signal line, and the closed bar is above EMA(200). It opens a short position when Supertrend is down, the MACD line is below the MACD signal line, and the closed bar is below EMA(200). Long positions close when the MACD line crosses below the signal line; short positions close when the MACD line crosses above the signal line.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_H1` | MT5 timeframe enum | Closed-bar signal timeframe from the card baseline. |
| `strategy_supertrend_period` | 10 | >= 1 | ATR period used by Supertrend. |
| `strategy_supertrend_mult` | 3.0 | > 0 | Supertrend ATR multiplier. |
| `strategy_supertrend_warmup` | 120 | >= 80 | Bounded OHLC history used to stabilize Supertrend state. |
| `strategy_macd_fast` | 12 | >= 1 | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | > fast | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | >= 1 | MACD signal EMA period. |
| `strategy_ema_period` | 200 | >= 1 | Trend-side EMA period. |
| `strategy_swing_lookback` | 10 | >= 1 | Structure stop lookback in completed bars. |
| `strategy_atr_period` | 14 | >= 1 | ATR period for broker-min-distance stop fallback. |
| `strategy_atr_fallback_mult` | 1.5 | > 0 | ATR multiplier used when the swing stop is too close. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX pair with full DWX matrix coverage.
- `GBPUSD.DWX` - card-listed major FX pair with full DWX matrix coverage.
- `GDAXI.DWX` - canonical DWX DAX symbol used for the card's `DAX.DWX` target.
- `NDX.DWX` - card-listed liquid index CFD with DWX matrix coverage.
- `XAUUSD.DWX` - card-listed gold CFD with DWX matrix coverage.

**Explicitly NOT for:**
- `DAX.DWX` - not present in `dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.
- Symbols outside the active magic registry rows for this EA - the framework magic resolver rejects unregistered symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via skeleton wiring |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | not specified by card; MACD reversal exit implies multi-bar H1 holds |
| Expected drawdown profile | bounded by fixed-risk structure stops and framework risk controls |
| Regime preference | trend-following momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script
**Pointer:** TradingView script `Supertrend and MACD strategy`, author handle `angiludia`, published 2024-12-01, `https://www.tradingview.com/script/lGdn6A7A/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10195_tv-st-macd-ema.md`

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
| v1 | 2026-06-09 | Initial build from card | 13da6049-327f-46fc-bcc8-d1695dbc1686 |
