# QM5_21518_wti-brent-cfm - Strategy Spec

**EA ID:** QM5_21518
**Slug:** `wti-brent-cfm`
**Source:** `MOP-CME-WTI-BRENT-CFM-2026`
**Author:** Codex
**Last revised:** 2026-08-14

## 1. Strategy Logic

On the first `XTIUSD.DWX` D1 bar after a genuine broker-month transition,
consume one attempt and intersect bounded completed WTI and read-only
`XBRUSD.DWX` D1 histories at exact timestamps. Reconstruct thirteen
consecutive synchronized broker-month endpoints ending in the immediately
completed month. Calculate an independent exact twelve-month log return for
each benchmark.

Buy WTI only when both returns are strictly positive. Sell WTI only when both
are strictly negative. A zero, disagreement, stale endpoint, or invalid state
consumes the month flat. Brent is never ordered.

Every entry has a frozen `3.5*ATR(20,D1)` hard stop, no take-profit, monthly
replacement, and a forty-calendar-day stale exit.

## 2. Parameters

| Parameter | Default | Authorized values | Meaning |
|---|---:|---|---|
| `strategy_trend_months` | `12` | `[12]` | Exact completed-month horizon for both benchmarks |
| `strategy_history_bars_d1` | `500` | `[500]` | Bounded completed-D1 copy per symbol |
| `strategy_max_endpoint_gap_days` | `10` | `[10]` | Latest common endpoint freshness |
| `strategy_return_tolerance` | `1e-10` | `[1e-10]` | Endpoint-versus-chain equality tolerance |
| `strategy_atr_period_d1` | `20` | `[20]` | Completed D1 ATR stop estimator |
| `strategy_atr_sl_mult` | `3.5` | `[3.5]` | Frozen hard-stop multiple |
| `strategy_max_hold_days` | `40` | `[40]` | Missed-rollover stale guard |
| `strategy_max_spread_points` | `1500` | `[1500]` | WTI entry spread ceiling |

All values are locked. No optimization or alternate sign threshold is
authorized.

## 3. Symbol Universe

The only traded symbol is registered `XTIUSD.DWX`, D1, magic slot 0, magic
`215180000`. `XBRUSD.DWX` is a read-only state input with no slot, magic, or
order authority. This is an outright WTI carrier, not a WTI/Brent basket,
spread, or hedge.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Signal history | Thirteen consecutive synchronized completed broker-month endpoints |
| Decision clock | First processed D1 bar after a genuine broker-month transition |
| Stop estimator | Completed `ATR(20,D1)` |
| Hold | Until the next month transition, capped at 40 calendar days |

Current D1 prices and incomplete monthly returns are excluded.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 8-11 after warm-up; retire below 5 |
| Typical hold time | One broker month, capped at 40 days |
| Direction | Long when both crude benchmarks trend up; short when both trend down |
| Risk | One fixed-dollar WTI position; Brent confirmation cannot scale size |

The crude-oil carrier is a diversification hypothesis relative to the
incumbent XAU/SP500/NDX/XNG book. Q09 alone owns realized portfolio overlap.

## 6. Source Citation

Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), "Time
Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

CME WTI-Brent Financial futures, ICE Brent/WTI Futures Spread, and U.S. EIA
Brent-WTI benchmark analysis, preserved in
`strategy-seeds/sources/CME-WTI-BRENT-SPREAD-2026/source.md`.

The primary source supplies WTI membership, own-return sign, a twelve-month
horizon, and monthly renewal. The benchmark records establish linked but
distinct crude markets. Same-sign confirmation is a locked QM hypothesis, not
a source-tested trading rule.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02-Q10) | `RISK_FIXED` | `$1000` per trade |
| Live burn-in | `RISK_PERCENT` | Not authorized |
| Full live | `RISK_PERCENT` | Not authorized |

The one backtest set uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

## 8. Exact Arithmetic Contract

Intersect completed WTI and Brent D1 bars by exact timestamp. Require strict
chronology, positive finite closes, a newest common endpoint before the
decision bar, and no more than ten calendar days stale. Within that common
history, retain the final common close of each broker month and require the
latest thirteen month keys to be consecutive and end in the immediately
completed broker month.

```text
wti_12m   = ln(WTI_end_12 / WTI_end_0)
brent_12m = ln(Brent_end_12 / Brent_end_0)
```

For each benchmark, require the endpoint return to equal the sum of its twelve
component monthly log returns within `1e-10`. Both strictly positive maps to
long WTI; both strictly negative maps to short WTI; equality or disagreement
maps to flat.

## 9. Non-Duplicate Boundary

`QM5_12603_wti-tsmom12m` is unconditional and never reads Brent.
`QM5_12843`, `QM5_12848`, and `QM5_12860` form and trade two-leg WTI/Brent
spread states; this EA neither forms a spread nor orders Brent. Brent trend
EAs trade Brent itself, internal WTI confirmation EAs compare WTI horizons,
and `QM5_12844` is a daily Donchian/ADX breakout. The synchronized endpoint
set, independent signs, strict agreement, WTI-only execution, and consumed
monthly attempt are jointly load-bearing.

## 10. Kill Criteria

Retire below five completed positions per full post-warm-up year, on
nonpositive governed economics, or at later portfolio-correlation rejection.
Fail on wrong endpoint count, timestamp mismatch, nonconsecutive months,
wrong return horizon, endpoint-chain mismatch, sign-disagreement entry, any
Brent order, repeated attempt, missing stop, hold beyond forty days, risk
mismatch, or nondeterminism. No rescue parameter is authorized.

## 11. Safety Boundary

Research, deterministic allocation, build, strict compile/Q01, one fixed-risk
backtest set, and one paced non-live Q02 enqueue only. No manual backtest,
live/demo/shadow/stress/optimization set, `T_Live` access, AutoTrading change,
deploy manifest, portfolio-gate edit, portfolio admission, or correlation
waiver is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-14 | Initial implementation from approved card | Q01 pending |
| v2 | 2026-08-14 | Validate locked benchmark-confirmation build | Q01 PASS; Q02 pending |

## 12. Q01 Status

PASS. The registered one-slot EA implements synchronized WTI/Brent month-end
reconstruction, independent exact twelve-month returns, strict sign
confirmation, restart-safe consumed attempts, a one-position WTI lifecycle,
and a frozen ATR hard stop while leaving Brent read-only. Strict compile
passed with zero errors and warnings; the targeted build check passed with
zero failures and warnings; six independent support, arithmetic, direction,
calendar, and carrier-separation tests passed; and P1 found the compiled
`.ex5`. Q02 work item `baee9255-3daf-4a85-b300-07a4f57ac0cf` is pending.
