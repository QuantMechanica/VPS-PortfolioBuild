# QM5_41397_wti-seas-surprise-rv — Strategy Spec

Status: `G0 APPROVED; IMPLEMENTED; Q01 VALIDATION PENDING`

## Identity

**EA ID:** QM5_41397

- slug: `wti-seas-surprise-rv`
- strategy ID: `KELOHARJU-YANG-WTI-SEASSURPRISE-2026_S01`
- source ID: `KELOHARJU-YANG-WTI-SEASSURPRISE-2026`
- approved card: `strategy-seeds/cards/approved/QM5_41397_wti-seas-surprise-rv_card.md`
- G0 decision: `decisions/2026-09-09_qm5_41397_wti_seasonal_surprise_reversion_g0.md`
- host/traded symbol: exact `XTIUSD.DWX`, D1, slot 0
- deterministic magic: `413970000`

## 1. Strategy Logic

At the first genuine normalized broker-month boundary, reconstruct WTI's
just-completed monthly log return. For that realized calendar month, collect
the same-month return from up to ten earlier years, excluding the realized
observation and requiring at least five valid samples.

Compute the arithmetic mean and `n-1` sample deviation. Sell only when the
standardized realized-minus-seasonal surprise exceeds `+0.50+1e-10`; buy only
below `-0.50-1e-10`; consume all other states flat. Persist `yyyymm` before
history or any later gate so every outcome consumes the month.

## 2. Parameters

| Input | Value | Role |
|---|---:|---|
| `strategy_history_years` | 10 | earlier same-calendar-year cap |
| `strategy_min_observations` | 5 | minimum valid sample |
| `strategy_entry_z` | 0.50 | strict surprise band |
| `strategy_signal_tolerance` | 1e-10 | equality buffer |
| `strategy_history_bars_d1` | 3000 | bounded endpoint scan |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen stop distance |
| `strategy_max_hold_days` | 40 | stale repair |
| `strategy_max_spread_points` | 1500 | nonnegative cost ceiling |

Q02 has one baseline and no optimization surface.

## 3. Symbol Universe

The host and sole traded symbol is exact `XTIUSD.DWX`; slot 0 resolves to
magic `413970000`. The EA never reads or trades XNG, metals, indices, a hedge,
or any external feed.

### Exposure And Lifecycle

Own at most one WTI position. Use `RISK_FIXED>0` with `RISK_PERCENT=0`, one
frozen `3.5*ATR(20,D1)` stop, no target, and no intramonth signal exit. Close
at the next normalized month boundary; 40 days is stale repair. Repair
malformed owned exposure before entry-only gates. Framework news and Friday
inputs remain configurable and are never source-pinned.

## 4. Timeframe

Execution and structural clock are D1. Entry is at most once per normalized
broker month. Formation uses only completed month endpoints. Ordinary exit is
the next broker-month boundary.

## 5. Expected Behaviour

Pre-result cadence is approximately six to nine completed positions per full
post-warm-up year. Q02 retires below five in any full scored year. Invalid
labels, endpoints, sample, scale, interior score, quote, risk, or order state
consume a month flat. Q09 alone may establish portfolio correlation.

## 6. Source Citation

Keloharju, Linnainmaa, and Nyberg (2016), *Journal of Finance* 71(4), supply
same-calendar commodity information and explicit crude-oil membership. Yang,
Goncu, and Pantelous (2017), SSRN 3069253, supply academic commodity-reversal
lineage. Neither tests this exact standardized WTI residual or CFD port.

Canonical dedup found no exact identity. The expected fuzzy neighbors are
`QM5_41208` on XNG with the same side, `QM5_41209` on WTI with the opposite
side, and `QM5_41393` on XNG with the opposite side. Carrier and direction are
both load-bearing.

## 7. Risk Model

The sole preset is backtest-only and uses `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Every valid entry gets one frozen
hard stop. Signal magnitude cannot alter risk. No live/demo/shadow/stress or
optimization preset is authorized.

## Framework Alignment

| Card rule | Implementation |
|---|---|
| exact host, identity, risk mode, locked `strategy_*` | `Strategy_NoTradeFilter` |
| month boundary and uniform labels | decision-clock helpers |
| realized plus earlier same-calendar endpoints | completed-month loader |
| mean, `n-1` scale, strict band, contrarian side | seasonal-surprise signal |
| durable consumed month | attempt helpers |
| quote/spread, completed ATR, frozen stop | `Strategy_EntrySignal` |
| malformed, later-month, stale repair | `Strategy_ManageOpenPosition` |
| configurable news axes | `Strategy_NewsFilterHook` |

## Validation And Kill Contract

Q01 must pass calendar, endpoint, exclusion, missing-year, sample arithmetic,
strict boundary, side, zero-spread, attempt, lifecycle, card, registry,
resolver, setfile, static-build, PACER pin-audit, and strict-compile checks.
Retire rather than tune on zero trades, sub-floor density, nonpositive
governed economics, implementation drift, current-month leakage, retry,
missing stop, or registry mismatch.

## Safety Boundary

This is a branch-only non-live build. It creates no live/demo/shadow/stress
preset, deployment manifest, `T_Live` change, portfolio-gate change,
admission, or promotion entitlement. Agents never toggle AutoTrading.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-09-09 | G0-approved WTI standardized seasonal-surprise reversion build |
