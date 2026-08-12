# QM5_20033_moc-imom — Strategy Spec

**EA ID:** QM5_20033
**Slug:** `moc-imom`
**Source:** `GAO-HAN-LI-ZHOU-2018`
**Author of this spec:** Codex
**Last revised:** 2026-07-22

---

## 1. Strategy Logic

The EA measures the signed move during each market's first 30 minutes. A
positive opening move buys and a negative opening move sells at the start of
the final cash-session M30 interval. The hard stop is one frozen opening-move
distance from the actual entry, there is no profit target or trailing logic,
and any remainder is closed at the cash-session close. US dates are admitted
by the hash-bound NYSE exception calendar; its 13:00 New York early close moves
the final M30 interval to 12:30–13:00. The Xetra route retains its existing
broker-clock eligibility boundary. Tester Groups applies venue commission to
fills.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_signal_tf` | `PERIOD_M30` | fixed M30 | Opening-return and final-interval signal timeframe. |
| `strategy_us_open_*_broker` | `16:30` | fixed | US cash-session opening anchor in broker time. |
| `strategy_us_entry_*_broker` | `22:30` | fixed | US final-M30 entry in broker time. |
| `strategy_us_close_*_broker` | `23:00` | fixed | US cash-session close in broker time. |
| `strategy_xetra_open_*_broker` | `10:00` | fixed | Xetra opening anchor in broker time. |
| `strategy_xetra_entry_*_broker` | `18:00` | fixed | Xetra final-M30 entry in broker time. |
| `strategy_xetra_close_*_broker` | `18:30` | fixed | Xetra cash-session close in broker time. |
| `strategy_max_spread_points` | `0` | optional >0 | Tester/live native spread guard; zero disables the guard. |

Framework-level risk, news, seed, stress, and Friday-close inputs are documented
in `framework/V5_FRAMEWORK_DESIGN.md` and are not duplicated here.

---

## 3. Symbol Universe

**Designed for:**

- `SP500.DWX` — canonical S&P 500 route for the source's US large-cap market.
- `NDX.DWX` — Nasdaq 100 portability route exposed to closing-auction and ETF-rebalancing flow.
- `WS30.DWX` — Dow 30 portability route for the same US cash-close mechanism.
- `GDAXI.DWX` — DAX 40 portability test using governed Xetra session timestamps.

**Explicitly NOT for:**

- All other `.DWX` symbols — the approved card authorizes only these four index routes.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 250 before clock/bar eligibility |
| Typical hold time | one final cash-session M30 interval |
| Expected drawdown profile | approximately 13% prior, concentrated in index cash-close reversals |
| Regime preference | closing-auction intraday momentum |
| Win rate target (qualitative) | medium; expected PF prior 1.35 |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `GAO-HAN-LI-ZHOU-2018`
**Source type:** academic paper
**Pointer:** Gao, Han, Li & Zhou (2018), JFE 129(2):394–414, DOI `10.1016/j.jfineco.2018.05.009`
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_20033_moc-imom.md`

The paper supports same-direction continuation from the first half-hour into
the final half-hour. Exact CFD routes, broker-clock sessions, stop construction,
and cash-close handling are explicit QuantMechanica interpretations from the
approved card.

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
| v1 | 2026-07-22 | Initial build from card | `d6c25ce6-d80e-4b25-bbf3-f1d4ecdd2b2d` |
| v2 | 2026-07-22 | FTMO density fix | Replaced the unprovisioned session ledger and pre-trade cost gate with fixed broker-clock sessions, UTC weekday/tick eligibility, and the optional native spread guard. |
| v3 | 2026-07-22 | US cash-calendar repair | Bound US routes to the official hash-verified 2018–2025 NYSE exception calendar; full closures fail closed and early closes move the final M30 interval. |
