# QM5_10783_tv-bos-forex - Strategy Spec

**EA ID:** QM5_10783
**Slug:** tv-bos-forex
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades a close-confirmed break of the most recent prior swing structure on the chart timeframe. It enters long when the last closed bar closes above the previous swing high during the configured long session, and enters short when the last closed bar closes below the previous swing low during the configured short session. Stops use the wider of the opposite recent swing or ATR(14) times the configured multiplier, and targets use a fixed R multiple. The EA can optionally flatten on an opposite cached BOS signal, and by default it exits at the end of the configured session.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_swing_lookback_bars | 10 | 5-20 tested | Maximum closed bars scanned for the previous swing high and low. |
| strategy_swing_strength_bars | 2 | 1+ | Bars required on both sides of a pivot swing. |
| strategy_atr_period | 14 | 1+ | ATR period for the volatility stop component. |
| strategy_atr_stop_mult | 1.5 | 1.5-2.0 tested | ATR multiplier for the volatility stop component. |
| strategy_target_r_multiple | 2.0 | 1.5-3.0 tested | Fixed reward-to-risk target multiple. |
| strategy_long_start_hour | 7 | 0-23 | Broker hour when long entries become permitted. |
| strategy_long_end_hour | 21 | 0-23 | Broker hour when long entries stop being permitted. |
| strategy_short_start_hour | 7 | 0-23 | Broker hour when short entries become permitted. |
| strategy_short_end_hour | 21 | 0-23 | Broker hour when short entries stop being permitted. |
| strategy_max_spread_points | 35 | 0+ | Maximum allowed spread in points; zero disables this filter. |
| strategy_opposite_bos_exit | false | true / false | Enables discretionary exit on a cached opposite BOS signal. |
| strategy_session_end_flat | true | true / false | Closes open positions when their direction's session window ends. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - forex major explicitly fits the card's forex BOS/session premise.
- GBPUSD.DWX - forex major explicitly fits the card's forex BOS/session premise.
- USDJPY.DWX - forex major explicitly fits the card's forex BOS/session premise.
- AUDUSD.DWX - forex major explicitly fits the card's forex BOS/session premise.
- USDCAD.DWX - forex major explicitly fits the card's forex BOS/session premise.
- XAUUSD.DWX - DWX matrix equivalent for the card's bare XAUUSD basket item.

**Explicitly NOT for:**
- Non-DWX symbols - build and backtest artifacts must use canonical DWX symbols.
- Equity index symbols - the approved card is forex-oriented and the P2 basket is FX/metals only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 and H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | Intraday session hold, usually minutes to hours |
| Expected drawdown profile | Breakout systems can cluster losses during choppy non-expansion periods |
| Regime preference | Breakout / volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView invite-only strategy page
**Pointer:** TradingView script "Break of structure (BOS) forex Strategy", author TJalam
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10783_tv-bos-forex.md`

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
| v1 | 2026-06-14 | Initial build from card | 91d4e53d-473e-4dc7-a20e-5b0655f94c06 |
