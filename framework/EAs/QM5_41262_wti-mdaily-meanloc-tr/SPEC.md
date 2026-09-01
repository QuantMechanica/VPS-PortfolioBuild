# QM5_41262_wti-mdaily-meanloc-tr - Strategy Spec

**EA ID:** QM5_41262

**Slug:** `wti-mdaily-meanloc-tr`

**Strategy ID:** `AI-CODEX-WTI-MDAILY-MEANLOC-20260901_S01`

**Source:** `AI-CODEX-WTI-MDAILY-MEANLOC-20260901`

**Last revised:** 2026-09-01

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar after a genuine normalized broker-
month transition, collect every close in the immediately completed month.
Require 17 through 23 weekday close labels plus one older adjacent-month bar
that proves the boundary. Apply one detected raw or `+86400` label convention
to the entire package and exclude all current-month prices.

Compute the arithmetic mean of the completed-month closes and the location
`final_close / mean_close - 1`. Buy above `1e-12`, sell below `-1e-12`, and
consume flat inside the neutral band. Persist the decision month before every
fallible gate, then hold at most one stop-protected position until the next
normalized broker month.

## 2. Locked Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | raw current-bar execution window |
| `strategy_history_bars_d1` | 45 | bounded completed-month buffer |
| `strategy_min_month_sessions` | 17 | minimum completed-month closes |
| `strategy_max_month_sessions` | 23 | maximum completed-month closes |
| `strategy_direction_epsilon` | 1e-12 | strict neutral location band |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry-cost guard |
| `strategy_deviation_points` | 20 | order deviation ceiling |

There is one Q02 baseline and no optimization surface.

## 3. Carrier And Cadence

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0; magic: `412620000`.
- Formation: all daily closes in the immediately completed normalized month.
- Direction: strict sign of final close versus same-month arithmetic mean.
- Hold: first tick in a later normalized month; forty-day stale repair.
- Expected activity: approximately ten to twelve completed positions per full
  post-warm-up year; retire below ten in any scored full year.

## 4. Duplicate Boundary

This is not the six-month-end mean in `QM5_13100`, daily-return median in
`QM5_41133`, monthly high-low range location in `QM5_41105`, month-open
residence count in `QM5_41130`, or raw boundary-to-endpoint return in
`QM5_20187`. It forms no daily return, sort, high-low range, month-open count,
or multi-month average. Reference fixtures require decision disagreement.

## 5. Risk And Lifecycle

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
Sizing uses a frozen completed-bar `3.5*ATR(20,D1)` hard stop and no target.
Both news axes, legacy news, Friday close, and stress rejection are OFF.

Malformed exposure is repaired before entry-only gates. The next-month exit
and forty-day stale repair run every tick. Terminal-persistent month state,
owned exposure, and same-month deal history prevent restart retries.

## 6. Source And Scope

The canonical governed source is
`strategy-seeds/sources/AI-CODEX-WTI-MDAILY-MEANLOC-20260901/source.md`.
Moskowitz, Ooi, and Pedersen (2012) support only the monthly WTI continuation
carrier. The mean-location rule is a disclosed pre-result QM interpretation;
no published performance or correlation result transfers.

No external runtime data, ML, banned signal indicator, optimization result,
current-month signal price, live/demo/shadow/stress set, manual backtest,
terminal control, portfolio-gate change, live manifest, `T_Live`, AutoTrading,
scale-in, grid, martingale, pyramid, target, trail, or partial exit exists.

## Framework Alignment

- no_trade: exact host/ID/slot and locked framework, risk, news, Friday,
  stress, and strategy inputs.
- trade_entry: normalized month clock, consumed attempt, complete close path,
  boundary proof, arithmetic mean/location, spread, quote, ATR, and stop.
- trade_management: malformed-position repair, next-month exit, stale repair.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v0 | 2026-09-01 | G0-approved card and governed magic `412620000` |

