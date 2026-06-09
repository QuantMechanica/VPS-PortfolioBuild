# QM5_10166_stochrsi-mr — Strategy Spec

**EA ID:** QM5_10166
**Slug:** `stochrsi-mr`
**Source:** `d3c009d7-a8d6-5251-b572-4777b207c2b9` (see `strategy-seeds/sources/d3c009d7-a8d6-5251-b572-4777b207c2b9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA evaluates one completed D1 bar at a time. It computes RSI(14), then
StochRSI as `100 * (RSI - rolling_min_RSI_14) / (rolling_max_RSI_14 -
rolling_min_RSI_14)`. It enters long when StochRSI crosses up through 20 and
enters short when StochRSI crosses down through 80. Long positions exit when
StochRSI crosses above 50; short positions exit when StochRSI crosses below 50.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 14 | 10-21 | RSI close lookback used by StochRSI. |
| `strategy_stoch_lookback` | 14 | 10-21 | Rolling RSI min/max lookback for StochRSI. |
| `strategy_entry_low` | 20.0 | 10-30 | Long trigger threshold crossed upward. |
| `strategy_entry_high` | 80.0 | 70-90 | Short trigger threshold crossed downward. |
| `strategy_exit_midline` | 50.0 | 45-55 | Centerline threshold used for strategy exits. |
| `strategy_atr_period` | 14 | 14 | ATR lookback for the emergency stop. |
| `strategy_atr_sl_mult` | 2.5 | 1.5-3.0 | ATR multiple for the emergency stop. |
| `strategy_warmup_bars` | 30 | 30+ | Minimum D1 warmup before signals are allowed. |
| `strategy_trend_filter` | false | true/false | Optional P3 close-vs-MA trend filter. |
| `strategy_trend_ma_period` | 200 | 200 | Optional trend-filter moving average period. |
| `strategy_trend_filter_ema` | false | true/false | Use EMA(200) instead of SMA(200) for the optional trend filter. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — S&P 500 custom symbol from the card's portable US index basket.
- `NDX.DWX` — Nasdaq 100 index CFD from the card's portable US index basket.
- `WS30.DWX` — Dow 30 index CFD from the card's portable US index basket.

**Explicitly NOT for:** any symbol not in the list above (no implicit
universe expansion at runtime; the `QM_SymbolGuard` framework helper
rejects foreign symbols).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | see `Strategy_*` hooks in the .mq5 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | not specified in card; exits on oscillator centerline or opposite signal |
| Expected drawdown profile | suffers in persistent trend regimes unless the optional trend filter helps |
| Regime preference | fast oscillator mean reversion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d3c009d7-a8d6-5251-b572-4777b207c2b9`
**Pointer:** `strategy-seeds/sources/d3c009d7-a8d6-5251-b572-4777b207c2b9/`
**R1–R4 verdict (Q00):** all PASS — see
`artifacts/cards_approved/QM5_10166_stochrsi-mr.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-09 | Initial build from card | 152f86cd-4031-4fb7-9266-1c0289cbde34 |
