# QM5_10971_ftmo-flag-brk — Strategy Spec

**EA ID:** QM5_10971
**Slug:** ftmo-flag-brk
**Source:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades H1 flag and pennant continuation breakouts after a sharp impulse. A bullish setup requires a 3-10 bar upward pole of at least 2.0 ATR(14), price above EMA(100), a 4-16 bar consolidation retracing 20%-60% of the pole, and a closed H1 candle above the consolidation high. A bearish setup mirrors the same rules below EMA(100), with entry on a closed H1 candle below the consolidation low. Stops sit beyond the consolidation by 0.25 ATR, targets project the pole from breakout capped at 3.0R, and positions time-exit after 24 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_atr_period | 14 | >0 | ATR period for pole size, stop buffer, and breakout candle filter. |
| strategy_ema_period | 100 | >0 | EMA trend filter period on H1 closes. |
| strategy_min_pole_bars | 3 | 1-10 | Minimum impulse pole length in H1 bars. |
| strategy_max_pole_bars | 10 | 3-50 | Maximum impulse pole length in H1 bars. |
| strategy_min_consolidation_bars | 4 | 1-16 | Minimum flag or pennant consolidation length in H1 bars. |
| strategy_max_consolidation_bars | 16 | 4-50 | Maximum flag or pennant consolidation length in H1 bars. |
| strategy_min_pole_atr_mult | 2.0 | >0 | Minimum pole distance as ATR multiple. |
| strategy_min_retrace_pct | 20.0 | 0-100 | Minimum consolidation retracement of the pole. |
| strategy_max_retrace_pct | 60.0 | 0-100 | Maximum consolidation retracement of the pole. |
| strategy_max_cons_range_pole_pct | 75.0 | 0-100 | Maximum consolidation range as a percentage of pole length. |
| strategy_sl_atr_buffer | 0.25 | >=0 | ATR buffer added beyond consolidation high or low for SL. |
| strategy_breakout_max_atr_mult | 2.0 | >0 | Maximum breakout candle range as ATR multiple. |
| strategy_tp_rr_fallback | 2.2 | >0 | Fallback target R multiple if measured pole projection is invalid. |
| strategy_tp_rr_cap | 3.0 | >0 | Maximum target R multiple. |
| strategy_time_exit_bars | 24 | >0 | Maximum hold time in H1 bars. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX — card R3 includes liquid FX major exposure for H1 flag breakouts.
- GBPUSD.DWX — card R3 includes liquid FX major exposure for H1 flag breakouts.
- XAUUSD.DWX — card R3 includes metal exposure where impulse-consolidation breakouts are testable.
- NDX.DWX — card R3 includes liquid index exposure for H1 continuation breakouts.

**Explicitly NOT for:**
- Symbols outside the approved R3 basket — not registered for this EA in `magic_numbers.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | Up to 24 H1 bars by card time exit |
| Expected drawdown profile | Continuation breakout drawdowns during failed impulse follow-through and choppy consolidation regimes |
| Regime preference | Trend-following breakout after volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Source type:** blog
**Pointer:** FTMO Australia, "How to trade chart patterns?", sections "Bearish/Bullish Flag" and "Bearish/Bullish Pennant"
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10971_ftmo-flag-brk.md`

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
| v1 | 2026-06-06 | Initial build from card | bbea8ab8-ac5f-42b9-b9b0-e130aaef66b4 |
