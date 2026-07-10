# QM5_13114_wti-roc14-xtrm - Strategy Spec

**EA ID:** QM5_13114
**Slug:** `wti-roc14-xtrm`
**Source:** `GURRIB-WTI-ROC14-2024`
**Author of this spec:** Codex
**Last revised:** 2026-07-10

## 1. Strategy Logic

This EA reconstructs completed WTI month-end closes from `XTIUSD.DWX` D1
history. A 14-month rate of change crossing outward through +40% establishes a
contrarian short state; a crossing outward through -40% establishes a
contrarian long state. The latest non-zero state persists until the opposite
crossing, and the EA expresses it as one non-overlapping fixed-risk package per
month with a frozen ATR hard stop.

At a broker-month transition the previous package closes. The EA then recovers
the last valid source state from bounded history and opens the next monthly
package when that state is non-zero. A 35-day guard closes any stale package.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_roc_months` | 14 | locked at 14 | Completed month-end ROC horizon |
| `strategy_extreme_pct` | 40.0 | locked at 40.0 | Symmetric overbought/oversold crossing level |
| `strategy_state_history_months` | 360 | 240-360 | Bounded history used to recover the latest state |
| `strategy_atr_period` | 20 | 14-30 | D1 ATR period for the hard stop |
| `strategy_atr_sl_mult` | 4.0 | 3.0-5.0 | Frozen ATR stop distance |
| `strategy_max_hold_days` | 35 | locked at 35 | Stale guard around monthly rollover |
| `strategy_max_spread_points` | 1500 | 1000-2500 | Entry spread cap |

The 14-month horizon, 40% threshold, direction map, monthly package cadence,
and 35-day stale guard are locked in Q02.

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` - the card and paper are WTI-specific; registered as magic slot
  0 with magic `131140000`.

**Explicitly not for:**

- `XNGUSD.DWX` - natural gas has a different physical seasonal structure and
  is not in the source test.
- XAU, XAG, indices, or FX - this is not a generic ROC fanout.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | D1 bars grouped into completed broker-calendar months |
| Bar gating | one `QM_IsNewBar()` consume; `QM_CalendarPeriodKey(PERIOD_MN1)` identifies month transitions |

The EA does not read MN1 bars because `.DWX` monthly history is not reliable in
the tester. One bounded `CopyRates` call runs only on a month-transition D1 bar.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 6-12 completed monthly packages after warm-up; prior 9 |
| Typical hold time | one broker month, capped at 35 calendar days |
| Expected drawdown profile | high; sparse source state changes and WTI gaps can create long adverse regimes |
| Regime preference | long-horizon WTI overreaction followed by reversal |
| Win rate target (qualitative) | unknown / medium-low until Q02 |

The paper reports only eight continuous source positions over about 20 years.
Monthly package accounting raises the Q02 package count without inventing
intramonth signals; costs and CFD basis can still invalidate the port.

## 6. Source Citation

**Source ID:** `GURRIB-WTI-ROC14-2024`

**Source type:** peer-reviewed open-access paper plus official exchange
supplement.

**Pointer:** `strategy-seeds/sources/GURRIB-WTI-ROC14-2024/source.md`, DOI
https://doi.org/10.32479/ijeep.16520, and CME WTI benchmark page
https://www.cmegroup.com/markets/energy/wti-crude-oil-futures.html.

**R1-R4 verdict (Q00):** all PASS; see
`artifacts/cards_approved/QM5_13114_wti-roc14-xtrm.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`. This build has one
backtest setfile and no live setfile. Friday close is disabled by the approved
card to preserve the monthly hold; month rollover, the stale guard, and the
broker ATR stop remain active.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-10 | Initial build from card | build task `3283ae39-9e38-40b2-9eb9-24637074a3df` |

