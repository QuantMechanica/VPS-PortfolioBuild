# QM5_11870_dead-time-range-fade - Strategy Spec

**EA ID:** QM5_11870
**Slug:** `dead-time-range-fade`
**Source:** `34ee988d-9c04-5057-9277-af2bd00e148c` (see approved card artifact)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

On the H1 bar that opens at 20:00 UTC, the EA reads the just-closed H1 candle and uses its close as the session reference level. If that reference candle closed above its open, the EA places a sell limit at the reference close for a fade from below; if it closed below its open, the EA places a buy limit at the reference close for a fade from above. The pending order expires at 00:00 UTC, and any filled trade exits by the fixed 12-pip stop loss or fixed 12-pip take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_reference_utc_hour` | 20 | 0-23 | UTC hour when the just-closed H1 candle provides the reference close. |
| `strategy_window_end_utc_hour` | 0 | 0-23 | UTC hour when the unfilled limit order expires. |
| `strategy_stop_pips` | 12 | >0 | Fixed stop loss distance in pips. |
| `strategy_take_pips` | 12 | >0 | Fixed take profit distance in pips. |
| `strategy_max_spread_pips` | 0 | >=0 | Optional spread cap; 0 disables the cap and zero modeled spread never blocks trading. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed major forex pair with DWX coverage.
- `GBPUSD.DWX` - Card-listed major forex pair with DWX coverage.
- `USDJPY.DWX` - Card-listed major forex pair with DWX coverage.
- `AUDUSD.DWX` - Card-listed major forex pair with DWX coverage.

**Explicitly NOT for:**
- Index and commodity `.DWX` symbols - The card specifies major forex dead-time behavior, not equity-index or commodity sessions.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | Up to 4 hours between 20:00 UTC and 00:00 UTC, often shorter by SL/TP. |
| Expected drawdown profile | Mean-reversion fade with fixed 1:1 bracket risk. |
| Regime preference | Quiet off-hours mean reversion. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `34ee988d-9c04-5057-9277-af2bd00e148c`
**Source type:** book / local PDF archive
**Pointer:** Jason Fielder, Forex Trading Cheat Sheets (TriadFormula.com), local PDF archive
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11870_dead-time-range-fade.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-25 | Initial build from card | 066c3d78-36a3-4395-ad1a-6af223f142b4 |
