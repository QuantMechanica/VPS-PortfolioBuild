# QM5_10747_tv-vwap-ema-pb - Strategy Spec

**EA ID:** QM5_10747
**Slug:** `tv-vwap-ema-pb`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades the M15 VWAP/EMA pullback rule from the approved card. A long entry requires the last closed bar to be above cached same-session VWAP, EMA(9) above EMA(21), a pullback touch of VWAP or the EMA zone, a close back above EMA(9), RSI(14) above 50, and ADX(14) at least 20 with +DI above -DI. Shorts mirror the same logic below VWAP with EMA(9) below EMA(21), RSI below 50, and -DI above +DI. Exits are the card's ATR stop, 2.0R target, framework Friday close, and session-end close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_ema_period` | 9 | 2-100 | Fast EMA used for trend and reclaim/rejection confirmation. |
| `strategy_slow_ema_period` | 21 | 3-200 | Slow EMA used with the fast EMA to define trend and the EMA pullback zone. |
| `strategy_rsi_period` | 14 | 2-100 | RSI lookback for directional confirmation. |
| `strategy_rsi_midline` | 50.0 | 1.0-99.0 | RSI threshold above for longs and below for shorts. |
| `strategy_adx_period` | 14 | 2-100 | ADX/DMI lookback for trend-strength and direction filtering. |
| `strategy_adx_min` | 20.0 | 1.0-100.0 | Minimum ADX value required before entry. |
| `strategy_atr_period` | 14 | 2-100 | ATR lookback used for stop distance. |
| `strategy_atr_sl_mult` | 1.5 | 0.1-10.0 | ATR multiplier for the initial stop. |
| `strategy_reward_risk` | 2.0 | 0.1-10.0 | Full-position take-profit multiple of initial risk. |
| `strategy_session_start_hour` | 7 | 0-23 | Broker-hour start of the active session. |
| `strategy_session_end_hour` | 20 | 0-23 | Broker-hour end of the active session. |
| `strategy_max_spread_points` | 0.0 | 0.0+ | Optional spread gate; 0 disables it. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - liquid index CFD compatible with the card's VWAP/EMA intraday trend-pullback mechanics.
- `GDAXI.DWX` - matrix-verified DAX custom symbol used as the canonical DWX equivalent for the card's `GER40.DWX`.
- `XAUUSD.DWX` - liquid metal CFD with M15 tick-volume VWAP, EMA, RSI, ADX, and ATR data available.
- `EURUSD.DWX` - liquid forex pair with M15 tick-volume VWAP, EMA, RSI, ADX, and ATR data available.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` |
| Typical hold time | Intraday, normally minutes to hours within the 07:00-20:00 broker session |
| Expected drawdown profile | Trend-pullback losses should be bounded by 1.5 ATR initial stop and fixed 2.0R target. |
| Regime preference | Trend-following pullback during liquid intraday sessions |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy script
**Pointer:** TradingView script `AVS VWAP EMA Pullback Pro`, author handle `anna797979`, updated 2026-04-16.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10747_tv-vwap-ema-pb.md`

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
| v1 | 2026-06-14 | Initial build from card | a1c09790-9129-4b0b-b9b2-aa6cd591f689 |
