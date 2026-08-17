# QM5_32007_london-fix-wm-reuters-currency-drift — Strategy Spec

**EA ID:** QM5_32007
**Slug:** `london-fix-wm-reuters-currency-drift`
**Source:** `london-fix-wm-reuters-currency-drift-official-source`
**Author of this spec:** Codex
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

On each weekday, compare the EURUSD or GBPUSD M5 close at 15:30 UTC with the
same symbol's M5 close at 11:30 UTC. Buy when that four-hour return is at least
+0.15%, sell when it is at most -0.15%, and otherwise stay flat. Each entry has
a fixed 12-pip stop and 22-pip target; any survivor is closed at 16:05 UTC.

The card's 15:31 order timestamp is normalized to the first tick of the M5 bar
opening at 15:30 UTC, after the preceding bar has fixed the 15:30 endpoint. This
keeps the signal closed-bar-only and avoids an exact-minute tick dependency.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `InpEntryTime` | `15:31` | `15:15`–`15:45` | Card order time in fixed UTC; rounded down to its completed M5 endpoint. |
| `InpExitTime` | `16:05` | `16:00`–`16:15` | Fixed UTC hard time exit. |
| `InpROCThreshold` | `0.15` | `0.08`–`0.30` | Absolute 11:30-to-15:30 return threshold in percent. |

The 11:30 UTC start, ATR(14) spread reference, 1.8×ATR spread cap, 12-pip
stop, and 22-pip target are card-locked constants rather than optimization
inputs. Framework risk inputs provide the card's sizing contract.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — primary liquid London-fix FX carrier, magic slot 0.
- `GBPUSD.DWX` — second liquid London-fix FX carrier, magic slot 1.

**Explicitly NOT for:**

- Non-FX symbols — the approved thesis is institutional currency-fix flow.
- Any symbol outside the two active magic-registry rows — the card does not authorize expansion.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

The bounded endpoint scan runs only on the framework's closed-bar path.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 80–160; ordering prior 150 |
| Typical hold time | up to about 35 minutes |
| Expected drawdown profile | card prior 12%; Q02 must measure it under fixed risk |
| Regime preference | weekday institutional time-of-day flow with a directional pre-fix move |
| Win rate target (qualitative) | unknown until governed out-of-sample evidence exists |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `london-fix-wm-reuters-currency-drift-official-source`
**Source type:** paper citation recorded by the approved Strategy Card
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_32007_london-fix-wm-reuters-currency-drift.md`
**Citation:** Marsh, I. and O'Rourke, R. (2020), *Order Flow Around the London 4 PM Fix*.
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `strategy-seeds/cards/approved/QM5_32007_london-fix-wm-reuters-currency-drift.md`.

The card's performance and prop-challenge figures are not treated as verified
evidence; Q02 and later governed phases determine viability.

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
| v1 | 2026-08-17 | Initial build from approved card | build task `02d91117-ca8c-4bdc-9231-8b7f6ebc3677` |
