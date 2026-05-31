# QM5_10579_mql5-schaffdm - Strategy Spec

**EA ID:** QM5_10579
**Slug:** mql5-schaffdm
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA computes a Schaff trend cycle from the difference between a fast DeMarker oscillator and a slow DeMarker oscillator on closed H4 bars. It opens a long position when the latest closed bar crosses upward through the zero level, and it opens a short position when the latest closed bar crosses downward through the zero level. A long closes on a bearish zero breakthrough, and a short closes on a bullish zero breakthrough. Every entry also carries the P2 baseline ATR(14) 2.0 hard stop and a 1.5R target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | M1-MN1 | Timeframe used for the closed-bar Schaff/DeMarker signal. |
| `strategy_signal_bar` | `1` | >=1 | Closed bar shift used for signal evaluation. |
| `strategy_fast_demarker` | `23` | >1 | Fast DeMarker period from the source indicator default. |
| `strategy_slow_demarker` | `50` | >1 | Slow DeMarker period from the source indicator default. |
| `strategy_cycle` | `10` | >1 | Schaff stochastic cycle length from the source indicator default. |
| `strategy_zero_level` | `0` | -100-100 | Breakthrough threshold for entries and opposite-signal exits. |
| `strategy_atr_period` | `14` | >0 | ATR period for the hard stop. |
| `strategy_atr_sl_mult` | `2.0` | >0 | ATR multiple used for the hard stop. |
| `strategy_take_profit_rr` | `1.5` | >0 | Reward-to-risk target multiple. |
| `strategy_max_spread_points` | `0` | >=0 | Optional spread cap in points; zero disables it. |

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - source test was USDJPY H4 and the card includes it in the primary P2 basket.
- `GBPJPY.DWX` - JPY FX cross with liquid DWX coverage and compatible oscillator behaviour.
- `EURUSD.DWX` - major FX pair with liquid DWX coverage and compatible oscillator behaviour.
- `XAUUSD.DWX` - liquid metal symbol included by the card for portable oscillator testing.

**Explicitly NOT for:**
- Non-DWX symbols - build and pipeline artifacts must use the registered `.DWX` symbols only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `40` |
| Typical hold time | hours to days |
| Expected drawdown profile | Moderate oscillator-reversal drawdowns, bounded by ATR stop and fixed target. |
| Regime preference | overbought-oversold cycle / oscillator zero-cross |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/14064
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10579_mql5-schaffdm.md`

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
| v1 | 2026-05-29 | Initial build from card | 54d078c4-9585-40c9-b3d7-6b16d419b272 |
