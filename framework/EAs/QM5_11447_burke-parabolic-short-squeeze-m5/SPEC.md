# QM5_11447_burke-parabolic-short-squeeze-m5 — Strategy Spec

**EA ID:** QM5_11447
**Slug:** `burke-parabolic-short-squeeze-m5`
**Source:** `04305b6c-b4ce-522b-87b5-71708b6b8327`
**Author of this spec:** Codex
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

On each new M5 bar, the EA looks for three consecutive lower D1 closes whose latest day also made a lower low and closed bullish; the short-side mirror requires three higher closes, a higher high, and a bearish latest close. During the London or New York window, it takes at most one entry per D1 setup: it buys the first closed M5 bar that crosses above EMA(20), or sells the mirrored cross below EMA(20). The stop is 20 pips; the target is at least 50 pips and extends to the D1 shift-3 swing price when that price is farther away, capped at 250 pips, with the framework Friday close as the only additional exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_pattern_bars` | 3 | 2, 3, or 4 | Number of consecutive lower or higher D1 closes required. |
| `strategy_ema_period` | 20 | 13, 20, or 34 | M5 EMA period used for the single closed-bar cross trigger. |
| `strategy_sl_pips` | 20 | 15, 20, or 25 | Fixed stop distance; the card caps it at 25 pips. |
| `strategy_tp_min_pips` | 50 | 50, 100, or 200 | Minimum take-profit distance before swing-target extension. |
| `strategy_tp_max_pips` | 250 | 50–250 | Maximum take-profit distance when the prior swing is farther away. |
| `strategy_london_start_utc` | 7 | 0–23 | Inclusive UTC hour for the interpreted London window. |
| `strategy_london_end_utc` | 12 | 1–24 | Exclusive UTC hour for the interpreted London window. |
| `strategy_ny_start_utc` | 13 | 0–23 | Inclusive UTC hour for the interpreted New York window. |
| `strategy_ny_end_utc` | 17 | 1–24 | Exclusive UTC hour for the interpreted New York window. |
| `strategy_spread_cap_pips` | 15 | 15 (card value) | Blocks entry when a positive modeled spread exceeds 15 pips; zero tester spread passes. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — liquid major FX pair explicitly listed by the approved card.
- `GBPUSD.DWX` — liquid London/NY major explicitly listed by the approved card.
- `USDJPY.DWX` — liquid major FX pair explicitly listed by the approved card.
- `AUDUSD.DWX` — portable major FX pair explicitly listed by the approved card.
- `USDCAD.DWX` — portable major FX pair explicitly listed by the approved card.

**Explicitly NOT for:**

- Other `.DWX` symbols — the approved card limits this build to the five named FX instruments, so no unapproved symbol expansion is registered.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `D1` for the multi-day false-break reversal state; `M5` for EMA entry timing |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (the generated setfiles run M5) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 20 |
| Expected trade frequency | Approximately 20 entries per year per symbol |
| Typical hold time | Not specified in the approved card; price-based SL/TP with Friday-close bounding |
| Expected drawdown profile | Not specified in the approved card; each position has a fixed 15–25 pip stop under framework risk sizing |
| Regime preference | False-break mean reversion followed by short-squeeze or long-squeeze continuation during liquid sessions |
| Win rate target (qualitative) | Not specified in the approved card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `04305b6c-b4ce-522b-87b5-71708b6b8327`
**Source type:** Online/self-published trading playbook
**Pointer:** `707586131-1-Stacey-Burke-Best-Trade-Setups-Playbook-Notes-Part-2.pdf`, Part 2, pages 51–106
**R1–R4 verdict (Q00):** R1 lineage recorded (named author, self-published/CONDITIONAL) and R2–R4 PASS per `artifacts/cards_approved/QM5_11447_burke-parabolic-short-squeeze-m5.md`.

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
| v1 | 2026-08-10 | Initial build from card | 0b3e5894-9acf-498c-a68e-d06a0877f633 |
