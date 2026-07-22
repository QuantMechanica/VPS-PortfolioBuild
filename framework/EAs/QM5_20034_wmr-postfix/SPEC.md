# QM5_20034_wmr-postfix — Strategy Spec

**EA ID:** QM5_20034
**Slug:** `wmr-postfix`
**Source:** `EVANS-2018`
**Author of this spec:** Codex
**Last revised:** 2026-07-22

---

## 1. Strategy Logic

The EA samples real-tick midquotes at the governed 15:57:30 and 16:02:30
London fix endpoints and compares the absolute displacement with the median of
the prior 20 valid fixing days. When displacement is strictly greater than 1.5
times that median and the completed 16:00–16:05 bar has not already reversed,
the EA fades the move at 16:05. Frozen P0 is the target, one displacement from
the actual entry is the hard stop, and any remainder is closed at 16:30 London.
The endpoints are derived from the broker clock, and a date enters the rolling
sample only when the manifest-bound WMR 16:00 London service contract says the
fix is available and its tick endpoints are valid. The EA never substitutes an
England/Wales holiday or LSE cash-session date for WMR availability. Tester
Groups applies venue commission.

The common loader verifies both
`QM5_London_calendar_manifest.json` and the WMR runtime CSV by SHA-256 in MT5
Common Files. Verified service coverage is only 2025-01-01 through 2025-12-31:
ordinary weekdays are available unless listed, explicit `NO_1600_FIX` dates are
skipped, and the available alteration statuses remain eligible.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_signal_tf` | `PERIOD_M5` | fixed M5 | Fix confirmation and entry timeframe. |
| `strategy_median_days` | `20` | fixed 20 | Prior valid fixing-day sample used for the displacement median. |
| `strategy_displacement_mult` | `1.50` | fixed 1.50 | Strict qualifying multiple of the prior-20 median displacement. |
| `strategy_p0_*_london` | `15:57:30` | fixed | First WMR displacement endpoint in London time. |
| `strategy_p1_*_london` | `16:02:30` | fixed | Second WMR displacement endpoint in London time. |
| `strategy_entry_*_london` | `16:05` | fixed | Post-fix entry time in London time. |
| `strategy_exit_*_london` | `16:30` | fixed | Mandatory flat time in London time. |
| `strategy_max_spread_points` | `0` | optional >0 | Tester/live native spread guard; zero disables the guard. |

Framework-level risk, news, seed, stress, and Friday-close inputs are documented
in `framework/V5_FRAMEWORK_DESIGN.md` and are not duplicated here.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — primary liquid WMR benchmark pair supported by the source evidence.
- `GBPUSD.DWX` — preregistered portability test for the same benchmark-flow reversal mechanism.

**Explicitly NOT for:**

- All other `.DWX` symbols — the approved card authorizes only EURUSD and GBPUSD.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` with real-tick endpoint sampling |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 200–250 before the strict displacement gate |
| Typical hold time | no more than 25 minutes after the 16:05 London entry |
| Expected drawdown profile | approximately 14% prior, concentrated during persistent benchmark-flow moves |
| Regime preference | conditional post-fix mean reversion |
| Win rate target (qualitative) | medium; expected PF prior 1.20 |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `EVANS-2018`
**Source type:** academic paper and regulatory evidence
**Pointer:** Evans (2018), JBF 87:233–247, DOI `10.1016/j.jbankfin.2017.09.017`; FCA Occasional Paper 46
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_20034_wmr-postfix.md`

The sources support WMR-window displacement and reversal while warning that the
effect decayed after 2015. The endpoint window, rolling median, 1.5 threshold,
confirmation, target, stop, and time exit are explicit QuantMechanica
interpretations from the approved card.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## 8. Calendar Contract and Validation Blocker

- WMR 16:00 service coverage for 2018-01-01 through 2024-12-31 is not backed by
  immutable official schedule bytes and is therefore `OUT_OF_COVERAGE`.
- Those dates fail closed before endpoint sampling and cannot populate the
  rolling 20-fix history. No UK public-holiday or LSE rule is used to fill the
  gap.
- The 2025 alteration schedule is usable as specified, including the
  counterexample 2025-05-26 where a UK holiday still has a normal 16:00 fix.
- Because the approved falsification contract requires positive conditional
  reversal separately in both 2024 and 2025, the full card cannot yet be
  validated. No strategy-success claim is supported until authoritative 2024
  WMR coverage is acquired and the prescribed tests pass.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-22 | Initial build from card | `a9dce427-25fd-4673-8c64-bf01ddcd4cc0` |
| v2 | 2026-07-22 | FTMO density fix | Replaced the unprovisioned fixing ledger and pre-trade cost gate with broker-clock weekday/tick eligibility and the optional native spread guard. |
| v3 | 2026-07-22 | Verified WMR calendar integration | Bound fixing-day eligibility and rolling history to the official 2025 WMR service schedule; 2018-2024 is explicitly fail-closed and UK/LSE substitution is forbidden. |
