# QM5_9357_mql5-orb-break — Strategy Spec

**EA ID:** QM5_9357
**Slug:** `mql5-orb-break`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

Opening Range Breakout (ORB) on M5. At the configured session start time (default 09:30 broker time), the EA records the high and low of the first 15 minutes of trading (the "opening range"). After that 15-minute window closes, the EA monitors each newly-closed M5 candle.

Long entry: a bullish M5 candle (close > open) closes above the opening-range high.
Short entry: a bearish M5 candle (close < open) closes below the opening-range low.

Only the first breakout signal of the day is taken — one active position per magic per day. Stop loss is placed at the opposite side of the opening range (long SL = OR low, short SL = OR high). Take profit is set at 2× the range width beyond the entry side (2R). Any open position is closed at session end regardless of SL/TP.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_session_start_hour` | 9 | 0-23 | Broker-time hour of session open / OR start |
| `strategy_session_start_min` | 30 | 0-59 | Broker-time minute of session open |
| `strategy_session_end_hour` | 17 | 0-23 | Broker-time hour at which open positions are closed |
| `strategy_session_end_min` | 30 | 0-59 | Broker-time minute for session end |
| `strategy_or_minutes` | 15 | 5-60 | Duration of opening range in minutes |
| `strategy_rr_ratio` | 2.0 | 1.0-5.0 | Risk-to-reward ratio for TP (multiplier on range width) |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` — US tech index; active intraday breakout around NY open
- `WS30.DWX` — US30 index; correlated NY-session momentum
- `XAUUSD.DWX` — Gold; strong intraday momentum after major session opens

**Explicitly NOT for:**
- `GER40.DWX` — Not present in dwx_symbol_matrix.csv (GDAXI.DWX is the verified DAX symbol); card lists GER40 but it is unverified in the matrix. Open question filed.
- FX pairs — Intraday range breakout on M5 for FX requires different session calibration; not targeted by this card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~120 |
| Typical hold time | 1-8 hours (intraday, closed at session end) |
| Expected drawdown profile | Moderate intraday drawdown; sessions close out all exposure |
| Regime preference | breakout / intraday-momentum |
| Win rate target (qualitative) | medium (2R target; ~40-50% win rate breakeven) |

---

## 6. Source Citation

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** forum / article
**Pointer:** https://www.mql5.com/en/articles/19886
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9357_mql5-orb-break.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-10 | Initial build from card | agents/board-advisor |
