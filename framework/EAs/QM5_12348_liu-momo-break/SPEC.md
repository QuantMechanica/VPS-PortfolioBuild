# QM5_12348_liu-momo-break - Strategy Spec

**EA ID:** QM5_12348
**Slug:** liu-momo-break
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades a long-only M1 opening-range breakout. It records the first 15 minutes of the mapped session, then buys at market during the next 60 minutes when the last closed M1 bar closes above that range high, MACD is positive and rising, MACD is above its signal by the configured multiplier, MACD histogram is rising, fallback intrabar momentum is positive, and RSI(20) is below 75.

The stop is entry minus 1.5 x ATR(14), and the target is 3R. Discretionary exits close the position when RSI reaches the source sell threshold, when price is at or above target while MACD is non-positive, or when MACD drops below signal after favorable movement.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_opening_range_minutes | 15 | 1-120 | Number of M1 bars used to define the opening high. |
| strategy_entry_window_minutes | 60 | 1-240 | Minutes after the opening range when new long entries may occur. |
| strategy_eu_session_open_hhmm | 1000 | 0000-2359 | Broker-time open used for DAX and FX symbols. |
| strategy_us_session_open_hhmm | 1630 | 0000-2359 | Broker-time open used for US indices and XAUUSD. |
| strategy_macd_fast | 12 | 1-100 | MACD fast EMA period. |
| strategy_macd_slow | 26 | 2-200 | MACD slow EMA period. |
| strategy_macd_signal | 9 | 1-100 | MACD signal period. |
| strategy_macd_signal_mult | 1.10 | 0.1-5.0 | Required MACD main value versus signal multiplier. |
| strategy_rsi_period | 20 | 2-100 | RSI lookback for entry and exit checks. |
| strategy_rsi_entry_max | 75.0 | 1-100 | Maximum RSI allowed for entry. |
| strategy_rsi_exit_morning | 85.0 | 1-100 | RSI exit threshold during the morning-rush window. |
| strategy_rsi_exit_other | 79.0 | 1-100 | RSI exit threshold after the morning-rush window. |
| strategy_morning_rush_minutes | 60 | 1-240 | Minutes after session open treated as morning rush. |
| strategy_atr_period | 14 | 1-100 | ATR lookback for the initial stop. |
| strategy_atr_stop_mult | 1.50 | 0.1-10.0 | ATR multiple subtracted from entry for the stop. |
| strategy_reward_risk | 3.00 | 0.1-10.0 | Take-profit distance as a multiple of initial risk. |
| strategy_max_spread_points | 0.0 | 0 disables, otherwise positive | Optional spread cap in points before new entries. |

---

## 3. Symbol Universe

**Designed for:**
- GDAXI.DWX - canonical DWX DAX symbol used as the available substitute for the card's GER40.DWX.
- NDX.DWX - US large-cap index exposure with US opening-session behaviour.
- WS30.DWX - US large-cap index exposure with US opening-session behaviour.
- XAUUSD.DWX - liquid metal CFD with opening momentum behaviour mapped to the US session.
- EURUSD.DWX - liquid FX major mapped to the London/Europe session.
- GBPUSD.DWX - liquid FX major mapped to the London/Europe session.

**Explicitly NOT for:**
- GER40.DWX - requested by the card but not present in `framework/registry/dwx_symbol_matrix.csv`.
- SP500.DWX - optional backtest-only symbol in the card, not part of the primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | Intraday, usually minutes to a few opening-session hours |
| Expected drawdown profile | Breakout losses cluster during failed opening momentum and gap-heavy sessions |
| Regime preference | Opening-session momentum and volatility expansion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** GitHub repository example
**Pointer:** https://github.com/amor71/LiuAlgoTrader/blob/master/examples/quickstart/momentum_long_simplified.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12348_liu-momo-break.md`

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
| v1 | 2026-06-11 | Initial build from card | 70df99e9-90fc-45bf-ade0-8d5878e579c7 |
