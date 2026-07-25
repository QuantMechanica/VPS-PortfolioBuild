# STR-088 — Codex independent mechanical specification

## Source boundary

- Source: foff00, “4x25MA Simple Strategy,” ForexFactory thread 932507.
- Evidence read for this blind specification: `00_source.md` and the `STR-088` row in `SOURCE_LEDGER.csv` only.
- The unrelated three-EMA link, `NRTR_ATR_STOP.ex4`, and the later MACD Sample discussion are excluded.
- Status: independent Codex draft for G0 comparison; not an approval, profitability verdict, or live-use authorization.

## Strategy hypothesis

On an H4 execution cadence, trade only when the most recently completed M15, H1, H4, and D1 closes all agree on the same side of their own 25-period EMA. Enter during the liquid London-open-to-New-York-close window and use H4 ATR(14) to define a 2 ATR stop and a 3 ATR baseline target.

## Instrument and timeframe scope

- Baseline cohort: validated `.DWX` FX majors and JPY crosses, tested one symbol at a time. This is the ledger-defined cohort; the source does not name a pair.
- Execution and decision cadence: H4.
- Direction filters: M15, H1, H4, and D1 on the same symbol.
- The later M15/scalper experiment and its unrelated trailing-stop EA are not part of this H4 baseline.

## Closed-bar synchronization

At the first tick of each new broker H4 bar:

- Let `decisionTime` be the open time of that new H4 bar.
- For each filter timeframe, select the newest bar whose close time is less than or equal to `decisionTime`; never read a forming M15, H1, H4, or D1 bar.
- For confirmation depth `N`, compare each of the last `N` independently completed closes with its correspondingly indexed EMA(25).
- Default `N=1`; `N=2` and `N=3` are source-permitted alternatives because “closed bars (1-3)” does not select one value.
- A missing, stale, or non-synchronized higher-timeframe series invalidates that H4 decision rather than falling back to a forming value.

## Mechanical rules

1. Evaluate at most once per new H4 bar and only when all four closed-bar series and all indicator values are valid.
2. Resolve the entry-session state in UTC and convert broker timestamps with `QM_BrokerToUTC`. Permit new exposure only from the calendar-aware London open through the calendar-aware New York close.
3. Do not hard-code one broker-hour pair for the full year. If the named session calendar or its DST state cannot be resolved, fail closed for new entries.
4. A long setup exists when, for every timeframe in `{M15,H1,H4,D1}` and every closed bar `i` in `[1,N]`, `Close(tf,i) > EMA25(tf,i)`.
5. A short setup exists when every corresponding closed close is strictly below its EMA25. Equality on any timeframe produces no setup.
6. If flat and exactly one setup is valid, submit one market entry at the first executable price of the new H4 bar. Do not place both directions, pyramid, or retain a pending entry.
7. Read ATR(14) from the just-closed H4 bar. Reject the setup if ATR is absent, non-finite, or non-positive.
8. For a long, attach `SL = fill - 2 * ATR14_H4` and `TP = fill + TargetATR * ATR14_H4`. For a short, mirror those distances.
9. `TargetATR=3` is the baseline. `TargetATR=4` is a separately labelled source-supported variant; do not optimize an undeclared continuous value between them.
10. Stops and targets are calculated from the actual fill and normalized to tick size. If valid broker geometry cannot be attached at entry, do not leave an unprotected position.
11. Maintain at most one open position per symbol/magic. When flat again, a still-valid alignment may create a new trade at the next H4 decision; the source gives no one-trade-per-trend or cooldown rule.
12. Close only by the fixed stop, fixed target, or mandatory framework safety handling. The source does not specify an opposite-stack exit, trailing stop, break-even rule, or time exit for this strategy.
13. News blackout and account-level risk gates override signal creation. No pending entry is used, so there is no order that can become newly exposed inside a blackout.

## Required inputs and baseline defaults

