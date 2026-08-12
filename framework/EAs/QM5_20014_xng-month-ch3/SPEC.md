# QM5_20014_xng-month-ch3 - Strategy Spec

**EA ID:** QM5_20014
**Slug:** `xng-month-ch3`
**Source:** `SZAKMARY-XNG-MCH3-2010` (see `strategy-seeds/sources/SZAKMARY-XNG-MCH3-2010/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-20

## 1. Strategy Logic

On the first D1 bar of each broker month, the EA reconstructs the four latest
completed Natural Gas month-end closes. It buys when the just-completed close
is strictly above all three earlier closes, sells when it is strictly below all
three, and remains flat otherwise. Every prior-month package is closed before
the new signal is evaluated, and every entry has a frozen D1 ATR hard stop.

This is a completed-month close channel with a one-month holding period. It is
not a daily Donchian breakout, an RSI pullback, a moving-average band, a
return-sign signal or an event/calendar rule.

## 2. Parameters

| Parameter | Default | Authorized value | Meaning |
|---|---:|---:|---|
| `strategy_channel_months` | 3 | 3 | Prior completed month-end closes in the source channel |
| `strategy_history_bars` | 180 | 180 | Bounded D1 history used to reconstruct month ends |
| `strategy_atr_period` | 20 | 20 | D1 ATR period for the frozen hard stop |
| `strategy_atr_sl_mult` | 4.0 | 4.0 | ATR multiple for the initial stop |
| `strategy_max_hold_days` | 35 | 35 | Stale guard around the next monthly renewal |
| `strategy_max_spread_points` | 3000 | 3000 | XNG entry spread cap; zero modeled spread remains valid |

All parameters are locked for the Q02 baseline. A parameter or rule variant
requires an amended or new approved card.

## 3. Symbol Universe

**Designed for:**

- `XNGUSD.DWX` (slot 0) - registered Darwinex Natural Gas CFD proxy named by
  the OWNER commodity-sleeve mission and supported by local D1 history cache.

**Explicitly not for:**

- `XTIUSD.DWX` - the same source family already has the disclosed WTI carrier
  `QM5_20008`; this card is the Natural Gas implementation.
- `XAUUSD.DWX` and `XAGUSD.DWX` - metal sleeves do not provide the selected
  energy-carrier logic.
- Indices and FX - outside the paper-to-XNG extraction boundary.

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
| Trades / year / symbol | 6 as a conservative prior; Q02 must measure it |
| Typical hold time | one broker month, capped at 35 calendar days |
| Expected drawdown profile | high XNG gap and false-breakout risk bounded by fixed dollar risk and a broker stop |
| Regime preference | persistent monthly Natural Gas trends |
| Win rate target (qualitative) | low-to-medium, with trend-following payoff asymmetry |

## 6. Source Citation

**Source ID:** `SZAKMARY-XNG-MCH3-2010`
**Source type:** peer-reviewed paper plus complete author-uploaded manuscript
**Pointer:** `strategy-seeds/sources/SZAKMARY-XNG-MCH3-2010/source.md`
**R1-R4 verdict (G0):** all PASS; see the approved card.

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
| v1 | 2026-07-20 | Initial source-backed Natural Gas monthly CH3 build | task `35c924e1-3fa4-460c-8c39-1f83aabffa35` |
