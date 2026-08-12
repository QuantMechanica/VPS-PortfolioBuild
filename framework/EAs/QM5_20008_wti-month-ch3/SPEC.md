# QM5_20008_wti-month-ch3 - Strategy Spec

**EA ID:** QM5_20008
**Slug:** `wti-month-ch3`
**Source:** `SZAKMARY-WTI-MCH3-2010` (see `strategy-seeds/sources/SZAKMARY-WTI-MCH3-2010/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-19

## 1. Strategy Logic

On the first D1 bar of each broker month, the EA reconstructs the four latest
completed WTI month-end closes. It buys when the just-completed close is
strictly above all three earlier closes, sells when it is strictly below all
three, and remains flat otherwise. Every prior-month package is closed before
the new signal is evaluated, and every entry has a frozen D1 ATR hard stop.

This is a completed-month close channel with a one-month holding period. It is
not a daily Donchian breakout, a moving-average band, a return-sign signal, a
52-week anchor, a month-opening range or an event/calendar rule.

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| `strategy_channel_months` | 3 | 3, 6, 9, 12 | Prior completed month-end closes in the source channel; Q02 uses 3 |
| `strategy_history_bars` | 180 | 140-400 | Bounded D1 history used to reconstruct month ends |
| `strategy_atr_period` | 20 | 14-30 | D1 ATR period for the frozen hard stop |
| `strategy_atr_sl_mult` | 4.0 | 3.0-5.0 | ATR multiple for the initial stop |
| `strategy_max_hold_days` | 35 | 35 | Stale guard around the next monthly renewal |
| `strategy_max_spread_points` | 1500 | 1000-2500 | Entry spread cap; zero modeled spread remains valid |

The baseline locks the source-tested `L=3` variant. Other source horizons are
predeclared variants, not an unconstrained optimization.

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` (slot 0) - the registered Darwinex WTI CFD proxy named by the
  OWNER commodity-sleeve mission and supported by local D1 history.

**Explicitly not for:**

- `XNGUSD.DWX` - natural gas already exists in the certified book and has
  different physical storage and seasonality dynamics.
- `XAUUSD.DWX` and `XAGUSD.DWX` - metal sleeves do not provide the requested
  new direct crude-oil exposure.
- Indices and FX - outside the paper-to-WTI extraction boundary.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none; broker-month keys are reconstructed from completed D1 bars |
| Bar gating | one framework `QM_IsNewBar()` consume on the D1 host |

The EA does not depend on `.DWX` MN1 tester bars.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 8; local cadence precheck measured 8.21 |
| Typical hold time | one broker month, capped at 35 calendar days |
| Expected drawdown profile | high WTI gap and false-breakout risk bounded by fixed dollar risk and a broker stop |
| Regime preference | persistent monthly crude-oil trends |
| Win rate target (qualitative) | low-to-medium, with trend-following payoff asymmetry |

## 6. Source Citation

**Source ID:** `SZAKMARY-WTI-MCH3-2010`
**Source type:** peer-reviewed paper plus complete author-uploaded manuscript
**Pointer:** `strategy-seeds/sources/SZAKMARY-WTI-MCH3-2010/source.md`
**R1-R4 verdict (Q00):** all PASS; see
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_20008_wti-month-ch3.md`.

Szakmary, A. C., Shen, Q. and Sharma, S. C. (2010), "Trend-following
trading strategies in commodity futures: A re-examination", *Journal of
Banking & Finance*, 34(2), 409-426, DOI
`10.1016/j.jbankfin.2009.08.004`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02-Q10) | `RISK_FIXED` | $1,000 per trade (HR4) |
| Live burn-in (Q13) | `RISK_PERCENT` | Min-lot equivalent under an OWNER manifest |
| Full live (post-Q13 PASS) | `RISK_PERCENT` | Allocated by the later portfolio process |

ENV-to-mode validation is enforced by `QM_FrameworkInit`. This build creates
no live setfile and does not touch T_Live, AutoTrading, deploy/T_Live manifests,
portfolio admission or the portfolio gate.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-19 | Initial source-exact monthly CH3 build | task `6c3d5c57-c3c3-4939-b4f8-ed5219d36c61` |
