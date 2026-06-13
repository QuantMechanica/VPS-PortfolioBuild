# QM5_10633_et-orb-5m-tqqq - Strategy Spec

**EA ID:** QM5_10633
**Slug:** et-orb-5m-tqqq
**Source:** cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64 (see `strategy-seeds/sources/cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades the direction of the first completed five-minute bar after the primary US index session open. If that first bar has a meaningful body and a range inside the ATR bounds, it enters long when the bar closes above its open and short when it closes below its open. The stop is placed beyond the first bar with a 0.10 ATR buffer, the target is 1.5R, and the strategy exits early when a later closed bar crosses back through the first bar midpoint. It also exits at session close or after 24 M5 bars, whichever comes first.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_session_start_hour | 16 | 0-23 | Broker-hour start of the mapped regular index session. |
| strategy_session_start_minute | 30 | 0-59 | Broker-minute start of the mapped regular index session. |
| strategy_session_end_hour | 23 | 0-23 | Broker-hour end of the mapped regular index session. |
| strategy_session_end_minute | 0 | 0-59 | Broker-minute end of the mapped regular index session. |
| strategy_opening_minutes | 5 | 5-15 | Opening-range bar length in minutes. |
| strategy_atr_period | 14 | 1-100 | ATR period used for doji, range, and stop-buffer checks. |
| strategy_doji_atr_fraction | 0.10 | 0.05-0.15 | Skip first bars whose body is at or below this ATR fraction. |
| strategy_stop_buffer_atr_fraction | 0.10 | 0.05-0.20 | ATR fraction added beyond the first-bar high or low for SL. |
| strategy_min_range_atr_fraction | 0.20 | 0.01-5.00 | Minimum first-bar range as an ATR fraction. |
| strategy_max_range_atr_fraction | 2.00 | 0.01-5.00 | Maximum first-bar range as an ATR fraction. |
| strategy_max_spread_range_fraction | 0.15 | 0.01-1.00 | Maximum spread as a fraction of first-bar range. |
| strategy_take_profit_rr | 1.50 | 1.00-2.00 | Take-profit multiple of initial risk. |
| strategy_time_exit_bars | 24 | 1-48 | Maximum M5 bars held after entry. |

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - Primary Nasdaq index CFD proxy for the TQQQ thesis.
- SP500.DWX - S&P 500 custom symbol comparator for backtest coverage.
- WS30.DWX - Dow 30 index CFD comparator for US large-cap breadth.

**Explicitly NOT for:**
- SPY.DWX - Not present in the DWX symbol matrix.
- TQQQ.DWX - Not present in the DWX symbol matrix; the card ports the thesis to index CFDs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | Intraday, up to 24 M5 bars or session close |
| Expected drawdown profile | Intraday breakout risk defined by first-bar structure and fixed 1.5R target. |
| Regime preference | Momentum continuation / opening-range breakout |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64
**Source type:** forum
**Pointer:** Elite Trader thread, `https://www.elitetrader.com/et/threads/opening-range-breakout-strategy.376917/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10633_et-orb-5m-tqqq.md`

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
| v1 | 2026-06-13 | Initial build from card | 0afc805f-d61a-40a5-80ab-c3668140ffe5 |
