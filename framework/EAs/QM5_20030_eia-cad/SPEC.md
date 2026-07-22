# QM5_20030_eia-cad — Strategy Spec

**EA ID:** QM5_20030
**Slug:** `eia-cad`
**Source:** `FERRARO-ROGOFF-ROSSI-2015`
**Author of this spec:** Codex
**Last revised:** 2026-07-22

---

## 1. Strategy Logic

The EA reads an immutable, hash-pinned EIA release calendar built from the
official WPSR archive and evaluates only the first completed five-minute WTI
bar after each eligible release. A WTI move of at least 0.6 times its
pre-release ATR arms a
USDCAD trade in the opposite direction: rising oil sells USDCAD and falling oil
buys it. The stop is the synchronized USDCAD release-bar extreme, there is no
profit target or trailing logic, and the position is closed at release time plus
30 minutes. Missing, stale, duplicate, or malformed schedule data blocks new
entries while leaving open-position exits active. API events remain ineligible:
the available official historical schedules prove publication dates but not the
exact timestamp required by the card.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_signal_tf` | `PERIOD_M5` | fixed M5 | Synchronized USDCAD and WTI event-bar timeframe. |
| `strategy_atr_period` | `14` | fixed 14 | Wilder ATR bars ending before the release bar. |
| `strategy_impulse_atr_mult` | `0.60` | fixed 0.60 | Minimum absolute WTI release-bar move in ATR units. |
| `strategy_time_exit_minutes` | `30` | fixed 30 | Force-flat deadline measured from scheduled release time. |
| `strategy_max_cost_r` | `0.10` | fixed 0.10 | Maximum commission-plus-spread cost as a fraction of initial risk. |

The immutable runtime calendar is
`QM5_20030_eia_calendar_20180110_20251231.csv` (SHA-256
`b273dd88d27e38fe78ec85e426e0f1c8c8ef07dae2f7e1e102ba96f492c33e04`),
provisioned through `FILE_COMMON`. It contains 352 official-archive Wednesday
releases at the issuer-defined 10:30 New York standard time. Sixty-four
historically shifted releases and all API releases are excluded when their
exact timestamp cannot be proven; no weekday/time fallback is used.

Framework-level risk, news, seed, stress, and Friday-close inputs are documented
in `framework/V5_FRAMEWORK_DESIGN.md` and are not duplicated here.

---

## 3. Symbol Universe

**Designed for:**

- `USDCAD.DWX` — the only order-routable leg; CAD is the commodity-currency response leg.
- `XTIUSD.DWX` — synchronized WTI sign anchor and ATR source; signal-only and never order-routable.

**Explicitly NOT for:**

- All other `.DWX` symbols — the approved card authorizes only the USDCAD response to the WTI event impulse.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none; cross-symbol `XTIUSD.DWX` is also read at M5 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 60 on the USDCAD order leg |
| Typical hold time | at most 25 minutes after the next-M5-open fill |
| Expected drawdown profile | approximately 12% prior, concentrated around inventory-event volatility |
| Regime preference | news-driven oil-inventory impulse |
| Win rate target (qualitative) | medium; expected PF prior 1.3 |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `FERRARO-ROGOFF-ROSSI-2015`
**Source type:** academic paper
**Pointer:** Ferraro, Rogoff & Rossi (2015), JIMF 54:116–141, DOI `10.1016/j.jimonfin.2015.03.001`
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_20030_eia-cad.md`

The paper supports the oil/commodity-currency sign thesis. The event timing,
M5 bar construction, ATR threshold, stop, cost gate, and time exit are explicit
QuantMechanica interpretations from the approved card.

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
| v1 | 2026-07-22 | Initial build from card | `3ba3900b-1c08-43b7-886b-20eb16cb7f6f` |
