# QM5_10167_stochrsi-mom - Strategy Spec

**EA ID:** QM5_10167
**Slug:** stochrsi-mom
**Source:** d3c009d7-a8d6-5251-b572-4777b207c2b9 (see `strategy-seeds/sources/d3c009d7-a8d6-5251-b572-4777b207c2b9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA evaluates once per completed D1 bar. It computes RSI(14), converts that RSI stream into StochRSI(14), and opens long when StochRSI crosses above the 50 centerline or short when it crosses below the 50 centerline. Long positions close when StochRSI crosses below 80 after being above 80, or crosses below 50; short positions close when StochRSI crosses above 20 after being below 20, or crosses above 50. The emergency stop is 3.0 x ATR(14) from entry and no fixed take-profit is used.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 14 | 10-21 | RSI period used as the source series for StochRSI. |
| `strategy_stochrsi_lookback` | 14 | 10-21 | Lookback window for min/max RSI normalization. |
| `strategy_centerline` | 50.0 | 45.0-55.0 | Centerline threshold for entry and centerline exits. |
| `strategy_long_exhaustion` | 80.0 | 70.0-85.0 | Long exhaustion exit threshold crossed from above. |
| `strategy_short_exhaustion` | 20.0 | 15.0-30.0 | Short exhaustion exit threshold crossed from below. |
| `strategy_atr_period` | 14 | 14 | ATR period for the emergency stop. |
| `strategy_atr_sl_mult` | 3.0 | 3.0 | ATR multiplier for the emergency stop distance. |
| `strategy_warmup_bars` | 30 | 30+ | Card warmup convention for D1 bars. |
| `strategy_sma_slope_period` | 0 | 0, 50, 100 | Optional P3 SMA slope agreement filter; 0 disables it. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - card R3 names S&P 500 exposure as portable for the close-only oscillator; build-time use is backtest-only.
- `NDX.DWX` - card R3 names Nasdaq 100 exposure as a portable US large-cap index target.
- `WS30.DWX` - card R3 names Dow 30 exposure as a portable US large-cap index target.

**Explicitly NOT for:**
- Non-DWX symbols - the V5 research and backtest pipeline requires canonical `.DWX` symbols.
- `SPX500.DWX`, `SPY.DWX`, and `ES.DWX` - unavailable S&P 500 aliases; `SP500.DWX` is the canonical custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` from the framework; strategy indicator reads use closed D1 bars. |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Typical hold time | days |
| Expected drawdown profile | Whipsaw risk around the centerline during choppy regimes. |
| Regime preference | Momentum with clean directional persistence. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d3c009d7-a8d6-5251-b572-4777b207c2b9
**Source type:** blog
**Pointer:** https://raposa.trade/blog/2-ways-to-trade-the-stochastic-rsi-in-python/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10167_stochrsi-mom.md`

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
| v1 | 2026-06-10 | Initial build from card | 02187c91-69bc-4758-886e-f7d9087c26cb |
