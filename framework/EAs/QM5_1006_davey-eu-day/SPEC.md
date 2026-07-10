# QM5_1006_davey-eu-day - Strategy Spec

**EA ID:** QM5_1006
**Slug:** `davey-eu-day`
**Source:** SRC01 / SRC01_S02
**Author of this spec:** Codex
**Last revised:** 2026-07-10

---

## 1. Strategy Logic

This H1 EURUSD strategy places one mean-reversion limit order per trading day. It offers short above a fresh five-bar high when the latest close is below the close 80 bars ago, and offers long below a fresh five-bar low when the latest close is above the close 80 bars ago. Unfilled orders are cancelled on the next H1 bar; filled positions use the source's fixed-dollar stop and effectively unreachable profit cap, with framework Friday-close protection.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_xb` | 5 | 2-5 | Closed H1 bars in the fresh-high/fresh-low window. |
| `strategy_xb2` | 80 | 50-80 | Closed H1 momentum comparison lookback. |
| `strategy_pipadd` | 8 | 1-11 | Limit-order offset in EURUSD pips. |
| `strategy_stopl_usd` | 425 | 225-425 | Davey fixed-dollar stop translated through the symbol tick value. |
| `strategy_proft_usd` | 5000 | fixed | Source safety cap; intended to be effectively unreachable intraday. |
| `strategy_time_cutoff_hhmm` | 1500 | fixed | Card chart-time entry cutoff retained by the baseline. |

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Darwinex spot proxy for the card's CME Euro FX contract, registered at slot 0.

**Explicitly NOT for:**
- Non-EUR instruments - the fixed pip and dollar translation is specific to the Euro FX source contract.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 20 or more; Q02 requires at least 5/year |
| Typical hold time | intraday, up to the source session close |
| Expected drawdown profile | clustered losses when fresh extremes continue instead of reverting |
| Regime preference | liquid-session mean reversion after a counter-momentum thrust |
| Win rate target (qualitative) | medium |

## 6. Source Citation

This card was mechanised from:

**Source ID:** SRC01_S02
**Source type:** book
**Pointer:** Kevin J. Davey, *Building Algorithmic Trading Systems* (Wiley, 2014), Appendix C pp. 259-261 and Chapters 15, 18, and 19; canonical card at `strategy-seeds/cards/davey-eu-day_card.md`.
**R1-R4 verdict (Q00):** APPROVED; the canonical card records the G0 approval and A-tier primary citation.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-10 | Legacy Q02 infrastructure recovery | Added canonical spec/set metadata and refreshed the strict build artifact. |
