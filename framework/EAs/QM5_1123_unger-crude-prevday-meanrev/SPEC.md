# QM5_1123_unger-crude-prevday-meanrev - Strategy Spec

**EA ID:** QM5_1123
**Slug:** unger-crude-prevday-meanrev
**Source:** eb97a148-0af9-5b9c-878c-25fb5dfa34f9
**Author of this spec:** Codex
**Last revised:** 2026-07-14

---

## 1. Strategy Logic

This EA trades M15 crude-oil mean reversion on XTIUSD.DWX. It computes the lower trigger as the lower of yesterday's low and the low from five trading sessions earlier, and the upper trigger as the higher of yesterday's high and the high from five trading sessions earlier. A long entry occurs when the last closed M15 bar trades below the lower trigger and closes back above it; a short entry occurs when the bar trades above the upper trigger and closes back below it. Positions use a 1.5 x ATR(14,M15) stop and are flattened before the configured session end. One trade per direction per day; a same-day stopout blocks further entries (either direction) for the rest of that day.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_atr_period | 14 | 2-100 | ATR period for M15 stop distance and D1 volatility filter. |
| strategy_atr_sl_mult | 1.5 | 0.1-10.0 | Stop distance multiplier applied to ATR(14,M15). |
| strategy_use_vwap_target | true | true/false | Use prior-day typical price (H+L+C)/3 as the mean-reversion target. |
| strategy_tp_rr | 1.0 | 0.1-10.0 | R-multiple target when the VWAP proxy target is disabled. |
| strategy_atr_percentile_lookback | 120 | 20-300 | Number of D1 ATR observations for the volatility percentile filter. |
| strategy_atr_percentile_pct | 25.0 | 0-100 | Skip trading when current D1 ATR is below this percentile. |
| strategy_skip_eia_day | true | true/false | Skip the configured EIA inventory release weekday. |
| strategy_eia_day_of_week | 3 | 0-6 | Broker weekday to suppress for EIA inventory day, Sunday=0. |
| strategy_session_start_hhmm | 0 | 0-2359 | Earliest broker-time HHMM for new entries. |
| strategy_flatten_hhmm | 2200 | 0-2359 | Broker-time HHMM for end-of-day flatten and entry cutoff. |
| strategy_max_spread_points | 80 | 0-10000 | Maximum modeled spread in points; zero spread is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- XTIUSD.DWX - Darwinex crude-oil CFD named in the approved card and present in the DWX symbol matrix.

**Explicitly NOT for:**
- XNGUSD.DWX - Energy market but natural gas, not crude oil.
- XAUUSD.DWX - Commodity market but metal, not crude oil.
- SP500.DWX - Index CFD; does not match the card's crude-oil session and inventory-day premise.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | D1 previous-day and five-session high/low; D1 ATR percentile filter |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) via the framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | Intraday, closed before session end |
| Expected drawdown profile | Sparse mean-reversion losses during sustained energy trends or inventory shocks |
| Regime preference | Intraday mean-reversion in sufficiently active crude-oil volatility regimes |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** eb97a148-0af9-5b9c-878c-25fb5dfa34f9
**Source type:** Unger Academy article and supporting book citation
**Pointer:** https://ungeracademy.com/blog/crude-oil-strategies-live-since-2017-and-still-profiting-let-s-see-the-results
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1123_unger-crude-prevday-meanrev.md`

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
| v1 | 2026-06-18 | Initial build from card | bca28a74-ea76-480d-b4b7-7698e98562c8 |
| v2 | 2026-07-14 | DL-069 rebuild in place: fixed pre-2026-07-02-audit OnTick news-gate ordering (news gate was blocking position management/exit, not just new entries); replaced raw iHigh/iLow/iClose reads with the sanctioned QM_ReadBar helper; D1 cadence now uses QM_IsNewCalendarPeriod instead of ad hoc day-key math; same-day-stopout detection now uses HistorySelectByPosition on the tracked position rather than a full HistorySelect day-scan every entry check. Strategy mechanics unchanged from the card. | build task e9226b0c-21b1-4e7d-afd6-7560e8cc017e |
