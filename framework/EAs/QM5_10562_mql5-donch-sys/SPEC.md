# QM5_10562_mql5-donch-sys - Strategy Spec

**EA ID:** QM5_10562
**Slug:** mql5-donch-sys
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see MQL5 CodeBase source citation)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA trades the approved Donchian_Channels_System closed-bar color-change rule. A bullish color state occurs when the latest closed bar closes above the shifted Donchian upper band; a bearish color state occurs when it closes below the shifted lower band; otherwise the bar is neutral. A long opens when the latest closed bar is bullish and the previous bar was bearish or neutral, and a short opens on the mirrored bearish transition. Open positions close on an opposite Donchian color state, at the broker SL/TP, at framework Friday close, or through the framework news and kill-switch exits.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | MT5 timeframe enum | Timeframe used for Donchian color-state evaluation. |
| `strategy_donchian_period` | `20` | `>1` | Number of bars used for the Donchian high/low channel. |
| `strategy_extremes_mode` | `0` | `0..4` | Source indicator extreme mode: high/low, high/low with open/close averaging, open-only, or close-only. |
| `strategy_margins_percent` | `-2.0` | any double | Source indicator channel margin percentage applied to the upper/lower channel. |
| `strategy_channel_shift` | `2` | `>=0` | Horizontal channel shift used by the source indicator. |
| `strategy_atr_period` | `14` | `>0` | ATR period for the P2 hard stop. |
| `strategy_atr_sl_mult` | `2.0` | `>0` | ATR multiple for the hard stop. |
| `strategy_reward_r_multiple` | `1.5` | `>0` | Take-profit distance in multiples of initial risk. |
| `strategy_ema_filter_enabled` | `false` | `true/false` | Optional EMA200 trend-side filter reserved for sweeps. |
| `strategy_ema_period` | `200` | `>1` | EMA period used only when the optional trend filter is enabled. |
| `strategy_max_spread_points` | `0` | `>=0` | Optional spread block in points; `0` disables this strategy-level spread filter. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` - source test used GBPJPY H4 and the symbol is available in the DWX matrix.
- `GBPUSD.DWX` - portable FX pair from the card's R3 P2 basket.
- `EURUSD.DWX` - portable liquid FX pair from the card's R3 P2 basket.
- `XAUUSD.DWX` - portable metal symbol from the card's R3 P2 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the build registers only verified DWX symbols.

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
| Trades / year / symbol | `45` |
| Typical hold time | Several H4 bars to several days, bounded by opposite color flips and SL/TP. |
| Expected drawdown profile | Trend-breakout drawdowns should cluster in range-bound whipsaw regimes. |
| Regime preference | Donchian breakout / volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase expert / indicator source
**Pointer:** Exp_Donchian_Channels_System, Nikolay Kositsin, MQL5 CodeBase, published 2016-10-10, updated 2016-11-22, https://www.mql5.com/en/code/15900
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10562_mql5-donch-sys.md`

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
| v1 | 2026-05-29 | Initial build from card | abe45cca-ab37-477f-b90d-130b43def125 |
