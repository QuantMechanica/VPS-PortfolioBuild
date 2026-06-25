# QM5_11321_tc-m5-17-ema3-8-sd-filter — Strategy Spec

**EA ID:** QM5_11321
**Slug:** `tc-m5-17-ema3-8-sd-filter`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see local PDF cited in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades the Carter M5 System #17 trend stack on closed M5 bars. A long entry requires EMA(3) above EMA(8), Parabolic SAR below the signal candle, MACD(12,26,9) main above zero, Stochastic(10,15,15) %K crossing above %D, and StdDev(20) at or above the pair-class medium volatility floor. A short entry mirrors those rules with EMA(3) below EMA(8), SAR above the candle, MACD below zero, and %K crossing below %D. The stop is the recent swing low for longs or swing high for shorts using the prior 10 closed bars excluding the signal bar; positions close when EMA(3) crosses back to the opposite side of EMA(8).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 3 | 2-10 | Fast EMA period |
| `strategy_ema_slow_period` | 8 | 5-30 | Slow EMA period |
| `strategy_sar_step` | 0.02 | 0.01-0.05 | Parabolic SAR acceleration step |
| `strategy_sar_max` | 0.20 | 0.10-0.50 | Parabolic SAR maximum acceleration |
| `strategy_macd_fast` | 12 | 5-20 | MACD fast EMA period |
| `strategy_macd_slow` | 26 | 15-40 | MACD slow EMA period |
| `strategy_macd_signal` | 9 | 5-15 | MACD signal period |
| `strategy_stoch_k` | 10 | 5-20 | Stochastic %K period |
| `strategy_stoch_d` | 15 | 3-20 | Stochastic %D period |
| `strategy_stoch_slowing` | 15 | 3-20 | Stochastic slowing |
| `strategy_stddev_period` | 20 | 10-40 | Standard Deviation lookback |
| `strategy_stddev_strong_only` | false | true/false | false admits medium and strong volatility; true admits strong only |
| `strategy_swing_lookback` | 10 | 5-15 | Swing stop lookback in closed bars, excluding signal bar |
| `strategy_spread_points_cap` | 20.0 | 5-50 | Blocks only genuinely wide modeled spread; zero DWX spread passes |

---

## 3. Symbol Universe

**Designed for:**
- `AUDUSD.DWX` — card P2 basket major pair; AUD/NZD StdDev floors apply.
- `NZDUSD.DWX` — card P2 basket major pair; AUD/NZD StdDev floors apply.
- `USDJPY.DWX` — card P2 basket major pair; JPY StdDev floors apply.
- `EURUSD.DWX` — card P2 basket major pair; other-pair StdDev floors apply.

**Explicitly NOT for:**
- Index, metal, energy, and crypto `.DWX` symbols — the source thresholds and M5 mechanics are specified for major FX pairs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | `minutes to a few hours` |
| Expected drawdown profile | `whipsaw drawdowns in weak or ranging M5 regimes` |
| Regime preference | `trend-following with medium/strong volatility filter` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** Thomas Carter, `20 Forex Trading Strategies (5 Minute Time Frame)`, 5 Min Trading System #17, pages 41-42; local PDF path cited in the approved card.
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11321_tc-m5-17-ema3-8-sd-filter.md`

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
| v1 | 2026-06-25 | Initial build from card | 6ccab032-5526-44ea-8da1-d1f86fc58df8 |
