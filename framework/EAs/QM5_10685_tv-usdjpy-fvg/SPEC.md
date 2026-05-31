# QM5_10685_tv-usdjpy-fvg - Strategy Spec

**EA ID:** QM5_10685
**Slug:** tv-usdjpy-fvg
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades three-candle fair value gap retests on the close of the current chart bar. A long entry requires a recent bullish FVG, the last closed candle to return into and close inside that gap, tick volume at least 1.5x its 20-bar average, the close above EMA(50), and a bullish candle body. A short entry mirrors the rule below EMA(50) with a bearish candle. Exits use broker SL/TP with a 2.0R target, plus a strategy time exit after 20 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_period | 50 | 1+ | EMA trend filter length. |
| strategy_atr_period | 14 | 1+ | ATR length for FVG size and stop buffer. |
| strategy_volume_avg_bars | 20 | 1+ | Lookback for tick-volume average. |
| strategy_volume_multiplier | 1.50 | 0.0+ | Required multiple of average tick volume. |
| strategy_max_fvg_age_bars | 20 | 1-80 | Maximum age of a valid FVG setup. |
| strategy_min_fvg_atr | 0.10 | 0.0+ | Minimum gap size as ATR multiple. |
| strategy_stop_buffer_atr | 0.20 | 0.0+ | Stop buffer beyond FVG boundary as ATR multiple. |
| strategy_max_stop_atr_mult | 2.50 | 0.1+ | Maximum stop distance as ATR multiple. |
| strategy_reward_r | 2.00 | 0.1+ | Take-profit multiple of initial risk. |
| strategy_max_hold_bars | 20 | 1+ | Time exit after this many chart bars. |
| strategy_tokyo_start_min | 120 | 0-1439 | Broker-time minute for Tokyo first-hour window start. |
| strategy_tokyo_end_min | 240 | 0-1440 | Broker-time minute for Tokyo first-hour window end. |
| strategy_overlap_start_min | 900 | 0-1439 | Broker-time minute for London/New York overlap start. |
| strategy_overlap_end_min | 1140 | 0-1440 | Broker-time minute for London/New York overlap end. |
| strategy_max_spread_points | 0 | 0+ | Optional spread cap; 0 disables the cap. |

---

## 3. Symbol Universe

**Designed for:**
- USDJPY.DWX - primary source pair and the card's first P2 target.
- EURUSD.DWX - liquid FX major with DWX tick volume.
- GBPUSD.DWX - liquid FX major with DWX tick volume.
- XAUUSD.DWX - canonical DWX form of the card's XAUUSD basket member.
- NDX.DWX - liquid index CFD named in the card's P2 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no verified DWX data target.
- Single stocks and crypto symbols - not present in the approved R3 basket for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 and M15 per card; smoke/setfiles use M15 baseline |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Intraday; maximum 20 bars |
| Expected drawdown profile | False fills in choppy sessions and news gaps are the main risk. |
| Regime preference | Session-concentrated FVG retest with EMA trend filter. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/tN8MbIXG-USDJPY-Fair-Value-Gap-Session-Strategy/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10685_tv-usdjpy-fvg.md`

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
| v1 | 2026-05-31 | Initial build from card | 0be519f1-27c8-4003-bf74-0a99034ea062 |
