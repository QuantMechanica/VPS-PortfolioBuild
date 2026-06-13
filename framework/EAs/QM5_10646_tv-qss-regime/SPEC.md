# QM5_10646_tv-qss-regime - Strategy Spec

**EA ID:** QM5_10646
**Slug:** tv-qss-regime
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades H1 long and short trend-continuation signals when the current regime, higher-timeframe EMA bias, delayed pivot structure, tick-volume participation, and session opening range all contribute to a confluence score. Long entries require bullish EMA/DMI/ADX regime evidence, H4 fast EMA above slow EMA with positive slope, and price breaking a delayed pivot high; shorts mirror those conditions below a delayed pivot low. Entries use market orders with fixed ATR(14) stop and target distances, and positions close at the configured session end, after the maximum hold bars, or when the regime or H4 bias invalidates.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_signal_tf | PERIOD_H1 | H1 or H2 intended | Base timeframe for entry, exit, ATR, ADX, structure, volume, and session logic. |
| strategy_htf | PERIOD_H4 | H1-D1 | Higher timeframe used for fast/slow EMA bias and slope confirmation. |
| strategy_fast_ema_period | 21 | 2-200 | Fast EMA period for regime and higher-timeframe bias. |
| strategy_slow_ema_period | 55 | 3-300 | Slow EMA period for regime and higher-timeframe bias. |
| strategy_adx_period | 14 | 2-100 | ADX and DI period for directional regime validation. |
| strategy_adx_threshold | 20.0 | 1.0-60.0 | Minimum ADX required for trend regime participation. |
| strategy_atr_period | 14 | 2-100 | ATR period for stop, target, and spread checks. |
| strategy_atr_sl_mult | 1.8 | 0.1-10.0 | ATR multiple for the initial stop loss. |
| strategy_atr_tp_mult | 2.8 | 0.1-20.0 | ATR multiple for the take-profit target. |
| strategy_max_stop_atr_mult | 3.5 | 0.1-20.0 | Planned stop cap expressed as ATR multiple. |
| strategy_max_spread_stop_pct | 15.0 | 0.0-100.0 | Maximum spread as a percentage of planned stop distance. |
| strategy_structure_lookback | 18 | 4-100 | Closed bars scanned for delayed pivot high and low structure. |
| strategy_volume_lookback | 20 | 1-100 | Closed bars used for average tick-volume participation. |
| strategy_min_score | 4 | 1-5 | Minimum confluence score required for long or short entry. |
| strategy_opening_range_enabled | true | true/false | Enables the session opening-range score component. |
| strategy_session_start_hour | 8 | 0-23 | Broker-hour start of the London/New York overlap baseline session. |
| strategy_opening_range_bars | 2 | 1-8 | Number of H1 bars forming the opening range after session start. |
| strategy_session_end_hour | 17 | 0-23 | Broker-hour session flattening cutoff. |
| strategy_cooldown_bars | 6 | 0-100 | Closed-bar cooldown after an exit before another entry may fire. |
| strategy_max_hold_bars | 12 | 1-200 | Maximum bars held before strategy close. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- XAUUSD.DWX - Gold is named by the card and supports OHLCV regime and ATR logic.
- EURUSD.DWX - Major FX pair named by the card and available in the DWX matrix.
- GBPUSD.DWX - Major FX pair named by the card and available in the DWX matrix.
- GDAXI.DWX - Available DAX custom symbol used as the DWX matrix equivalent for card-stated GER40.DWX.
- NDX.DWX - Nasdaq 100 index CFD named by the card and available in the DWX matrix.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; this build uses `GDAXI.DWX`.
- SPX500.DWX - not named by the card and not the canonical S&P 500 custom symbol.
- SPY.DWX - not present in the DWX symbol matrix for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | H4 fast/slow EMA bias and fast EMA slope |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through framework OnTick |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | Intraday, capped at 12 H1 bars |
| Expected drawdown profile | Bounded by fixed 1.8 ATR initial stops and one position per symbol/magic. |
| Regime preference | Trend-following / volatility-expansion regime participation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView script
**Pointer:** https://www.tradingview.com/script/vxQ5o39J-Quant-Synthesis-Strategy-JOAT/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10646_tv-qss-regime.md`

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
| v1 | 2026-06-14 | Initial build from card | 435d03ce-a2ac-4e8f-b6f1-2cbe630e8848 |
