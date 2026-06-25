# QM5_2079_williams-ultimate-oscillator-h4 - Strategy Spec

**EA ID:** QM5_2079
**Slug:** williams-ultimate-oscillator-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

This EA trades Larry Williams' Ultimate Oscillator divergence rule on H4 bars. It computes buying pressure and true range, blends 7-, 14-, and 28-bar BP/TR ratios with fixed 4:2:1 weights, and enters long when price makes a meaningful lower low while UO makes a higher low from an oversold prior window and then crosses above the inter-low trigger line. Shorts use the mirrored higher-high, lower-UO-high, overbought, trigger-line breakdown rule. Exits come from the opposite divergence trigger, overbought or oversold target reach, trigger-line failure, ATR trailing, time stop, and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_signal_tf | PERIOD_H4 | H4 baseline | Signal timeframe from the card. |
| strategy_uo_fast_period | 7 | >0 | Fast UO buying-pressure window. |
| strategy_uo_mid_period | 14 | >0 | Middle UO buying-pressure window. |
| strategy_uo_slow_period | 28 | >0 | Slow UO buying-pressure window. |
| strategy_divergence_window | 14 | >=2 | Current/prior window length for divergence anchors. |
| strategy_min_low_separation | 7 | >=1 | Minimum bar separation between compared extremes. |
| strategy_oversold_level | 30.0 | 0-100 | Oversold threshold for bullish divergence context. |
| strategy_overbought_level | 70.0 | 0-100 | Overbought threshold for bearish divergence context and long target. |
| strategy_atr_period | 20 | >0 | ATR period for stops, spread cap, and trailing. |
| strategy_initial_stop_atr_mult | 0.5 | >0 | Initial stop buffer beyond the signal bar extreme. |
| strategy_meaningful_extreme_atr | 0.5 | >0 | Required price break beyond prior extreme, in ATR units. |
| strategy_trail_start_atr_mult | 1.5 | >0 | Favorable move required before ATR trailing starts. |
| strategy_trail_atr_mult | 2.5 | >0 | ATR trailing distance after activation. |
| strategy_d1_sma_period | 100 | >0 | D1 SMA regime filter period. |
| strategy_use_d1_sma_filter | true | true/false | Enables the optional macro-bias gate from the card. |
| strategy_uo_range_lookback | 50 | >0 | UO stability/range lookback. |
| strategy_min_uo_range | 30.0 | 0-100 | Minimum UO range over the stability lookback. |
| strategy_target_breakout_lookback | 20 | >0 | Recent price extreme window for overbought/oversold target exits. |
| strategy_max_hold_bars | 50 | >0 | Time stop in H4 bars. |
| strategy_warmup_bars | 120 | >= required UO/window lookback | Closed-bar OHLC warm-up window for UO math. |
| strategy_spread_atr_mult | 0.30 | >=0 | Maximum live spread as a fraction of ATR; zero-spread DWX quotes are allowed. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - FX major explicitly listed in the card R3/target_symbols.
- GBPUSD.DWX - FX major explicitly listed in the card R3/target_symbols.
- USDJPY.DWX - FX major explicitly listed in the card R3/target_symbols.
- XAUUSD.DWX - Williams commodity/metal lineage and card target symbol.
- XTIUSD.DWX - Williams crude-oil lineage and card target symbol.
- NDX.DWX - Liquid index target from the card R3 basket.
- WS30.DWX - Liquid index target from the card R3 basket.
- GDAXI.DWX - European index target from the card R3 basket.
- UK100.DWX - European index target from the card R3 basket.
- SP500.DWX - Backtest-only S&P 500 port because R3 references S&P-500 examples and current DWX discipline names SP500.DWX as the canonical S&P symbol.

**Explicitly NOT for:**
- SPX500.DWX - Not present in the DWX symbol matrix; SP500.DWX is the canonical custom S&P symbol.
- SPY.DWX - Not present in the DWX symbol matrix.
- ES.DWX - Not present in the DWX symbol matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 SMA(100) regime filter |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | up to 50 H4 bars, about 9 calendar days |
| Expected drawdown profile | Momentum-divergence reversals with ATR-defined initial risk and trailing protection after favorable movement. |
| Regime preference | Multi-period momentum divergence with optional higher-timeframe trend bias. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum/book/article reference bundle
**Pointer:** artifacts/cards_approved/QM5_2079_williams-ultimate-oscillator-h4.md
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_2079_williams-ultimate-oscillator-h4.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-26 | Initial build from card | 10392e6e-de53-4f88-b0df-76fb293c0883 |
