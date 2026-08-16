# QM5_32003_cl-pit-open-volatility-breakout — Strategy Spec

**EA ID:** QM5_32003
**Slug:** `cl-pit-open-volatility-breakout`
**Source:** `cl-pit-open-volatility-breakout-official-source`
**Author of this spec:** Codex
**Last revised:** 2026-08-16

---

## 1. Strategy Logic

On each M5 trading day, the EA measures the high and low of the 08:50–09:00 US Eastern crude-oil box. At the first bar after the box closes, it places a buy stop $0.03 above the high and a sell stop $0.03 below the low; both orders carry a $0.25 stop and a $0.50 target. Filling either side cancels the other, and any remaining position or pending order is closed or removed at 14:30 US Eastern time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `InpBoxStart` | `08:50` | `08:30`–`08:55` | Opening-box start in US Eastern time. |
| `InpBoxEnd` | `09:00` | `08:55`–`09:10` | Opening-box end in US Eastern time. |
| `InpTPDollars` | `0.50` | `0.30`–`1.00` | Take-profit distance in CL dollars per barrel. |
| `InpSLDollars` | `0.25` | `0.15`–`0.40` | Stop-loss distance in CL dollars per barrel. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` — Darwinex WTI crude-oil proxy matching the card's CL pit-open mechanic and registered at symbol slot 0.

**Explicitly NOT for:**
- Other energy or index symbols — the $0.03 entry offset and fixed dollar-per-barrel exits are specific to WTI/CL price behavior.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 150 ordering prior; card frequency band is 80–160 high-conviction trades per year |
| Typical hold time | Intraday, from a near-open fill to no later than 14:30 ET (maximum about 5.5 hours) |
| Expected drawdown profile | Approximately 12% prior, with losses clustering on false opening-range breaks |
| Regime preference | Pit-open volatility expansion and directional breakout |
| Win rate target (qualitative) | Medium; source performance claims are not treated as evidence |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `cl-pit-open-volatility-breakout-official-source`
**Source type:** verified quantitative model / energy-desk blueprint
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_32003_cl-pit-open-volatility-breakout.md`; citation: “Crude Oil Pit Open Mechanics & Apex/Topstep Energy Studies.”
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_32003_cl-pit-open-volatility-breakout.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-16 | Initial build from card | 21858d97-b65b-404c-9e1a-dad1e616ded0 |
