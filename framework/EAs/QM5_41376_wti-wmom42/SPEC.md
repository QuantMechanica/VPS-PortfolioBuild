# QM5_41376_wti-wmom42 — Strategy Spec

**EA ID:** QM5_41376
**Slug:** `wti-wmom42`
**Source:** `KWON-KANG-YUN-WTI-WMOM42-2026` (see `strategy-seeds/sources/KWON-KANG-YUN-WTI-WMOM42-2026/`)
**Author of this spec:** Codex
**Last revised:** 2026-09-08

---

## 1. Strategy Logic

At the first tradable D1 bar of a new broker week, the EA reconstructs four consecutive completed three-to-five-session weeks for WTI. It excludes the immediately preceding week `t-1`, computes `ln(final close of t-2 / first open of t-4)`, buys when that value is strictly positive, and sells when it is strictly negative. Each week is consumed before fallible entry gates so the EA cannot retry, and an open position is closed at the next normalized week boundary or after ten calendar days as stale-state repair; the initial stop is frozen at `3.5 × ATR(20,D1)` with no take-profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_symbol` | empty | setfile-bound to registered host symbol | Exact chart and traded symbol; the backtest setfile supplies `XTIUSD.DWX`. |
| `strategy_label_offset_seconds` | 86400 | locked | Uniform one-day normalization for the XTIUSD.DWX D1 energy-bar labels. |
| `strategy_entry_grace_minutes` | 180 | locked | Maximum elapsed minutes from the first tradable weekly D1 bar open. |
| `strategy_history_bars` | 40 | locked | Bounded D1 history buffer used to reconstruct completed weeks. |
| `strategy_formation_weeks` | 3 | locked | Formation span covering weeks `t-4` through `t-2`. |
| `strategy_skip_recent_weeks` | 1 | locked | Excludes week `t-1` from formation arithmetic. |
| `strategy_min_week_bars` | 3 | locked | Minimum unique sessions accepted in a completed week. |
| `strategy_max_week_bars` | 5 | locked | Maximum unique sessions accepted in a completed week. |
| `strategy_return_epsilon` | 0.0 | locked | Strict zero boundary for long/short sign selection. |
| `strategy_atr_period_d1` | 20 | locked | Completed-D1-bar ATR period for the entry stop. |
| `strategy_atr_sl_mult` | 3.5 | locked | Frozen ATR multiple used for the hard stop. |
| `strategy_max_hold_days` | 10 | locked | Calendar-day stale-position repair ceiling. |
| `strategy_max_spread_points` | 1500 | locked | Maximum entry spread; a zero modeled tester spread remains valid. |

> Framework inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` — the card's exact registered WTI crude-oil carrier and the R3 PASS data source.

**Explicitly NOT for:**

- All other `.DWX` symbols — the approved card is an explicit single-symbol WTI baseline and forbids basket expansion.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` consumed once per tick |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 48; approximately 45–52 completed WTI positions per full post-warm-up year before execution gates |
| Typical hold time | One broker week; ten calendar days is stale repair only |
| Expected drawdown profile | High-risk profile; card expectation is up to 35% drawdown before portfolio aggregation |
| Regime preference | Structural WTI trend / weekly momentum continuation |
| Win rate target (qualitative) | Not specified by the card; Q02 owns empirical frequency and economics |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `KWON-KANG-YUN-WTI-WMOM42-2026`
**Source type:** peer-reviewed paper
**Pointer:** `strategy-seeds/sources/KWON-KANG-YUN-WTI-WMOM42-2026/source.md`; Kwon, Kang, and Yun (2020), *Weekly Momentum in the Commodity Futures Market*, Finance Research Letters 35, 101306, DOI 10.1016/j.frl.2019.101306.
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_41376_wti-wmom42.md`.

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
| v1 | 2026-09-08 | Initial build from card | c85306da-094b-45a0-8c2f-722ecc4e5adc |
