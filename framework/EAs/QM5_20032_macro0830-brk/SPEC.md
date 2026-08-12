# QM5_20032_macro0830-brk — Strategy Spec

**EA ID:** QM5_20032
**Slug:** `macro0830-brk`
**Source:** `EDERINGTON-LEE-1993`
**Author of this spec:** Codex
**Last revised:** 2026-07-22

---

## 1. Strategy Logic

The EA trades only events in the framework news calendar deployed by the
pipeline and scheduled at exactly 08:30 New York time. The eligible subset is
NFP, CPI, and PPI. It freezes the high and low of the three completed M5 bars
before the release, then buys when the completed 08:30 release bar closes above
that range or sells when it closes below it. The opposite range boundary is the
hard stop, there is no profit target or trailing logic, and the position is
closed at 17:20 Berlin with independent EU-DST conversion.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_signal_tf` | `PERIOD_M5` | fixed M5 | Pre-release range and release-bar timeframe. |
| `strategy_pre_release_bars` | `3` | fixed 3 | Number of completed bars in the 08:15–08:30 New York range. |
Runtime events come from the deployed framework `news_calendar_2015_2025.csv`.
Missing or malformed calendar data fails entries closed. Xetra full closures
and 14:00 Europe/Berlin early closes remain anchored to the shared cash
calendar. Tester Groups and live fills realize trading costs in results.

`basket_manifest.json` declares `GDAXI.DWX` and `SP500.DWX` as order routes
and `EURUSD.DWX` as a conversion-only market-data dependency for the
card-required EUR commission conversion. The EA never routes an EURUSD order.

Framework-level risk, news, seed, stress, and Friday-close inputs are documented
in `framework/V5_FRAMEWORK_DESIGN.md` and are not duplicated here.

---

## 3. Symbol Universe

**Designed for:**

- `GDAXI.DWX` — canonical DAX route for the approved German spillover test.
- `SP500.DWX` — canonical S&P 500 route and direct US macro-shock control.

**Explicitly NOT for:**

- All other `.DWX` symbols — the approved card authorizes only the DAX spillover and S&P control routes.

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
| Trades / year / symbol | approximately 120–180 across the exact-time event basket |
| Typical hold time | from the 08:35 New York entry to at most 17:20 Berlin |
| Expected drawdown profile | approximately 15% prior, concentrated around scheduled macro jumps |
| Regime preference | news-driven volatility expansion and price discovery |
| Win rate target (qualitative) | medium; expected PF prior 1.30 |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `EDERINGTON-LEE-1993`
**Source type:** academic papers
**Pointer:** Ederington & Lee (1993), JF 48(4):1161–1191; Andersen et al. (2003), AER 93(1):38–62
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_20032_macro0830-brk.md`

The sources support scheduled-release jumps and rapid price discovery. The
issuer whitelist, three-bar breakout, DAX/S&P routes, opposite-range stop, cost
gate, and Berlin time exit are explicit QuantMechanica interpretations from the
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
| v1 | 2026-07-22 | Initial build from card | `498c7f0a-7678-46ab-a2fd-84424cabdf51` |
| v2 | 2026-07-25 | Group-B calendar repair | Replaced the bespoke macro ledger with the deployed framework news calendar and removed the pre-trade cost gate. |
