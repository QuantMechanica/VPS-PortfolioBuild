# QM5_12815_stat-mr-confint - Strategy Spec

**EA ID:** QM5_12815
**Slug:** stat-mr-confint
**Source:** forexalgotrader-statistical-mr-part39-2026
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

The EA computes a rolling mean and standard deviation of the last N closed-bar closes. It enters mean-reversion trades only when the last closed bar finishes outside the confidence band and the recent return distribution passes a normality gate: absolute skewness is below `strategy_skew_max` and absolute excess kurtosis is below `strategy_excess_kurt_max`. A close below the lower band opens a BUY toward the rolling mean; a close above the upper band opens a SELL toward the rolling mean. The hard stop is placed at `strategy_stop_sigma_mult` standard deviations from the entry side, with exits otherwise handled by the broker TP at the rolling mean and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lookback_bars` | 50 | 10-200 | Rolling window for mean, standard deviation, skewness, and excess kurtosis. |
| `strategy_band_sigma_mult` | 2.0 | 1.0-3.0 | Entry band multiplier around the rolling mean. |
| `strategy_stop_sigma_mult` | 3.0 | 2.0-5.0 | Wider sigma-band hard stop distance from the entry price. |
| `strategy_skew_max` | 0.5 | 0.1-1.5 | Maximum allowed absolute return skewness for the normality gate. |
| `strategy_excess_kurt_max` | 1.0 | 0.25-3.0 | Maximum allowed absolute excess kurtosis for the normality gate. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - gold is explicitly named by the card as a low-commission mean-reversion instrument.
- `NDX.DWX` - Nasdaq 100 maps the card's NDX/US100 index exposure to a verified DWX symbol.
- `SP500.DWX` - S&P 500 maps the card's US500/SP500 exposure to the canonical available custom symbol.
- `GDAXI.DWX` - DAX maps the card's GER40 exposure to the verified DAX DWX symbol.

**Explicitly NOT for:**
- Forex pairs - the card says to defer FX and focuses this build on gold and liquid indices.
- Non-matrix symbols such as `US100.DWX`, `US500.DWX`, `GER40.DWX`, `SPY.DWX`, and `SPX500.DWX` - these are not verified DWX registry symbols for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Additional generated variants | M15 and D1 setfiles, because the card names M15/H1 and a D1 variant |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Intraday to several bars; D1 variant may hold multiple days |
| Expected drawdown profile | Around 10% expected drawdown from card frontmatter |
| Regime preference | Mean-revert, best when recent returns are close to normally distributed |
| Win rate target (qualitative) | Medium to high, with profit factor target 1.30 from card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** forexalgotrader-statistical-mr-part39-2026
**Source type:** video/channel analysis
**Pointer:** `docs/research/FOREX_ALGO_TRADER_CHANNEL_ANALYSIS_2026-06-29.md` Part 39
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12815_stat-mr-confint.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-30 | Initial build from card | be9fb253-febe-4ef8-a1b3-d154403b4be1 |
