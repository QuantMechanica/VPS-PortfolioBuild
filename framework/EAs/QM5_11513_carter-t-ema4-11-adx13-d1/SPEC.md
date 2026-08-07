# QM5_11513_carter-t-ema4-11-adx13-d1 — Strategy Spec

**EA ID:** QM5_11513
**Slug:** `carter-t-ema4-11-adx13-d1`
**Source:** `8794b680-f6f4-5142-b12c-e5e0057e7bcf`
**Author of this spec:** Codex
**Last revised:** 2026-08-03

---

## 1. Strategy Logic

On the first tick of each new D1 bar, the EA buys when EMA(4) crossed above EMA(11) on the just-closed bar, ADX(13) is above 22, and +DI is above -DI; it sells when the opposite crossover occurs with -DI above +DI. It skips new Friday entries and blocks entries only when a genuinely positive spread exceeds 30 pips, so the zero modeled spread on `.DWX` tester symbols remains eligible. The default position has a 100-pip stop and no fixed target, closing on the opposite EMA crossover; the card-authorized fixed-target comparison uses `strategy_tp_pips` values of 100, 200, or 300 instead.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast_period` | 4 | test 4, 5, or 8 | Fast EMA period used by the crossover trigger. |
| `strategy_ema_slow_period` | 11 | test 10, 11, or 21 | Slow EMA period used by the crossover trigger. |
| `strategy_adx_period` | 13 | fixed at 13 | Period used for ADX, +DI, and -DI. |
| `strategy_adx_threshold` | 22.0 | test 18, 22, or 25 | ADX must be strictly above this trend-strength threshold. |
| `strategy_sl_pips` | 100 | fixed at 100 | Fixed fallback stop distance in pips. |
| `strategy_tp_pips` | 0 | 0, 100, 200, or 300 | `0` uses the opposite-EMA exit; a positive value selects that fixed target. |
| `strategy_no_friday_entry` | true | false or true | When true, no new position may open on Friday broker time. |
| `strategy_spread_cap_pips` | 30 | fixed at 30 | Blocks only a positive bid/ask spread wider than 30 pips. |

> Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — source-specified liquid FX major with verified D1 DWX history.
- `GBPUSD.DWX` — card-authorized QM expansion to a second liquid USD FX major with verified D1 DWX history.

**Explicitly NOT for:**

- Other `.DWX` instruments — the approved card limits this build to EURUSD and GBPUSD, so no other symbols are registered.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` on the D1 chart |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 35 |
| Trade frequency | approximately three entries per month, derived from the stated annual count |
| Typical hold time | variable multi-day hold until the opposite D1 EMA crossover, the 100-pip stop, or framework Friday close |
| Expected drawdown profile | clustered whipsaw losses in ranging markets, with the fixed stop capping each trade |
| Regime preference | ADX-confirmed directional trends |
| Win rate target (qualitative) | not specified by the approved card |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `8794b680-f6f4-5142-b12c-e5e0057e7bcf`
**Source type:** book
**Pointer:** Thomas Carter, *Forex Trend Following Strategies: 20 Trend Following Systems*, System #8, self-published 2014; source record `[[sources/carter-thomas-20-forex-trend-following-systems]]`.
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_11513_carter-t-ema4-11-adx13-d1.md`.

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
| v1 | 2026-08-03 | Initial build from card | 635a1c44-3fc2-4322-a8f1-45f57fac68da |
