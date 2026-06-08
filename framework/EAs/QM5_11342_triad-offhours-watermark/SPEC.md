# QM5_11342_triad-offhours-watermark - Strategy Spec

**EA ID:** QM5_11342
**Slug:** triad-offhours-watermark
**Source:** 581facd5-aecc-5b86-8121-1eaa3eaf1a45
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

The EA trades the off-hours watermark fade described in the approved Triad card. After the session-start H1 bar closes, it records that bar's high and low as watermarks, then places a sell limit at the high watermark and a buy limit at the low watermark. Each order uses a 12-pip take profit and a 12-pip stop capped at 0.5 x ATR(14,H1); any open position is closed when the broker-time session window ends.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_session_start_hour_broker | 20 | 0-23 | Standard broker-hour session start for the setup bar. |
| strategy_session_end_hour_broker | 0 | 0-23 | Standard broker-hour hard session end. |
| strategy_use_us_dst_session_hours | true | true/false | Switches to the DST session hours between the US DST start and end dates. |
| strategy_dst_session_start_hour_broker | 19 | 0-23 | Broker-hour session start during US DST. |
| strategy_dst_session_end_hour_broker | 23 | 0-23 | Broker-hour hard session end during US DST. |
| strategy_tp_pips | 12 | 8-15 | Fixed take-profit distance in pips. |
| strategy_sl_pips | 12 | 8-15 | Fixed stop-loss distance in pips before the ATR cap. |
| strategy_atr_period | 14 | 5-50 | ATR period used for the stop cap. |
| strategy_atr_sl_cap_mult | 0.5 | 0.1-2.0 | Maximum stop distance as a multiple of ATR(14,H1). |
| strategy_spread_cap_pips | 3 | 1-10 | Maximum allowed spread when arming the session orders. |
| strategy_min_watermark_range_pips | 3 | 1-20 | Minimum setup-bar high-low range required to define watermarks. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed major FX pair with H1 DWX data.
- GBPUSD.DWX - card-listed major FX pair with H1 DWX data.
- USDJPY.DWX - card-listed major FX pair with H1 DWX data.

**Explicitly NOT for:**
- Index, metal, energy, or non-FX `.DWX` symbols - the card specifies only EURUSD, GBPUSD, and USDJPY.
- FX symbols not listed above - not part of the approved R3 symbol basket for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | ATR(14,H1) only |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 200 |
| Typical hold time | Same off-hours session, capped at roughly 4 hours |
| Expected drawdown profile | Frequent small fixed-pip losses during dead-time continuation moves |
| Regime preference | Mean-reversion in low-directional-liquidity off-hours conditions |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 581facd5-aecc-5b86-8121-1eaa3eaf1a45
**Source type:** book/PDF
**Pointer:** Jason Fielder, Triad Cheat Sheets, Cheat Sheet #1 Strategy #1 - Off-Hours Counter-Trend Scalping, local PDF `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\254938836-TriadCheatSheets-pdf.pdf`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11342_triad-offhours-watermark.md`

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
| v1 | 2026-06-08 | Initial build from card | c93db9e3-04be-46dc-8e57-5631b90d6d0c |
