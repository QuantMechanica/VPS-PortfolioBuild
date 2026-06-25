# QM5_11445_burke-low-hanging-fruit-m5 - Strategy Spec

**EA ID:** QM5_11445
**Slug:** burke-low-hanging-fruit-m5
**Source:** 04305b6c-b4ce-522b-87b5-71708b6b8327 (see `strategy-seeds/sources/04305b6c-b4ce-522b-87b5-71708b6b8327/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades M5 continuation entries during the London and New York UTC sessions. It tracks the rolling session high and low from closed M5 closes; a long setup arms when a bar makes a new session high, then price pulls back 25-50 pips and closes back above EMA20. A short setup mirrors this from a new session low, a 25-50 pip retracement upward, and a close back below EMA20. Each session allows only one re-entry attempt, with a 20 pip stop and a target based on half of D1 ATR(14), bounded by the card's 25-100 pip TP range and defaulting around the 50 pip primary target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_signal_tf | PERIOD_M5 | M5 expected | Timeframe used for session state and EMA trigger |
| strategy_london_start_utc | 7 | 0-23 | London session start hour in UTC |
| strategy_london_end_utc | 12 | 1-24 | London session end hour in UTC, exclusive |
| strategy_ny_start_utc | 13 | 0-23 | New York session start hour in UTC |
| strategy_ny_end_utc | 17 | 1-24 | New York session end hour in UTC, exclusive |
| strategy_ema_period | 20 | 13-34 sweep candidate | EMA close-back trigger period |
| strategy_pullback_min_pips | 25 | 15-30 sweep candidate | Minimum retracement from HOD/LOD break level |
| strategy_pullback_max_pips | 50 | 40-60 sweep candidate | Maximum retracement from HOD/LOD break level |
| strategy_sl_pips | 20 | 15-25 | Fixed stop distance in pips |
| strategy_tp_primary_pips | 50 | 30-75 sweep candidate | Fallback and primary target in pips |
| strategy_use_d1_atr_tp | true | true/false | Use half of D1 ATR(14) as session range proxy for TP |
| strategy_d1_atr_period | 14 | 14 fixed | D1 ATR period for target proxy |
| strategy_tp_min_pips | 25 | 25 fixed | Lower bound for ATR-derived TP |
| strategy_tp_max_pips | 100 | 100 fixed | Upper bound for ATR-derived TP |
| strategy_spread_cap_pips | 15 | 0-15 | Blocks only genuinely wider spreads; zero modeled spread is allowed |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-stated M5 DWX FX target
- GBPUSD.DWX - card-stated M5 DWX FX target
- USDJPY.DWX - card-stated M5 DWX FX target
- AUDUSD.DWX - card-stated M5 DWX FX target
- USDCAD.DWX - card-stated M5 DWX FX target

**Explicitly NOT for:**
- Non-FX `.DWX` indices or commodities - the card defines a major-FX session HOD/LOD continuation setup

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | D1 ATR(14) for TP proxy |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | intraday session continuation, usually minutes to hours |
| Expected drawdown profile | fixed 20 pip stop with one attempt per session limits clustering |
| Regime preference | trend-following / session breakout continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 04305b6c-b4ce-522b-87b5-71708b6b8327
**Source type:** self-published trading playbook
**Pointer:** `707586131-1-Stacey-Burke-Best-Trade-Setups-Playbook-Notes-Part-2.pdf`, Part 2 pages 51-106
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11445_burke-low-hanging-fruit-m5.md`

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
| v1 | 2026-06-25 | Initial build from card | 723ed9a3-5575-44a1-b9b2-056d75a1410a |
