# QM5_9716_bandy-trend-stretch-ratio-mr-index — Strategy Spec

**EA ID:** QM5_9716
**Slug:** `bandy-trend-stretch-ratio-mr-index`
**Approved card:** `docs/strategy_card.md`
**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Last revised:** 2026-08-24

## 1. Strategy Logic

On each new D1 bar, the EA evaluates the just-closed bar. It computes Bandy's
Trend-Stretch Ratio as `(Close(1) - SMA(50, Close, 1)) / ATR(14, 1)` and enters
long at the next session open only when TSR is at or below `-2.5` and the close
is above SMA(200). The strategy is long-only and allows one position per magic.

Open positions retain a fixed catastrophic stop at `3.0 * ATR(14)` from entry.
They close when TSR reaches `0.0` or after seven D1 trading bars. These exits,
the framework Friday close, and MAE tracking remain reachable even when entry
admission is blocked by warm-up, quote, spread, news, or kill-switch checks.

## 2. Parameters

| Input | Default | P3 candidates / constraint | Meaning |
|---|---:|---|---|
| `strategy_sma_ref_period` | 50 | 30 / 50 / 80 | TSR reference SMA period |
| `strategy_atr_period` | 14 | 10 / 14 / 20 | TSR and stop ATR period |
| `strategy_tsr_entry_thresh` | -2.5 | -2.0 / -2.5 / -3.0 | Deep-stretch long entry threshold |
| `strategy_tsr_exit_thresh` | 0.0 | -0.5 / 0.0 / +0.5 | Mean-reversion exit threshold |
| `strategy_sma_regime_period` | 200 | fixed by approved card | Long-regime SMA period |
| `strategy_time_stop_days` | 7 | 5 / 7 / 10 | Maximum D1 trading bars held |
| `strategy_sl_atr_mult` | 3.0 | fixed by approved card | Catastrophic stop distance |
| `strategy_spread_max_atr` | 0.25 | implementation guard | Entry-only spread ceiling as ATR fraction |
| `strategy_warmup_bars` | 200 | implementation guard | Minimum D1 history before entry |

Every declared strategy input has an executable use-site in the EA and is
sealed into each canonical backtest setfile.

## 3. Symbol Universe

| Symbol | Role | Magic slot |
|---|---|---:|
| `SP500.DWX` | Backtest target; live-promotion caveat applies | 2 |
| `NDX.DWX` | Parallel-validation/live-capable target | 1 |
| `WS30.DWX` | Parallel-validation/live-capable target | 4 |

No other symbol is authorized by the approved card. Historical registry
allocations outside this universe are not consumed by this delivery and have
no setfiles.

## 4. Timeframe

| Aspect | Contract |
|---|---|
| Chart and signal timeframe | `D1` only |
| Entry timing | First tick of the session after the qualifying D1 close |
| Bar gate | `QM_IsNewBar()` |
| Friday close | Framework override, declared as `V5_WEEKEND_RISK_POLICY` |
| News axes | Framework temporal/compliance inputs |
| Position cardinality | One long position per resolved magic |

`OnInit` fails closed unless `QM_FrameworkInit` and
`QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)` both succeed.

## 5. Expected Behaviour

The approved card expects approximately 20 trades per year per symbol. Build
and static validation establish only implementation conformity; the pipeline,
not this SPEC, determines economic validity and promotion.

## 6. Source Citation

The strategy is authorized by `docs/strategy_card.md`, sourced from Howard
Bandy's *Quantitative Technical Analysis* (2015), ISBN 978-0-9791037-7-1,
under source ID `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`.

### Framework alignment

| Card rule | Implementation surface |
|---|---|
| No-trade / operational controls | `QM_KillSwitchCheck`, news framework, Friday-close framework, entry-only spread/warm-up guard |
| Trade entry | `Strategy_EntrySignal` |
| Trade management | `Strategy_ManageOpenPosition` seven-trading-day stop |
| Trade close | `Strategy_ExitSignal` TSR zero-cross plus framework close helper |
| Risk / stop / magic | `QM_StopATR`, framework risk modes, `QM_FrameworkMagic` |
| MAE | `QM_FrameworkTrackOpenPositionMae` at the start of `OnTick` |

## 7. Risk Model

| Environment | Active risk mode | Inactive mode |
|---|---|---|
| Backtest | `RISK_FIXED=1000` | `RISK_PERCENT=0` |
| Live packaging | `RISK_PERCENT` | `RISK_FIXED=0` |

The EA resolves magic through `QM_FrameworkMagic()` / `QM_MagicResolver`; it
does not compute magic numbers locally.

## Revision history

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-23 | Initial generated specification |
| v2 | 2026-08-24 | Reconciled D1, parameter, symbol, exit-reachability, and execution-contract requirements with the approved card |
