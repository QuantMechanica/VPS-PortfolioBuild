# STR-086 — Codex independent mechanical specification

## Source boundary

- Source: “The DIBS Method… No Free Lunch continues,” ForexFactory thread 86766, compiled by jarroo from PeterCrowns’ DIBS posts.
- Evidence read for this blind specification: `00_source.md` and the `STR-086` row in `SOURCE_LEDGER.csv` only.
- Status: independent Codex draft for G0 comparison; not an approval, profitability verdict, or live-use authorization.

## Strategy hypothesis

Use the 06:00 UTC daily open as a directional line. During the early part of that trading day, buy an H1 inside-bar upside break only above the line or sell an H1 inside-bar downside break only below it. Risk the opposite side of the inside bar, realize half at 1R, and leave the remainder exposed to a long-tail exit.

## Instrument and timeframe scope

- Primary cohort: validated DXZ FX `.DWX` symbols on H1.
- Baseline daily anchor: 06:00 UTC for non-JPY pairs.
- JPY-pair variant: 00:00 UTC, as recorded in the ledger and discussed in the thread, but kept as a separate variant because the source discussion is not unanimous.
- H1 is canonical. The source mentions M30/M15 use by others, but PeterCrowns says he would not personally use bars below H1; lower-timeframe variants are excluded from the baseline.

All UTC-to-broker conversion must use `QM_BrokerToUTC` / `QM_DSTAware.mqh` against the NY-close GMT+2/+3 broker clock. No fixed broker-hour surrogate is allowed.

## Closed-bar and price definitions

- `dayOpen` is the market open price at the configured UTC anchor for the active DIBS day.
- `ib` is a just-closed H1 bar and `mother` is the H1 bar immediately before it.
- `ib` is inside when `ib.high <= mother.high` and `ib.low >= mother.low`. Equality at either boundary is allowed by the source.
- `setupSpread` is the current executable `Ask - Bid` when the pending prices are created.
- Pip conversion comes from validated symbol metadata; it must not be inferred for an unsupported symbol.

## Mechanical rules

1. At every configured daily anchor, record `dayOpen` and begin a new DIBS day.
2. Evaluate a candidate only after an H1 bar has closed; never use the forming bar.
3. Accept `ib` only when it satisfies the inclusive inside-bar definition above.
4. In a consecutive run of inside bars, retain only the first (largest) inside bar and ignore subsequent nested inside bars until a non-inside bar resets the sequence.
5. The baseline setup window admits inside bars whose close time is after the daily anchor and no later than nine hours after it.
6. Calculate a long trigger at `ib.high + 1 pip + setupSpread`. The long side is eligible only when that trigger is strictly above `dayOpen`.
7. Calculate a short trigger at `ib.low - 1 pip`. The short side is eligible only when that trigger is strictly below `dayOpen`.
8. If only the long side is eligible, place only the buy stop. If only the short side is eligible, place only the sell stop. If an inside bar spans the daily open and both calculated triggers satisfy rules 6–7, place the two sides as an OCO pair.
9. Long initial stop is `ib.low - 1 pip`. Short initial stop is `ib.high + 1 pip + setupSpread`.
10. When one side of an OCO pair fills, cancel the other immediately.
11. Reject any order whose stop geometry is invalid or whose volume cannot be represented safely after V5 risk sizing.
12. Let `R` equal the executable fill-to-initial-stop distance, including the source-defined entry/stop offsets and spread treatment.
13. When favorable executable price first reaches 1R, close exactly 50% of the original volume, subject to broker volume-step normalization.
14. Do not move the protective stop on the remaining volume merely because the 1R partial was taken. The source explicitly says not to move it.
15. Manage the remainder with a 20-period H1 moving-average ratchet: after each H1 close, a long may raise its stop to the closed-bar MA20 value and a short may lower its stop to that value, but only when the modification tightens risk and is valid relative to market/freeze levels.
16. Cancel unfilled orders at the end of the configured setup window, at the next daily anchor, or when a different retained first-inside-bar setup replaces them after the prior setup becomes price-invalid. Do not use a bar-count expiry.
17. Permit at most one live DIBS position per magic/symbol. While it is open, do not place add-on entries even though the source discusses accumulating positions over time.
18. A fresh setup may be taken after a completed loss or exit if it independently satisfies all rules and remains within the setup window. No automatic stop-and-reverse is allowed.

## Required inputs and baseline defaults

