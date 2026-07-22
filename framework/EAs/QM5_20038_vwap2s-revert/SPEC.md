# QM5_20038_vwap2s-revert — Strategy Spec

**EA ID:** QM5_20038
**Slug:** `vwap2s-revert`
**Source:** BERKOWITZ-LOGUE-NOSER-1988
**Author of this spec:** Codex
**Last revised:** 2026-07-22

---

## 1. Strategy Logic

For each calendar-approved 09:30–16:00 New York cash session, the EA incrementally
builds a tick-volume-weighted typical-price VWAP and population sigma on closed
M5 bars. A shallow-slope close that touches only the lower or upper two-sigma
band schedules a fade at the next M5 open, with frozen VWAP as target and the
frozen three-sigma band as hard stop. Both mechanical sides are eligible and
positions are flat by 16:00 or the official 13:00 early close. A hash-bound
NYSE exception calendar supplies holiday and early-close identity, and exact
contiguous bars remain mandatory. Tester Groups applies venue commission to
fills.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_variant_id` | `VWAP2S_REVERT_BASELINE` | locked | Approved variant identity. |
| `strategy_signal_tf` | `PERIOD_M5` | locked | VWAP, tag, and entry timeframe. |
| `strategy_cash_open_*_new_york` | `09:30` | locked | Cash-session opening anchor in New York time. |
| `strategy_cash_close_*_new_york` | `16:00` | locked | Mandatory cash-session flat time in New York time. |
| `strategy_max_spread_points` | `0` | optional >0 | Tester/live native spread guard; zero disables the guard. |

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
| Trades / year / symbol | approximately 300 before session and tag eligibility |
| Typical hold time | intraday, from the tagged next M5 open to frozen VWAP/stop or cash close |
| Expected drawdown profile | approximately 12% card prior; clustered losses when two-sigma excursions continue to three sigma |
| Regime preference | shallow-VWAP-slope intraday mean reversion |
| Win rate target (qualitative) | unverified until pipeline evaluation |

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
| v2 | 2026-07-22 | FTMO density fix | Removed the unprovisioned cash-calendar, DEV-hash, and commission/cost gates; broker-clock weekday/bar eligibility and the optional native spread guard remain. |
| v3 | 2026-07-22 | US cash-calendar repair | Restored the Card-required official, hash-verified 2018–2025 NYSE holiday/early-close dependency without changing signal thresholds. |
