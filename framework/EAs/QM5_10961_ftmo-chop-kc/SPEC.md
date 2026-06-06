# QM5_10961_ftmo-chop-kc - Strategy Spec

**EA ID:** QM5_10961
**Slug:** ftmo-chop-kc
**Source:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades H1 volatility breakouts when CHOP shows either an active trend or a fresh move out of consolidation. A long entry requires the last closed H1 candle to break above the Keltner upper band and TSI(25,13) to have crossed above zero within the last three closed bars; a short entry mirrors this below the Keltner lower band with a TSI cross below zero. The stop is the wider of the distance to the Keltner middle line or 1.5 ATR(20), the take profit is 2.0R, and open trades close early on an adverse TSI signal-line cross or after 48 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_chop_period | 14 | 2-100 | CHOP lookback used for trend and consolidation state. |
| strategy_chop_trend_threshold | 38.1 | 0-100 | Trending-mode threshold; CHOP below this permits entries. |
| strategy_chop_consolidation_level | 61.8 | 0-100 | Consolidation threshold used for the breakout-from-consolidation mode. |
| strategy_chop_lookback_bars | 10 | 1-100 | Number of closed H1 bars checked for recent consolidation. |
| strategy_keltner_ema_period | 20 | 2-200 | EMA middle line for the Keltner Channel. |
| strategy_keltner_atr_period | 20 | 2-200 | ATR period for Keltner width and volatility stop. |
| strategy_keltner_atr_mult | 2.0 | 0.1-10.0 | ATR multiplier for Keltner upper and lower bands. |
| strategy_tsi_fast_period | 25 | 2-200 | First EMA period in the TSI calculation. |
| strategy_tsi_slow_period | 13 | 2-200 | Second EMA period in the TSI calculation. |
| strategy_tsi_signal_period | 13 | 2-200 | EMA period for the TSI signal line used by exits. |
| strategy_tsi_zero_cross_bars | 3 | 1-10 | Closed-bar window in which a TSI zero cross can confirm entry. |
| strategy_sl_atr_mult | 1.5 | 0.1-10.0 | ATR stop-distance floor. |
| strategy_tp_r_multiple | 2.0 | 0.1-10.0 | Reward multiple for take profit. |
| strategy_max_hold_bars | 48 | 1-500 | Maximum H1 holding time before strategy exit. |
| strategy_atr_percentile_lookback | 8760 | 100-20000 | H1 bars used to estimate the 12-month ATR percentile filter. |
| strategy_atr_percentile_min | 30.0 | 0-100 | Minimum ATR percentile required for new entries. |
| strategy_max_spread_stop_fraction | 0.10 | 0-1 | Maximum spread as a fraction of planned stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- XAUUSD.DWX - volatile metal CFD named directly by the card.
- NDX.DWX - volatile US index CFD named directly by the card.
- WS30.DWX - liquid US index CFD named directly by the card.
- EURUSD.DWX - lower-volatility FX control named directly by the card.

**Explicitly NOT for:**
- Symbols outside the approved DWX matrix - the build registers only the card's R3 portable basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 55 |
| Typical hold time | Up to 48 H1 bars |
| Expected drawdown profile | Breakout strategy with clustered losses in failed volatility expansions. |
| Regime preference | volatility-expansion / breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Source type:** blog
**Pointer:** FTMO, "Three-phase momentum strategy for Bitcoin", 2024-12-20, https://ftmo.com/en/three-phase-momentum-strategy-for-bitcoin/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10961_ftmo-chop-kc.md`

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
| v1 | 2026-06-06 | Initial build from card | 999faaa6-b1a4-4075-9355-2e664546755c |
