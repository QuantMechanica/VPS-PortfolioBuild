# QM5_10769_tv-axis-rev - Strategy Spec

**EA ID:** QM5_10769
**Slug:** tv-axis-rev
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA tracks local axis levels as the highest high and lowest low over a configurable closed-bar sensitivity window. A long standby is armed when the last closed bar breaches the lower axis, RSI has touched the oversold threshold inside the configured synchronization window, and entry fires only when Supertrend flips bullish on a confirmed bar. Short entries mirror the rule after an upper-axis breach, recent overbought RSI, and a bearish Supertrend flip. Stops are placed beyond the breached axis extreme with an ATR buffer, and targets use a fixed R multiple from entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_axis_sensitivity | 20 | 10-40 test grid | Closed-bar highest/lowest window used to define local axis levels. |
| strategy_rsi_period | 14 | 14-21 test grid | RSI period for oversold and overbought synchronization. |
| strategy_rsi_long_threshold | 30.0 | 25-35 test grid | Long setup requires RSI to touch this value or lower. |
| strategy_rsi_short_threshold | 70.0 | 65-75 test grid | Short setup requires RSI to touch this value or higher. |
| strategy_rsi_sync_bars | 3 | 1-5 test grid | Number of closed bars in which the RSI touch remains valid. |
| strategy_supertrend_atr_period | 10 | 10-14 test grid | ATR period used by the Supertrend trigger. |
| strategy_supertrend_multiplier | 3.0 | 2.0-4.0 test grid | ATR multiplier used by the Supertrend trigger. |
| strategy_supertrend_warmup_bars | 80 | 40-160 | Closed-bar warmup length for Supertrend state reconstruction. |
| strategy_atr_stop_period | 14 | 14 baseline | ATR period for the axis stop buffer. |
| strategy_atr_stop_buffer | 0.5 | 0.25-1.0 test grid | ATR multiple added beyond the breached axis extreme for the stop. |
| strategy_rr_target | 2.0 | 1.5-2.5 test grid | Fixed reward-to-risk target multiple. |
| strategy_exit_on_opposite_supertrend | false | false/true | Optional exit on opposite Supertrend flip; default exits by SL/TP and Friday close only. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - FX major with portable OHLC, RSI, ATR, and Supertrend inputs.
- GBPUSD.DWX - FX major with similar volatility and liquidity profile.
- USDJPY.DWX - FX major from the approved R3 basket.
- XAUUSD.DWX - Gold port for the card's `XAUUSD` basket item.
- GDAXI.DWX - Canonical DWX DAX symbol, used for the card's `GER40.DWX` basket item.
- NDX.DWX - Nasdaq 100 index CFD from the approved R3 basket.
- WS30.DWX - Dow 30 index CFD from the approved R3 basket.

**Explicitly NOT for:**
- GER40.DWX - Not present in `dwx_symbol_matrix.csv`; use GDAXI.DWX.
- Symbols outside `dwx_symbol_matrix.csv` - not valid for DWX backtest registration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15, H1, H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` wiring |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 90 |
| Expected trade frequency | Around 90 trades per year per symbol from card frontmatter |
| Typical hold time | Intraday to multi-session, until 2R target, ATR-axis stop, Friday close, or optional opposite Supertrend exit |
| Expected drawdown profile | Mean-reversion drawdowns during sustained one-way trend without reversal confirmation |
| Regime preference | Mean-reversion after liquidity sweep with Supertrend confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy script
**Pointer:** TradingView script `AXIS REVERSAL`, author handle `egoigor1976`; approved card at `artifacts/cards_approved/QM5_10769_tv-axis-rev.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10769_tv-axis-rev.md`

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
| v1 | 2026-05-31 | Initial build from card | e6a0728c-e2b3-4716-8b36-8fc5afb0223b |
