# QM5_10082_gh-dax-adxday - Strategy Spec

**EA ID:** QM5_10082
**Slug:** gh-dax-adxday
**Source:** 3b3ec48a-0755-5187-9331-afb36e174175 (see `sources/github-mql5-stars-20`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades the DAX mapping `GDAXI.DWX` once per trading day from an M15 execution chart. At the 13:30 broker-time bar it reads the last closed D1 ADX(14) and SMA(10); it buys when ADX is above 25 and ask is above the D1 SMA, and sells when ADX is above 25 and bid is below the D1 SMA. Positions use a protective ATR stop for V5 baseline safety and close by timed strategy exit at or after 21:30 broker time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_hour_broker` | 13 | 0-23 | Broker-time hour for the daily entry check. |
| `strategy_entry_min_broker` | 30 | 0-59 | Broker-time minute for the daily entry check. |
| `strategy_close_hour_broker` | 21 | 0-23 | Broker-time hour for the timed strategy close. |
| `strategy_close_min_broker` | 30 | 0-59 | Broker-time minute for the timed strategy close. |
| `strategy_adx_period_d1` | 14 | 1+ | D1 ADX period used as the trend-strength filter. |
| `strategy_adx_threshold` | 25.0 | 0+ | Minimum D1 ADX value required to trade. |
| `strategy_sma_period_d1` | 10 | 1+ | D1 SMA period used for directional bias. |
| `strategy_atr_stop_period` | 14 | 1+ | ATR period for the protective stop. |
| `strategy_atr_stop_mult` | 1.5 | 0+ | ATR multiple for the protective stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` - direct DWX DAX mapping from the card's DAX source instrument.

**Explicitly NOT for:**
- `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `UK100.DWX` - not listed in the card's R3 portable basket for this source.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | D1 ADX(14), D1 SMA(10), current-chart ATR protective stop |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Intraday, from 13:30 to 21:30 broker time |
| Expected drawdown profile | Protective ATR stop limits baseline adverse moves; timed close limits overnight exposure. |
| Regime preference | Intraday directional trend-strength filter |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3b3ec48a-0755-5187-9331-afb36e174175
**Source type:** GitHub repository source file
**Pointer:** https://github.com/victor-algo/channel/blob/main/LIVE%20BOT%20-%20Cr%C3%A9ation%20de%20trading%20bot%20from%20scratch/Daily%20Dax/Expert/daily-dax.mq5
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10082_gh-dax-adxday.md`

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
| v1 | 2026-06-11 | Initial build from card | f107e2ce-6e1e-4107-a3b5-cc3750ee0ab3 |
