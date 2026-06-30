# QM5_11820_carter-m5-s9-ema50100-macd-m5 - Strategy Spec

**EA ID:** QM5_11820
**Slug:** carter-m5-s9-ema50100-macd-m5
**Source:** f4430cee-7efb-592e-bf0f-e469ef156b2d (see `strategy-seeds/sources/f4430cee-7efb-592e-bf0f-e469ef156b2d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

This EA trades the M5 trend defined by EMA(50) and EMA(100). It opens long when EMA(50) is above EMA(100) and the MACD(12,26,9) histogram crosses above zero on the last closed bar. It opens short when EMA(50) is below EMA(100) and the histogram crosses below zero. The EA exits with a 2x ATR(14) stop, a 4x ATR(14) take profit, or when the closed price crosses back through EMA(50) by 10 pips against the position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_M5` | MT5 timeframe enum | Signal timeframe from the card. |
| `strategy_ema_fast_period` | `50` | `>= 1` | Fast EMA period for trend state and exit line. |
| `strategy_ema_slow_period` | `100` | `>= 1` | Slow EMA period for trend state. |
| `strategy_macd_fast` | `12` | `>= 1` | MACD fast EMA period. |
| `strategy_macd_slow` | `26` | `>= 1` | MACD slow EMA period. |
| `strategy_macd_signal` | `9` | `>= 1` | MACD signal period. |
| `strategy_atr_period` | `14` | `>= 1` | ATR period used for stop and target distances. |
| `strategy_atr_sl_mult` | `2.0` | `> 0` | Stop loss distance in ATR multiples. |
| `strategy_atr_tp_mult` | `4.0` | `> 0` | Take profit distance in ATR multiples. |
| `strategy_exit_break_pips` | `10` | `> 0` | EMA(50) break distance in pips for discretionary exit. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major Forex pair with M5 DWX data.
- `GBPUSD.DWX` - card-listed major Forex pair with M5 DWX data.
- `USDJPY.DWX` - card-listed major Forex pair with M5 DWX data.
- `USDCHF.DWX` - card-listed major Forex pair with M5 DWX data.
- `AUDUSD.DWX` - card-listed major Forex pair with M5 DWX data.

**Explicitly NOT for:**
- Non-Forex `.DWX` symbols - the card names Forex pairs only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | Card does not specify; exits on EMA(50) break, ATR stop, or ATR target. |
| Expected drawdown profile | ATR-bounded trend-following losses. |
| Regime preference | Trend-following momentum. |
| Win rate target (qualitative) | Card does not specify. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** f4430cee-7efb-592e-bf0f-e469ef156b2d
**Source type:** book
**Pointer:** Thomas Carter, `20 Forex Trading Strategies (5 Minute Time Frame)`, 2014; local file `367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11820_carter-m5-s9-ema50100-macd-m5.md`

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
| v1 | 2026-06-26 | Initial build from card | 45e63651-deb3-47e9-a377-d28c39d5922d |
| v2 | 2026-06-30 | Q02 throughput repair | Explicit backtest setfile framework/news and strategy inputs; no strategy-logic change |
