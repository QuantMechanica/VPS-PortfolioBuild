# QM5_20039_onr-mid-brk — Strategy Spec

**EA ID:** QM5_20039
**Slug:** `onr-mid-brk`
**Source:** ZARATTINI-AZIZ-2023
**Author of this spec:** Codex
**Last revised:** 2026-07-22

---

## 1. Strategy Logic

For each calendar-approved US cash date, the EA constructs the executable-midquote overnight range
from 18:00 New York time on the preceding local date to 09:30. It freezes the
range and midpoint, then uses the first valid cash-session midquote strictly
inside that range to arm only the midpoint-indicated side. The first closed M5
bar beyond the armed boundary enters at the immediately following M5 open; a
close through the opposite boundary cancels the date. The immutable hard stop
is the overnight midpoint, there is no profit target, and every position closes
at 16:00 New York or the official 13:00 early close. A hash-bound NYSE
exception calendar supplies closure identity; valid ticks and contiguous bars
remain mandatory. Tester Groups applies venue commission to fills.

The midpoint side filter is explicitly an **UNVERIFIED QM repair hypothesis**.
It is implemented literally and is not represented as a result established by
Zarattini and Aziz (2023).

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_variant_id` | `ONR_MID_BRK_BASELINE` | locked | Approved variant identity. |
| `strategy_signal_tf` | `PERIOD_M5` | locked | Breakout confirmation and next-open entry timeframe. |
| `strategy_overnight_start_*_new_york` | `18:00` | locked | Overnight-range start on the preceding New York local date. |
| `strategy_cash_open_*_new_york` | `09:30` | locked | Cash-session freeze/open anchor in New York time. |
| `strategy_cash_close_*_new_york` | `16:00` | locked | Mandatory cash-session flat time in New York time. |
| `strategy_max_spread_points` | `0` | optional >0 | Tester/live native spread guard; zero disables the guard. |

## 3. Symbol Universe

**Designed for:**

- `SP500.DWX` — card-authorized US large-cap index route.
- `NDX.DWX` — card-authorized US technology-index sibling route.

**Explicitly NOT for:**

- Other `.DWX` symbols — they lack approval for this overnight midpoint
  hypothesis and do not share this card's US-index execution contract.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none; overnight extrema use synchronized real ticks |
| Bar gating | one `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` edge resolves the first closed-bar break before entry gating |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 200 before inside-range, side, and breakout exclusions |
| Typical hold time | intraday, from the qualifying next M5 open to midpoint stop or official cash close |
| Expected drawdown profile | approximately 12% card prior; SP500 and NDX losses may cluster as one correlated family |
| Regime preference | overnight-range breakout / cash-session volatility expansion |
| Win rate target (qualitative) | unverified; must be established by governed DEV/OOS/sealed tests |

## 6. Source Citation

This card was mechanised from:

**Source ID:** ZARATTINI-AZIZ-2023
**Source type:** academic paper plus an explicitly unverified QM hypothesis
**Pointer:** Zarattini and Aziz (2023), SSRN 4416622,
DOI 10.2139/ssrn.4416622; implementation card at
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_20039_onr-mid-brk_card.md`.
**R1–R4 verdict (Q00):** all PASS per the approved strategy card, with the
midpoint-side repair retained as an unverified hypothesis.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).
The approved baseline authorizes fixed-risk testing only; live sizing remains a
later governed promotion decision.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-22 | Initial build from card | 524c55cf-bca3-4100-a0aa-7c023b3a6f5d |
| v2 | 2026-07-22 | FTMO density fix | Replaced the unprovisioned overnight/cash ledger and commission/cost gate with broker-clock weekday/tick/bar eligibility and the optional native spread guard. |
| v3 | 2026-07-22 | US cash-calendar repair | Bound cash dates to the official hash-verified 2018–2025 NYSE calendar and made the entry/exit window honor 13:00 early closes. |
