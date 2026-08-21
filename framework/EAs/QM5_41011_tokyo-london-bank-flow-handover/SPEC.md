# QM5_41011_tokyo-london-bank-flow-handover — Strategy Spec

**EA ID:** QM5_41011
**Slug:** tokyo-london-bank-flow-handover
**Source:** tokyo-london-bank-flow-handover-official-source
**Author of this spec:** Gemini
**Last revised:** 2026-08-18

---

## 1. Strategy Logic

Quantitative interbank liquidity handover breakout model on JPY crosses (EURJPY, GBPJPY, USDJPY) operating on M15 bars. The EA quantifies the pre-London fixing range between 06:00 and 06:45 GMT (UTC). During the London opening liquidity injection window (07:00 to 07:30 GMT), if price breaks out beyond the pre-range high/low by a buffer distance with minimum volatility confirmation (ATR >= 10 pips), the EA enters in the direction of the London morning institutional flow. Stop loss is set at the range midpoint (with bounds check), and take profit is placed at 2.0x SL distance (1:2.0 R:R). Any remaining position is closed at 12:00 GMT via a deterministic daily time-stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `InpRangeStartHourUTC` | 6 | 5-6 | Handover pre-range start hour UTC |
| `InpRangeStartMinUTC` | 0 | 0-30 | Handover pre-range start minute UTC |
| `InpRangeEndHourUTC` | 6 | 6-7 | Handover pre-range end hour UTC |
| `InpRangeEndMinUTC` | 45 | 30-59 | Handover pre-range end minute UTC |
| `InpEntryStartHourUTC` | 7 | 6-8 | Entry window start hour UTC |
| `InpEntryStartMinUTC` | 0 | 0-30 | Entry window start minute UTC |
| `InpEntryEndHourUTC` | 7 | 7-9 | Entry window end hour UTC |
| `InpEntryEndMinUTC` | 30 | 0-59 | Entry window end minute UTC |
| `InpTimeStopHourUTC` | 12 | 11-15 | Daily time stop exit hour UTC |
| `InpBufferPips` | 2.0 | 1.0-5.0 | Breakout entry buffer in pips |
| `InpMinAtrPips` | 10.0 | 5.0-25.0 | Minimum ATR in pips for volatility filter |
| `InpAtrPeriod` | 14 | 10-30 | ATR period for spread & volatility filter |
| `InpSpreadAtrMult` | 1.8 | 1.0-3.0 | Maximum allowable spread as multiple of M15 ATR |
| `InpRrMultiplier` | 2.0 | 1.5-3.0 | Take profit risk-reward multiplier |

---

## 3. Symbol Universe

**Designed for:**
- `EURJPY.DWX` — Primary target cross currency pair with high institutional handover volume.
- `GBPJPY.DWX` — High-beta GBP/JPY cross with pronounced London open expansion.
- `USDJPY.DWX` — Major JPY pair sensitive to Tokyo fix handover flow.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_M15)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 110 |
| Typical hold time | 1 to 5 hours (max until 12:00 UTC) |
| Expected drawdown profile | Controlled drawdown (<2.9%) |
| Regime preference | session breakout with momentum expansion |
| Win rate target (qualitative) | moderate-high |

---

## 6. Source Citation

**Source ID:** tokyo-london-bank-flow-handover-official-source
**Source type:** research paper / quantitative desk
**Pointer:** Institutional FX Liquidity Analysis & Tokyo Fix Handover Dynamics.
**R1–R4 verdict (Q00):** all PASS

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-18 | Initial build from approved card | Task fdaac67c-12cf-4c0f-a203-c19618076972 |
