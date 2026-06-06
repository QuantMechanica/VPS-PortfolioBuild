# QM5_10913_grimes-snap-pb - Strategy Spec

**EA ID:** QM5_10913
**Slug:** grimes-snap-pb
**Source:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades a reversal snap-pullback pattern on H1 closes. A long setup requires an old downtrend by EMA(50), a fresh 20-bar low that fails to continue lower within five bars, a bullish snap bar closing above EMA(20) with body at least 1.2 ATR(14), then a 2-8 bar reluctant pullback that retraces less than half of the snap range and does not close below the snap low. The EA enters long when the last closed H1 bar breaks above the pullback range high; shorts mirror the same rules after an old uptrend, failed 20-bar high continuation, bearish snap, reluctant bounce, and break below the pullback range low. Stops sit beyond the pullback extreme by 0.2 ATR(14), targets use the larger of the measured snap range or 1R, and positions time out after 12 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_trend_period | 50 | 2-200 | EMA period used to verify the old trend. |
| strategy_ema_snap_period | 20 | 2-100 | EMA period the countertrend snap bar must close through. |
| strategy_atr_period | 14 | 2-100 | ATR period used for snap body, stop buffer, and stop-distance filter. |
| strategy_trend_count_bars | 15 | 1-60 | Prior bars counted for old-trend close-below or close-above validation. |
| strategy_trend_min_closes | 10 | 1-60 | Minimum closes on the trend side of EMA(50). |
| strategy_extreme_lookback_bars | 20 | 2-100 | Lookback used to define the failed 20-bar low or high. |
| strategy_failure_window_bars | 5 | 1-20 | Bars after the 20-bar extreme where continuation must fail. |
| strategy_min_pullback_bars | 2 | 1-20 | Minimum reluctant pullback length after the snap bar. |
| strategy_max_pullback_bars | 8 | 1-30 | Maximum reluctant pullback length after the snap bar. |
| strategy_snap_body_atr_mult | 1.20 | 0.1-5.0 | Minimum snap-bar body as a multiple of ATR(14). |
| strategy_pullback_max_retrace | 0.50 | 0.1-0.9 | Maximum retracement fraction of the snap bar range. |
| strategy_stop_buffer_atr_mult | 0.20 | 0.0-2.0 | ATR buffer beyond the pullback low or high for the stop. |
| strategy_max_stop_atr_mult | 2.50 | 0.5-10.0 | Maximum accepted stop distance as an ATR multiple. |
| strategy_time_exit_bars | 12 | 1-100 | Maximum hold time in H1 bars. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - card-listed S&P 500 proxy; valid DWX custom symbol for backtest-only index exposure.
- NDX.DWX - card-listed Nasdaq 100 proxy with DWX data and live-tradable large-cap index exposure.
- WS30.DWX - card-listed Dow 30 proxy with DWX data and live-tradable large-cap index exposure.
- XAUUSD.DWX - card-listed metal with DWX data and active-market volatility suitable for snap-pullbacks.

**Explicitly NOT for:**
- SPX500.DWX, SPY.DWX, ES.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; SP500.DWX is the canonical available S&P 500 custom symbol.

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
| Trades / year / symbol | 18 |
| Typical hold time | Up to 12 H1 bars |
| Expected drawdown profile | Reversal drawdowns cluster when the countertrend snap fails and the prior trend resumes. |
| Regime preference | Trend-reversal after impulse and reluctant pullback |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Source type:** blog
**Pointer:** Adam H. Grimes, "The Anti: a trading lesson from ROKU" and "Selective Intraday Trades: A Deep Dive Into the Snap Pullback"
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10913_grimes-snap-pb.md`

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
| v1 | 2026-06-06 | Initial build from card | c5371b76-c933-41dd-b28b-49d53447cd49 |
