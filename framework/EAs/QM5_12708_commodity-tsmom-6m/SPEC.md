# QM5_12708_commodity-tsmom-6m - Strategy Spec

**EA ID:** QM5_12708
**Slug:** `commodity-tsmom-6m`
**Source:** `516fdfd0-0cc3-5474-8012-91879fbf79ed`
**Author of this spec:** Claude
**Last revised:** 2026-07-05

## 1. Strategy Logic

On the first D1 bar of each calendar month, the EA computes the trailing
six-month return `R6 = (Close[0]-Close[126])/Close[126]` (126 trading days).
If `R6 > 0` and flat, it opens LONG; if `R6 < 0` and flat, it opens SHORT. If
already positioned opposite to the new signal it closes and flips; if the
signal matches the current position it holds. The EA is always evaluating to
be in the market, once per month. A hard stop at 2.0x ATR(D1,20) is placed at
entry and held fixed for the month (no trailing/BE/partial). An ATR% floor
(ATR(20)/Close > 0.3%) blocks entries in dead-volatility regimes, and the
framework news filter blocks entries in a blackout window around high-impact
events. This EA is rebuilt in place (DL-069) from a prior single-symbol WTI
build under the same ea_id; the current card is a different, independently
G0-approved source (Zhang & Urquhart 2021) covering four commodity symbols.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_formation_bars` | 126 | 105-147 | R6 lookback in completed D1 bars (J=6 formation window) |
| `strategy_atr_period` | 20 | 14-20 | ATR period for the hard stop |
| `strategy_atr_stop_mult` | 2.0 | 1.5-2.5 | ATR hard-stop distance multiplier |
| `strategy_min_atr_pct` | 0.003 | - | Minimum ATR(20)/Close ratio required to trade |

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - gold, named in the card's R3 portable basket
- `XAGUSD.DWX` - silver, named in the card's R3 portable basket
- `XTIUSD.DWX` - WTI crude, named in the card's R3 portable basket
- `XNGUSD.DWX` - natural gas, named in the card's R3 portable basket

**Explicitly NOT for:**
- FX pairs / equity indices - the card's signal and cost model (commission
  ~$0.4-6.7/trade) is calibrated to commodity CFDs; monthly rebalancing on FX
  spreads is a different cost regime and not part of this card.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none (MN1 is untestable on .DWX; monthly cadence is derived via `QM_IsNewCalendarPeriod(PERIOD_MN1)`, which internally keys off D1 bar time) |
| Bar gating | `QM_IsNewBar()` + `QM_IsNewCalendarPeriod(PERIOD_MN1)` for the once-per-month rebalance edge |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 12 |
| Typical hold time | one monthly package (~21 trading days), or shorter if the ATR hard stop is hit |
| Expected drawdown profile | ~22% (card `expected_dd_pct`), commodity trend reversals bounded by the ATR stop |
| Regime preference | trend-following / time-series momentum |
| Win rate target | medium |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `516fdfd0-0cc3-5474-8012-91879fbf79ed`
**Source type:** `paper` (Zhang, H. & Urquhart, A., "Do momentum and reversal
strategies work in commodity futures?", Review of Behavioral Finance, 2021;
SSRN 3271841)
**Pointer:** `https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3271841`
**R1-R4 verdict (Q00):** all PASS / see
`artifacts/cards_approved/QM5_12708_commodity-tsmom-6m.md`

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). No live manifest, `T_Live` file, portfolio
gate, or AutoTrading setting is touched by this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-28 | Initial build from prior (single-symbol WTI, source MOP-TSMOM-2012) card | branch-local build |
| v2 | 2026-07-05 | Rebuild in place (DL-069) for current 4-symbol card (Zhang & Urquhart 2021); replaced hand-rolled iTime month-key gate (review-flagged framework_corset violation + 1-trade-then-silent smoke symptom) with `QM_IsNewCalendarPeriod`; registered XAUUSD/XAGUSD/XNGUSD alongside existing XTIUSD per P2 saturation rule | task 44bfeb0c-2896-4949-896b-390244680c06 |
