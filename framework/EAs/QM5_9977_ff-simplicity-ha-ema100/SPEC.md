# QM5_9977_ff-simplicity-ha-ema100 - Strategy Spec

**EA ID:** QM5_9977
**Slug:** ff-simplicity-ha-ema100
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades the H1 ForexFactory Simplicity setup. A long is opened at the next H1 bar when the last closed candle closed above EMA(100), the prior Heiken Ashi candle was bearish, and the last Heiken Ashi candle turned bullish. A short mirrors the rule below EMA(100) after a bullish-to-bearish Heiken Ashi color flip. The stop is beyond the signal candle by 2 pips, widened to at least 0.4 x ATR(14) when needed, the take profit is 1R, and an open trade closes early on the opposite Heiken Ashi color flip.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_period` | 100 | 1+ | EMA close-period used as the trend-side filter. |
| `strategy_atr_period` | 14 | 1+ | ATR period used for the minimum stop-distance check. |
| `strategy_min_stop_atr_mult` | 0.40 | >0 | Minimum stop distance as a fraction of ATR(14). |
| `strategy_stop_buffer_pips` | 2 | 0+ | Extra pips beyond the signal candle low/high for stop placement. |
| `strategy_take_profit_rr` | 1.0 | >0 | Fixed reward/risk target. |
| `strategy_session_start_utc` | 6 | 0-23 | UTC hour when entries may begin. |
| `strategy_session_end_utc` | 15 | 0-23 | UTC hour when entries stop; interpreted as exclusive. |
| `strategy_max_spread_stop_fraction` | 0.08 | 0-1 | Maximum spread as a fraction of stop distance. |
| `strategy_ha_warmup_bars` | 80 | 3+ | Closed-bar warmup length for deterministic Heiken Ashi color calculation. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX major in the ForexFactory basket.
- `GBPUSD.DWX` - card-listed FX major in the ForexFactory basket.
- `USDCHF.DWX` - card-listed FX major in the ForexFactory basket.
- `USDJPY.DWX` - card-listed FX major in the ForexFactory basket.

**Explicitly NOT for:**
- `SP500.DWX` - not part of the card's FX-major basket.
- `XAUUSD.DWX` - not part of the card's FX-major basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | Intraday to multi-hour, bounded by 1R TP, SL, Friday close, or opposite HA flip |
| Expected drawdown profile | Trend-continuation FX strategy with fixed 1R risk and one position per magic-symbol |
| Regime preference | Trend-continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** zeiman, "Trading System Simplicity", ForexFactory, 2020, https://www.forexfactory.com/thread/1010582-trading-system-simplicity
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9977_ff-simplicity-ha-ema100.md`

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
| v1 | 2026-06-11 | Initial build from card | bdcd8894-249a-48fd-806f-b900bb9ded50 |
