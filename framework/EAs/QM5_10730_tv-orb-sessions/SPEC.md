# QM5_10730_tv-orb-sessions - Strategy Spec

**EA ID:** QM5_10730
**Slug:** tv-orb-sessions
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA builds an opening range from the first 15 minutes of the selected broker-time session. After the range is locked, a long setup starts when a closed M5 candle closes above the opening-range high; a later closed candle must wick back to that broken high and close back above it before the EA buys. A short setup mirrors this below the opening-range low. The stop is the opposite side of the opening range, the first target is handled by a one-time partial close at 1R, the final broker TP is 2R, and any open position is closed at session end.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_session_module | SESSION_NY | SESSION_ASIA, SESSION_LONDON, SESSION_NY | Enables exactly one ORB session module for a run. |
| strategy_or_minutes | 15 | 5-120 | Opening range duration in minutes. |
| strategy_asia_or_start_hhmm | 100 | 0000-2359 | Broker-time Asia OR start. |
| strategy_london_or_start_hhmm | 900 | 0000-2359 | Broker-time London OR start. |
| strategy_ny_or_start_hhmm | 1530 | 0000-2359 | Broker-time New York OR start. |
| strategy_asia_session_end_hhmm | 900 | 0000-2359 | Broker-time Asia flat time. |
| strategy_london_session_end_hhmm | 1730 | 0000-2359 | Broker-time London flat time. |
| strategy_ny_session_end_hhmm | 2200 | 0000-2359 | Broker-time New York flat time. |
| strategy_atr_period | 14 | 2-200 | ATR period used only to reject excessive opening-range width. |
| strategy_max_or_atr_mult | 3.00 | 0.1-10.0 | Skip the session if OR width exceeds this ATR multiple. |
| strategy_tp1_close_fraction | 0.50 | 0.0-1.0 | Fraction of the open position to close at 1R when volume permits. |
| strategy_tp2_reward_risk | 2.00 | 0.5-10.0 | Final take-profit distance in R multiples. |
| strategy_max_spread_points | 0 | 0-100000 | Optional spread gate; 0 disables the gate. |

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - Nasdaq index exposure from the card basket.
- WS30.DWX - Dow index exposure from the card basket.
- GDAXI.DWX - matrix-verified DAX equivalent for the card's GER40.DWX target.
- GBPUSD.DWX - FX session-breakout exposure from the card basket.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; use GDAXI.DWX.
- Non-DWX symbols - V5 build and backtest artifacts require the `.DWX` suffix.

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
| Trades / year / symbol | 120 |
| Expected trade frequency | Multi-session ORB with one baseline trade cap per session; conservative estimate 90-180 trades/year/symbol. |
| Typical hold time | Not specified in card; intraday from retest entry until SL, TP, partial/final target, or session-end flat. |
| Expected drawdown profile | Breakout/retest strategy with losses capped by the opposite opening-range side. |
| Regime preference | Opening-range/session breakout with volatility expansion after the range locks. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy script
**Pointer:** TradingView script `ORB SESSIONS`, author handle `VONKAR`, public page cited in `artifacts/cards_approved/QM5_10730_tv-orb-sessions.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10730_tv-orb-sessions.md`

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
| v1 | 2026-06-14 | Initial build from card | d65942a9-d07d-4fbf-a824-85b9279f8180 |
