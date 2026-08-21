# QM5_41093_wti-wclose-breakout-mom - Strategy Spec

**EA ID:** QM5_41093

**Slug:** `wti-wclose-breakout-mom`

**Strategy ID:** `MOP-SZAKMARY-WTI-WCLOSE-BRK-2026_S01`

**Source:** `MOP-SZAKMARY-WTI-WCLOSE-BRK-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-21

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of a new normalized broker week,
aggregate the exact two immediately completed Monday-anchored broker weeks.
Each package must contain three to five unique completed sessions under one
uniform energy-label convention.

Compute the parent package's aggregate high and low and select the newest
package's chronologically final close. Buy when that close is strictly above
the parent high; sell when it is strictly below the parent low. Equality, an
inside-range close, incomplete packages, nonadjacent anchors, and malformed
history consume the week flat. Hold one broker week with fixed-dollar risk and
a frozen completed-bar ATR hard stop.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_label_offset_seconds` | 86400 | uniform raw-to-energy-session label offset |
| `strategy_entry_grace_minutes` | 180 | first-week-bar execution window |
| `strategy_history_bars` | 30 | bounded D1 weekly OHLC buffer |
| `strategy_required_weeks` | 2 | exact newest and parent packages |
| `strategy_min_week_bars` | 3 | minimum sessions in each package |
| `strategy_max_week_bars` | 5 | maximum sessions in each package |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | preserve full-week ownership |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework input |

All strategy parameters are frozen for the Q02 baseline. There is no fitted
breakout buffer or optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0.
- Magic: `410930000`.
- No signal, hedge, conversion, ratio, or companion symbol exists.

## 4. Timeframe And Lifecycle

- Signal and execution timeframe: D1.
- Formation: exact parent and newest completed broker-week OHLC packages; the
  current week contributes no signal price.
- Trigger: newest chronological final close strictly outside the parent
  aggregate high-low range.
- Hold: until the first tick of the next broker week, with ten-day stale repair.
- Attempt: persist the current Monday anchor before every fallible signal or
  execution gate; never retry within that week.

## 5. Expected Behaviour

- Approximately ten to twenty-five completed WTI positions per full post-
  warm-up year; Q02 owns the binding activity verdict.
- Symmetric direct-WTI weekly structural continuation after accepted closing
  price discovery beyond the parent auction range.
- One fixed-risk position and one consumed attempt per broker week.
- A different carrier and mechanic do not establish decorrelation; Q09 owns
  the realized portfolio-correlation verdict.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Szakmary, A. C., Shen, Q., and Sharma, S. C. (2010), "Trend-following trading
strategies in commodity futures: A re-examination," *Journal of Banking &
Finance* 34(2), 409-426, DOI `10.1016/j.jbankfin.2009.08.004`.

Canonical bounded source packet:
`strategy-seeds/sources/MOP-SZAKMARY-WTI-WCLOSE-BRK-2026/source.md`.

The papers supply own-price continuation, WTI membership, and completed-
extrema channel lineage. The exact two-week high-low/final-close construction
is a disclosed QM hypothesis; no paper result transfers to this standalone
continuous-CFD implementation.

## 7. Risk Model And Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
Position sizing uses a frozen completed-bar `3.5*ATR(20,D1)` stop through the
V5 risk helper. Both news axes and Friday close are OFF.

There is no live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy manifest, portfolio admission, correlation waiver,
portfolio-gate change, own-body gate, close-location threshold, both-sided
outside expansion, range migration, current-week signal price, external feed,
retry, scale-in, grid, martingale, pyramid, target, trail, break-even move, or
partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-21 | approved build-directory identity | source approval `f0d8fe585`; source packet `cfaabdb97`; EA-ID reservation `2a20468ce`; Q00 card `04cbd4f8f`; planned governed magic `410930000` |
| v1 | 2026-08-21 | Q01 implementation PASS | exact two-week final-close breakout implementation; 13 reference checks; strict compile 0/0; static build check 0 failures; backtest-only fixed-risk preset |