| Input | Baseline | Allowed research variation | Evidence status |
|---|---:|---:|---|
| `SignalTF` | H1 | fixed | sourced canonical timeframe |
| `DailyOpenUTC` | 06:00 | 00:00 for separately labelled JPY variant | sourced but discussed inconsistently |
| `SetupWindowHours` | 9 | 6 or 10 as labelled variants | source says first 6–9 and elsewhere 9–10 hours have higher potential |
| `InsideEqualityAllowed` | true | fixed | sourced stricter DIBS definition |
| `ConsecutiveInsideSelection` | first/largest | fixed | sourced |
| `BreakBufferPips` | 1 | fixed | sourced |
| `LongSpreadAdjustment` | setup spread | fixed | sourced example/risk formula |
| `PartialAtR` | 1.0 | fixed | sourced |
| `PartialFraction` | 0.50 | optional 0.67 variant only | source baseline and explicit variation |
| `RunnerExitMode` | MA20 ratchet | initial-stop-only as a labelled source-supported variant | source gives both holding at initial stop and MA20 trailing |
| `RunnerMAPeriod` | 20 | fixed when MA mode is used | sourced |
| `TimeExpiryBars` | disabled | none | no source-backed bar-count expiry |
| `RISK_FIXED` | positive test lot from canonical set generation | positive only | house backtest constraint |
| `RISK_PERCENT` | 0 in backtests | live configuration at or below 1.0 only with separate authorization | house constraint |

## Interpretation register

- **I-01 — anchor mapping:** PeterCrowns repeatedly identifies 06:00 GMT/UTC as the intended constant, while participants test other anchors and the ledger records 00:00 UTC for JPY pairs. The faithful baseline is 06:00 UTC; the JPY mapping is an explicit variant, not silently mixed into results.
- **I-02 — inside equality:** the source first describes strictly lower/high and higher/low, then says equal boundaries are permitted. Baseline applies inclusive bounds. Fully identical adjacent bars are allowed, although rare.
- **I-03 — setup window as a gate:** the source says early breakouts have higher potential rather than stating a universal prohibition after nine hours. Baseline turns nine hours into a bounded mechanical gate; six and ten hours are declared sensitivity variants.
- **I-04 — pending lifecycle:** the source does not resolve when an unfilled or wrong-side order is cancelled. Rule 16 is the minimum deterministic lifecycle; it introduces no three-bar or other arbitrary expiry.
- **I-05 — runner trail mechanics:** the source names a 20-period moving average as a trailing stop but does not define update timing. Baseline uses closed H1 MA values and ratchets only, avoiding look-ahead and stop widening.
- **I-06 — partial-volume rounding:** when exactly half is not broker-valid, normalize the closing volume down to the nearest valid step while leaving at least the minimum position. If no valid partial exists, skip the partial and record the condition rather than changing total risk.
- **I-07 — OCO behavior:** the source says an inside bar spanning the open may be traded in whichever direction breaks. OCO is the deterministic implementation; the unfilled opposite order is cancelled on fill.

## V5 five-hook sketch

1. **Initialization/calendar hook:** validate H1 history, UTC conversion, symbol pip/volume metadata, MA20 handle, and fail-closed news-calendar state.
2. **Daily-anchor/new-bar hook:** record the UTC-anchored daily open, classify the just-closed inside bar, enforce first-in-chain selection and the setup window.
3. **Order/risk hook:** construct eligible buy/sell stop prices, opposite-side stops, OCO linkage, and V5-sized volume without adding a discretionary filter.
4. **Position-management hook:** execute the 1R half close once, retain the initial stop at that event, then apply only valid closed-bar MA20 ratchets.
5. **Exit/audit hook:** cancel stale daily intents, record anchor/IB/trigger/risk/partial/trail/exit data, and use Q-only operator phase names.

## House and Edge Lab controls

- The mandatory framework news blackout blocks new entries; stale/missing news data fails closed. It is a house control, not a DIBS source rule.
- One position per magic/symbol; no stacking, pyramiding, martingale, grid, recovery sizing, or ML.
- FTMO + DXZ evaluation only; daily drawdown must remain at or below 5% and total drawdown at or below 10%.
- Backtests require `RISK_FIXED > 0` and `RISK_PERCENT = 0`.
- H1 closed-bar evaluation is non-HFT. Tick work is limited to pending activation, protection, and the one-time 1R partial.
- No T_Live, AutoTrading, or deployment action is authorized.

## Explicit fidelity exclusions

Do not add a bar-count pending expiry, discretionary support/resistance filter, unsourced spread veto, lower-timeframe signal, automatic reversal, break-even move on the runner, or multi-position accumulation to the faithful baseline. Relative “hot hand” market ranking and weekly/monthly alignment are source-discussed context, not mandatory DIBS entry rules here.

