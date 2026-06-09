# QM5_10080_gh-victor-gap - Strategy Spec

**EA ID:** QM5_10080
**Slug:** `gh-victor-gap`
**Source:** `3b3ec48a-0755-5187-9331-afb36e174175` (see `strategy-seeds/sources/3b3ec48a-0755-5187-9331-afb36e174175/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

On each H1 closed bar, the EA compares the gap between that bar's open and the prior closed bar's close. It buys when the gap is -1.0% or lower, the gap bar closes bullish, and that close is above SMA(250). It sells when the gap is +1.0% or higher, the gap bar closes bearish, and that close is below SMA(250). Entries use an initial 1.0 x ATR(250) stop, a 1.0 x ATR(250) take profit, and an ATR trailing stop based on the latest closed-bar close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_gap_threshold_pct` | 1.0 | > 0 | Minimum absolute gap percent required for entry. |
| `strategy_sma_period` | 250 | >= 1 | Close-price SMA period used as the directional filter. |
| `strategy_atr_period` | 250 | >= 1 | ATR period used for stop, take-profit, and trailing distance. |
| `strategy_atr_sl_mult` | 1.0 | > 0 | Initial stop and trailing-stop ATR multiple. |
| `strategy_atr_tp_mult` | 1.0 | > 0 | Initial take-profit ATR multiple. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - they are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - card target for S&P 500-style index session gaps.
- `NDX.DWX` - card target for Nasdaq 100 index session gaps.
- `WS30.DWX` - card target for Dow 30 index session gaps.
- `XAUUSD.DWX` - card target for gap-prone gold/metals behaviour.

**Explicitly NOT for:**
- Any symbol not registered above - the card does not authorize an implicit wider universe.

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
| Trades / year / symbol | 35 |
| Typical hold time | hours |
| Expected drawdown profile | Mean-reversion losses are bounded by the ATR stop and framework fixed-risk sizing. |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3b3ec48a-0755-5187-9331-afb36e174175`
**Source type:** GitHub source code
**Pointer:** `https://github.com/victor-algo/channel/blob/main/LIVE%20BOT%20-%20Cr%C3%A9ation%20de%20trading%20bot%20from%20scratch/Gap%20Reversal/Expert/GapReversal.mq5`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10080_gh-victor-gap.md`

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
| v1 | 2026-06-09 | Initial build from card | c9e8cd34-2d5c-440d-9f8f-17c967ae07a3 |
