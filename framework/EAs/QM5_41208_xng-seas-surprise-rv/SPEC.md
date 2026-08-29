# QM5_41208_xng-seas-surprise-rv - Strategy Spec

Status: `G0 APPROVED; IMPLEMENTED; Q01 VALIDATION PENDING`

## Identity

**EA ID:** QM5_41208

- EA ID: `QM5_41208`
- slug: `xng-seas-surprise-rv`
- strategy ID: `KELOHARJU-MISHRA-XNG-SEASSURPRISE-2026_S01`
- source ID: `KELOHARJU-MISHRA-XNG-SEASSURPRISE-2026`
- source packet: `strategy-seeds/sources/KELOHARJU-MISHRA-XNG-SEASSURPRISE-2026/source.md`
- source approval: `decisions/2026-08-30_xng_seasonal_surprise_reversion_source_approval.md`
- approved card: `strategy-seeds/cards/approved/QM5_41208_xng-seas-surprise-rv_card.md`
- G0 decision: `decisions/2026-08-30_qm5_41208_xng_seasonal_surprise_reversion_g0.md`
- host/traded symbol: exact `XNGUSD.DWX`, D1, slot 0
- deterministic magic: `412080000`

## 1. Strategy Logic

At the first genuine normalized D1 broker-month boundary, reconstruct the
just-completed XNG log return. For that realized calendar month, collect the
same-month return in each of the ten earlier exact years. A missing older year
is skipped without substitution; five observations are mandatory.

Compute the arithmetic mean and sample standard deviation with denominator
`n-1`, excluding the realized observation. Sell when the standardized surprise
is strictly above `+0.50+1e-10`, buy when it is strictly below
`-0.50-1e-10`, and otherwise remain flat. Persist the decision `yyyymm` before
history or any later gate, so every outcome consumes the month.

## 2. Parameters

| Input | Value | Role |
|---|---:|---|
| `strategy_history_years` | 10 | maximum earlier same-calendar years |
| `strategy_min_observations` | 5 | minimum valid historical returns |
| `strategy_entry_z` | 0.50 | strict surprise band |
| `strategy_signal_tolerance` | 1e-10 | equality buffer |
| `strategy_history_bars_d1` | 3000 | bounded endpoint scan |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen stop distance |
| `strategy_max_hold_days` | 40 | stale repair |
| `strategy_max_spread_points` | 3000 | nonnegative cost ceiling |

Q02 has one baseline and no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XNGUSD.DWX`.
- Symbol slot: `0`; deterministic magic: `412080000`.
- One direct XNG leg only; no hedge, companion, conversion, or external feed.

### Exposure And Lifecycle

The EA owns at most one direct XNG position. It uses `RISK_FIXED=1000`, one
frozen `3.5*ATR(20,D1)` hard stop, no target, and no intramonth signal exit.
The ordinary exit is the next normalized broker-month boundary; 40 elapsed
days is a survivor guard. Malformed or duplicate owned exposure is flattened
before entry-only gates. Both news axes, legacy news, and Friday close are OFF.

## 4. Timeframe

Execution and the structural clock are D1. Entry is at most once per normalized
broker month. Formation uses the just-completed month and five to ten disjoint
earlier observations of that same calendar month. Ordinary exit is the next
broker-month boundary.

## 5. Expected Behaviour

The pre-result cadence prior is approximately six to nine completed positions
per full post-warm-up year. Invalid label mapping, endpoints, insufficient
history, nonpositive sample deviation, interior z score, quote, risk, or order
state can consume a month flat. Q02 retires below five completed positions in
any full scored year. Q09 alone may establish portfolio correlation.

## 6. Source Citation

Keloharju, Linnainmaa, and Nyberg (2016), *Journal of Finance* 71(4), supply
the same-calendar commodity information object, natural-gas membership, and a
five-year history floor. Mishra and Smyth (2016), *Economic Modelling* 59,
supply direct natural-gas fixed-frequency contrarian evidence and its adverse
robustness caveat. Neither tests this exact standardized-surprise conjunction
or Darwinex CFD implementation.

Canonical dedup was clean across 4,707 identity rows, 1,353 cards, and 45 Wiki
nodes. Unlike `QM5_12567`, this is monthly, symmetric, and oscillator-free;
unlike `QM5_20054`, it removes same-calendar expectation and scales the
residual; unlike `QM5_20100`/`QM5_41205`, it fades the just-realized surprise
instead of following the upcoming-month historical location; unlike
`QM5_21517`, it is a one-leg natural-gas rule rather than a metals basket.

## 7. Risk Model

The sole preset is backtest-only and locks `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Every valid entry receives one
frozen `3.5*ATR(20,D1)` hard stop and no target. Signal magnitude cannot alter
risk. No live, demo, shadow, stress, or optimization preset is authorized.

## Framework Alignment

| Card rule | Implementation |
|---|---|
| exact host, identity, risk, news/Friday modes, locked inputs | `Strategy_NoTradeFilter` |
| uniform label normalization and genuine month boundary | decision-clock helpers |
| completed month plus exact earlier same-calendar endpoints | `Strategy_CompletedMonthReturn` and loader |
| arithmetic mean, `n-1` scale, strict z boundaries, contrarian side | `Strategy_SeasonalSurpriseSignal` |
| durable consumed month | attempt helpers and `Strategy_PrepareDecisionSignal` |
| quote/spread, completed ATR, frozen stop | `Strategy_EntrySignal` |
| malformed, later-month, and stale repair | lifecycle helper |
| no discretionary signal exit | `Strategy_ExitSignal` returns false |

## Validation And Kill Contract

Q01 must pass independent calendar, endpoint, realized-exclusion, missing-year
skip, five-through-ten-sample, arithmetic mean, `n-1` scale, strict boundary,
contrarian-side, zero-spread, durable-attempt, lifecycle, card, registry,
resolver, setfile, static-build, and strict-compile checks.

Retire rather than tune on zero trades; fewer than five completed positions in
a full post-warm-up year; nonpositive governed economics; wrong endpoint,
sample, mean, denominator, score, side, attempt, stop, spread, or lifecycle;
current-month leakage; retry; missing stop; or registry mismatch.

## Safety Boundary

This is a non-live branch build. It creates no live/demo/shadow/stress preset,
deployment manifest, T_Live change, portfolio-gate change, admission, or
promotion entitlement. Agents never toggle AutoTrading.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-30 | G0-approved XNG standardized seasonal-surprise reversion build |
