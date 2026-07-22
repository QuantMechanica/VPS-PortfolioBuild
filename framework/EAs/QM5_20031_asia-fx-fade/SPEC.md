# QM5_20031_asia-fx-fade — Strategy Spec

**EA ID:** QM5_20031
**Slug:** `asia-fx-fade`
**Source:** `ITO-HASHIMOTO-2006`
**Author of this spec:** Codex
**Last revised:** 2026-07-22

---

## 1. Strategy Logic

The EA builds each broker date's 00:00–07:00 range from completed M15 bars and
compares the current move from the session open with the expanding mean of prior
valid session ranges. A move of at least 75% of that prior mean is faded at the
next M15 open, targeting the signal-time range midpoint and using the opposite
one-mean-range boundary as the hard stop. Only one attempt is permitted per day,
and any remainder is closed at 08:00 London. Session eligibility is derived
from the broker clock, requires all 28 valid M15 bars, and is limited to UTC
weekdays; no external session ledger is used. Tester Groups applies venue
commission to fills.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_signal_tf` | `PERIOD_M15` | fixed M15 | Session-state and entry-signal timeframe. |
| `strategy_range_fraction` | `0.75` | fixed 0.75 | Required move as a fraction of the expanding prior-session mean range. |
| `strategy_max_spread_points` | `0` | optional >0 | Tester/live native spread guard; zero disables the guard. |

Framework-level risk, news, seed, stress, and Friday-close inputs are documented
in `framework/V5_FRAMEWORK_DESIGN.md` and are not duplicated here.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — primary liquid FX pair supported by the source's Asian-session microstructure evidence.
- `GBPUSD.DWX` — preregistered portability test for the same Asian-session USD-flow mechanism.

**Explicitly NOT for:**

- All other `.DWX` symbols — the approved card authorizes only EURUSD and GBPUSD.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 220 after session eligibility |
| Typical hold time | intraday, from the qualifying Asian-session M15 open to at most 08:00 London |
| Expected drawdown profile | approximately 14% prior, concentrated during one-way Asian extensions |
| Regime preference | low-activity Asian-session mean reversion |
| Win rate target (qualitative) | medium; expected PF prior 1.25 |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ITO-HASHIMOTO-2006`
**Source type:** academic paper
**Pointer:** Ito & Hashimoto (2006), NBER Working Paper 12413 / JJIE 20(4):637–664, DOI `10.3386/w12413`
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_20031_asia-fx-fade.md`

The source supports the Asian-session low-activity mechanism. The 0.75 range
threshold, expanding estimator, midpoint target, hard stop, and London time
exit are explicit QuantMechanica interpretations from the approved card.

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
| v1 | 2026-07-22 | Initial build from card | `c17160f6-0f9d-492a-a6ab-816094e912eb` |
| v2 | 2026-07-22 | FTMO density fix | Replaced the unprovisioned session ledger and pre-trade cost gate with broker-clock weekday/bar eligibility and the optional native spread guard. |
