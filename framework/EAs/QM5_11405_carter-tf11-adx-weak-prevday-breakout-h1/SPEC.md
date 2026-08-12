# QM5_11405_carter-tf11-adx-weak-prevday-breakout-h1 — Strategy Spec

**EA ID:** QM5_11405
**Slug:** `carter-tf11-adx-weak-prevday-breakout-h1`
**Source:** `29c77a02-59bd-52f7-bcb3-b3108d5f1e79`
**Author of this spec:** Codex
**Last revised:** 2026-08-03

---

## 1. Strategy Logic

On each completed H1 bar, the EA requires ADX(14) below 35 and checks whether that bar moved at least 15 pips beyond the previous day's range. A move below the previous-day low arms a buy stop 15 pips above the previous-day high, while a move above the previous-day high arms a sell stop 15 pips below the previous-day low; an unfilled order expires at the end of the broker day. A filled trade has a 30-pip stop, a 60-pip target, and moves its stop to break-even after a 30-pip favorable move.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_adx_period` | 14 | 7–28 | ADX lookback on H1. |
| `strategy_adx_weak_threshold` | 35.0 | 25–35 | Entries require ADX strictly below this weak-trend ceiling. |
| `strategy_breakout_buffer_pips` | 15 | 5–15 | Distance beyond the previous-day extreme for both the probe and pending entry. |
| `strategy_sl_pips` | 30 | 1–40 | Initial stop distance; the card caps P2 at 40 pips. |
| `strategy_tp_pips` | 60 | 40–80 | Fixed take-profit distance from pending entry. |
| `strategy_be_trigger_pips` | 30 | 1–60 | Favorable distance that triggers an exact break-even stop. |
| `strategy_spread_cap_pips` | 20 | 1–20 | Blocks only a genuinely positive modeled spread above this value. |

> Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — liquid FX major named by the approved card.
- `GBPUSD.DWX` — liquid FX major named by the approved card.
- `USDJPY.DWX` — liquid FX major named by the approved card; framework pip conversion handles JPY scaling.
- `AUDUSD.DWX` — liquid FX major named by the approved card.
- `USDCAD.DWX` — liquid FX major named by the approved card.
- `USDCHF.DWX` — liquid FX major named by the approved card.

**Explicitly NOT for:**

- Non-FX `.DWX` symbols — the approved card restricts the portable basket to these six FX majors and calibrates its distances in FX pips.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `D1` previous-day high and low at shift 1 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 50 |
| Expected trade frequency | Roughly weekly, derived from the card's 50 trades/year estimate |
| Typical hold time | Hours to several days; the card specifies no filled-position time stop |
| Expected drawdown profile | Losses can cluster when weak-ADX range failures continue instead of crossing the prior-day range |
| Regime preference | Weak-ADX consolidation followed by a false break and cross-range expansion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `29c77a02-59bd-52f7-bcb3-b3108d5f1e79`
**Source type:** `book`
**Pointer:** Thomas Carter, *20 Trend Following Systems* (2014), Strategy #11; local PDF `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\514732392-Forex-Trend-Following-Strategy.pdf`
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_11405_carter-tf11-adx-weak-prevday-breakout-h1.md`

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
| v1 | 2026-08-03 | Initial build from card | a3058d61-2053-4133-a7eb-b90dde62df9e |
