# QM5_20038_vwap2s-revert — Strategy Spec

**EA ID:** QM5_20038
**Slug:** `vwap2s-revert`
**Source:** BERKOWITZ-LOGUE-NOSER-1988
**Author of this spec:** Codex
**Last revised:** 2026-07-22

---

## 1. Strategy Logic

For each official 09:30–16:00 New York cash session, the EA incrementally
builds a tick-volume-weighted typical-price VWAP and population sigma on closed
M5 bars. A shallow-slope close that touches only the lower or upper two-sigma
band schedules a fade at the next M5 open, with frozen VWAP as target and the
frozen three-sigma band as hard stop. A symbol/side may trade only when its
hash-pinned 2018–2023 DEV artifact records more reversions than failures and
positive net expectancy; positions are flat by the official close or early close.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_variant_id` | `VWAP2S_REVERT_BASELINE` | locked | Approved variant identity. |
| `strategy_signal_tf` | `PERIOD_M5` | locked | VWAP, tag, and entry timeframe. |
| `strategy_max_cost_r` | 0.10 | locked | Maximum commission plus entry spread relative to initial risk. |
| `strategy_round_turn_commission_usd_per_lot` | 0.0 | governed value required | Per-symbol runtime commission; zero fails closed. |
| `strategy_cash_calendar_file` | `QM5_20038_us_cash_calendar.csv` | immutable file | Common-Files official US cash sessions and early closes. |
| `strategy_cash_calendar_sha256` | empty | SHA-256 | Required exact calendar-file hash. |
| `strategy_calendar_valid_through` | `2025.12.31` | locked | Required calendar coverage. |
| `strategy_tzdb_version` | empty | governed value required | Pinned America/New_York tzdb version. |
| `strategy_dev_guard_file` | `QM5_20038_vwap2s_dev_guard.csv` | immutable file | Frozen per-symbol/per-side DEV proof. |
| `strategy_dev_guard_sha256` | empty | SHA-256 | Required exact guard-artifact hash. |
| `strategy_expected_dev_code_sha256` | empty | SHA-256 | Expected measurement code identity. |
| `strategy_expected_dev_inputs_sha256` | empty | SHA-256 | Expected frozen measurement-input identity. |
| `strategy_expected_dev_data_sha256` | empty | SHA-256 | Expected symbol-specific DEV dataset identity. |

## 3. Symbol Universe

**Designed for:**

- `SP500.DWX` — direct US-index route for the New York cash-session hypothesis.
- `XAUUSD.DWX` — card-authorized cross-asset benchmark port, guarded independently.

**Explicitly NOT for:**

- Other `.DWX` symbols — no other route has an approved, independently frozen
  symbol/side DEV proof for this variant.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | one `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` edge advances the cached estimator before entry gating |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 300 before DEV-side, session, tag, and cost gates |
| Typical hold time | intraday, from the tagged next M5 open to frozen VWAP/stop or cash close |
| Expected drawdown profile | approximately 12% card prior; clustered losses when two-sigma excursions continue to three sigma |
| Regime preference | shallow-VWAP-slope intraday mean reversion |
| Win rate target (qualitative) | each admitted DEV side must have strictly more reversions than failures |

## 6. Source Citation

This card was mechanised from:

**Source ID:** BERKOWITZ-LOGUE-NOSER-1988
**Source type:** academic paper
**Pointer:** Berkowitz, Logue and Noser (1988), *The Journal of Finance* 43(1),
DOI 10.1111/j.1540-6261.1988.tb02591.x; implementation card at
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_20038_vwap2s-revert_card.md`.
**R1–R4 verdict (Q00):** all PASS per
`artifacts/cards_approved/QM5_20038_vwap2s-revert.md`.

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
| v1 | 2026-07-22 | Initial build from card | 294c6197-df5d-478f-bf22-0421fcb0a90d |