| Input | Baseline | Allowed research variation | Evidence status |
|---|---:|---:|---|
| `ExecutionTF` | H4 | fixed | sourced |
| `FastFilterTF` | M15 | fixed | sourced |
| `MidFilterTF` | H1 | fixed | sourced |
| `ExecutionFilterTF` | H4 | fixed | sourced |
| `SlowFilterTF` | D1 | fixed | sourced |
| `EMAPeriod` | 25 | fixed baseline | sourced; author says MA may later be made changeable |
| `EMAMethod` | EMA | fixed baseline | sourced |
| `EMAAppliedPrice` | Close | fixed | interpretation I-01 |
| `ConfirmClosedBars` | 1 | discrete `{1,2,3}` | source range; baseline selection is interpretation I-02 |
| `ATRPeriod` | 14 | fixed | sourced |
| `ATRTimeframe` | H4 | fixed baseline | interpretation I-04 |
| `StopATR` | 2.0 | fixed | sourced |
| `TargetATR` | 3.0 | discrete source variant `4.0` | sourced range |
| `EntrySessionProfile` | `LONDON_OPEN_TO_NY_CLOSE` | fixed baseline | sourced named window; exact clock handling is interpretation I-05 |
| `OppositeAlignmentExit` | disabled | none | not sourced |
| `TimeExitBars` | disabled | none | not sourced |
| `VolatilityPercentileGate` | disabled | none | not sourced |
| `StrategySpreadVeto` | disabled | none | not sourced |
| `RISK_FIXED` | positive test lot from canonical set generation | positive only | house backtest constraint |
| `RISK_PERCENT` | 0 in backtests | live configuration at or below 1.0 only with separate authorization | house constraint |

## Interpretation register

- **I-01 — meaning of price:** the source says “price” is above/below EMA and requires closed bars. Baseline therefore compares each completed close, not high, low, Bid, Ask, or the forming price.
- **I-02 — “closed bars (1-3)”:** this could mean any one of shifts 1–3 or persistence across one to three bars. Baseline requires persistence across the latest `N` bars and declares `N`; one is the least-added default.
- **I-03 — cross-timeframe alignment:** the four timeframes do not close together. Baseline aligns each to the newest bar completed by the H4 decision time, avoiding both look-ahead and stale fixed-shift assumptions.
- **I-04 — ATR timeframe:** the author trades the H4 chart but does not state which timeframe supplies ATR(14). Baseline uses closed H4 ATR; this is not represented as source fact.
- **I-05 — session clocks:** “after London opens” and “not after NY closes” names market events but gives no clock, timezone, or DST table. The implementation must use a declared calendar-aware profile and UTC conversion, not invent fixed broker hours. The profile is an operational interpretation that must be visible in setfiles.
- **I-06 — 3–4 ATR target:** baseline chooses the lower literal endpoint, 3 ATR, and preserves 4 ATR as the only alternate source endpoint.
- **I-07 — repeated entries:** the source supplies no episode lock. A flat EA may re-enter on a later H4 decision while alignment persists; adding one-entry-per-alignment, a cooldown, or a daily cap would be a variant.

## V5 five-hook sketch

1. **Initialization hook:** validate M15/H1/H4/D1 history, create four EMA25 handles plus H4 ATR14, resolve symbol/tick/risk metadata, load the named UTC session calendar, and fail closed on stale or missing mandatory news data.
2. **New-bar regime hook:** on each H4 boundary, locate fully closed bars as of `decisionTime`, test `N`-bar four-timeframe alignment, session eligibility, and the flat/one-position condition.
3. **Order/risk hook:** size through V5 risk controls and submit one market intent with fill-relative 2 ATR protection and the declared 3 ATR or 4 ATR target.
4. **Position-management hook:** preserve the fixed protection, perform no source-absent trailing/opposite/time exit, and let framework safety controls act.
5. **Exit/audit hook:** record all four close/EMA tuples, synchronization timestamps, H4 ATR, UTC session state, fill, protection, target variant, and Q-only operator phase labels.

## House and Edge Lab controls

- Mandatory high-impact-news blackout applies and stale/missing calendar data fails closed. `qm_news_stale_max_hours` is never raised above 336.
- No martingale, grid, averaging, stacking, recovery sizing, discretionary intervention, or ML.
- FTMO + DXZ evaluation only; daily drawdown must remain at or below 5% and total drawdown at or below 10%.
- Backtest setfiles require `RISK_FIXED > 0` and `RISK_PERCENT = 0`.
- H4 decision logic is swing-horizon and closed-bar; tick handling is limited to execution and protection.
- No T_Live, AutoTrading, terminal launch, pipeline verdict, or deployment action is authorized.

## Explicit fidelity exclusions

The ledger reports that prior `QM5_10038` added a 30th-percentile ATR gate, a strategy spread veto, an opposite-stack exit, and a 20-bar time exit. Those are material rule deltas and must not appear in this faithful baseline. The later M15/MACD Sample material, trailing-stop-only behavior, and the linked three-EMA/NRTR strategy are also outside STR-088.
