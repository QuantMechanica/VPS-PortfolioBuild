# STR-087 — Codex independent mechanical specification

## Source boundary

- Source: Fx-ken, “Simple Horizontal Line Trading H1,” ForexFactory thread 922813.
- Evidence read for this blind specification: `00_source.md` and the `STR-087` row in `SOURCE_LEDGER.csv` only.
- Secondary-contributor Renko/pivot material is not used for the baseline.
- Status: independent Codex draft for G0 comparison; not an approval, profitability verdict, or live-use authorization.

## Strategy hypothesis

On H1, use SMA50 to select direction and place a stop entry three pips beyond the next 25-pip round-number level in that direction. Use a fixed 30-pip stop and 50-pip target, protecting a favorable move at break-even plus a small offset.

## Instrument and timeframe scope

- Canonical symbols: GBPUSD.DWX and EURJPY.DWX, tested separately on H1.
- Other validated FX symbols may be a separately labelled generalization; the source says the method can be used in other markets but primarily trades GBPUSD and EURJPY.
- H1 with 25-pip levels is canonical.
- H4/D1 with 100-pip levels is source-discussed but is a separate family variant, not part of this baseline.
- No mandatory session gate: the author initially reports trading Asia-to-London because of availability and later says the method may be traded at any time.

## Closed-bar and round-level definitions

At the first tick of a new H1 bar:

- `close1` and `sma1` are the just-closed H1 close and SMA(50, Close).
- `pipSize` comes from validated symbol metadata.
- `gridStep = 25 * pipSize`.
- Round levels are integer multiples of `gridStep` in absolute quote-price space, corresponding to the source’s `000 / 250 / 500 / 750` levels.
- A long candidate uses the nearest round level whose entry price is strictly above current Ask. A short candidate uses the nearest round level whose entry price is strictly below current Bid.

## Mechanical rules

1. Evaluate setup creation and invalidation once per new H1 bar, using only closed SMA/price data.
2. Long regime exists when `close1 > sma1`. Short regime exists when `close1 < sma1`. No new setup is permitted when equal at tick precision.
3. In a long regime, identify the nearest forward round level, `L`, for which `L + 3 pips > Ask` and `L > sma1`.
4. In a short regime, identify the nearest forward round level, `L`, for which `L - 3 pips < Bid` and `L < sma1`.
5. Require `abs(L - sma1) >= MinLineToSmaPips`.
6. Place one buy stop at `L + 3 pips` for an eligible long or one sell stop at `L - 3 pips` for an eligible short.
7. Attach a 30-pip protective stop and 50-pip take profit measured from the executable fill price.
8. Maintain only one pending order or open position per magic/symbol.
9. An unfilled pending order has no time/bar-count expiry. Cancel it only when the H1 close is no longer on its qualifying side of SMA50, the selected line is no longer beyond market, the line-to-SMA filter fails, the daily safety/news gate blocks fresh exposure, or the order is replaced by the newly nearest eligible line.
10. After favorable executable movement reaches `BreakEvenTriggerPips`, ratchet the stop once to entry plus `BreakEvenOffsetPips` for a long or entry minus that offset for a short, provided the broker stop/freeze level permits it.
11. Never loosen the break-even stop. If price gaps past the requested modification level, retain the existing protective stop and retry only while the position remains open and the modification would still tighten risk.
12. Close only by the fixed stop, fixed target, or framework safety exit. There is no source-backed ten-bar exit.
13. After an exit, wait for the next independently valid H1 evaluation. Do not reverse automatically and do not open both directions together.

## Required inputs and baseline defaults

| Input | Baseline | Allowed research variation | Evidence status |
|---|---:|---:|---|
| `SignalTF` | H1 | fixed for baseline | sourced |
| `MAPeriod` | 50 | MA200 as separately labelled variant | SMA50 is core; author later experiments with SMA200 |
| `MAMethod` | SMA | EMA only as separately labelled variant | source clarifies SMA, while allowing EMA experimentation |
| `MAAppliedPrice` | Close | fixed | natural implementation of stated SMA50; interpretation I-01 |
| `GridStepPips` | 25 | fixed for H1 baseline | sourced |
| `EntryBufferPips` | 3 | fixed | sourced |
| `StopLossPips` | 30 | 25 only in a separately labelled sideways variant | sourced baseline |
| `TakeProfitPips` | 50 | 25 only in a separately labelled sideways variant | sourced baseline |
| `MinLineToSmaPips` | 5 | bounded sensitivity values 5, 10, 15 | source requires distance but gives no number; interpretation I-03 |
| `BreakEvenTriggerPips` | 10 | 15 | both source-supported |
| `BreakEvenOffsetPips` | 1 | 5 | both source-supported |
| `SessionMode` | ALL | observational Asia-to-London slice only | no source-backed hard gate |
| `PendingExpiryBars` | disabled | none | no source-backed expiry |
| `TimeExitBars` | disabled | none | no source-backed time exit |
| `MaxSpreadPips` | disabled | none | no source-backed spread veto |
| `OppositeGridGate` | disabled | none | no source-backed opposite-grid gate |
| `RISK_FIXED` | positive test lot from canonical set generation | positive only | house backtest constraint |
| `RISK_PERCENT` | 0 in backtests | live configuration at or below 1.0 only with separate authorization | house constraint |

## Interpretation register

- **I-01 — SMA applied price:** the source names SMA50 but not its applied-price field. Baseline uses close, the standard chart default; this must remain visible in the card/input set.
- **I-02 — which round line:** the source says place the pending order at a horizontal line above/below SMA50 but does not define selection when several qualify. Baseline chooses the nearest line still ahead of executable market price, producing an actual stop-entry breakout without look-ahead.
- **I-03 — “too close” threshold:** the author repeats that a line too close to SMA50 must be avoided but supplies no distance. Five pips is a declared bounded projection, with 10 and 15 pips as sensitivity values. It is not source fact.
- **I-04 — pending lifecycle:** no expiry rule is supplied. Baseline has no bar-count expiry and only cancels when the qualifying state or price geometry ceases to exist. Replacement by the newly nearest eligible line prevents multiple grid orders and is a house-bounded projection.
- **I-05 — break-even alternatives:** the source gives 10–15 pips of favorable movement and BE+1/BE+5. Baseline selects the least aggressive stated combination, +10 then BE+1; the other combinations remain declared variants.
- **I-06 — price side/spread:** the fixed three-pip offset is the source’s allowance around the horizontal level. The baseline does not add a dynamic spread veto or a second spread adjustment.
- **I-07 — sideways handling:** identifying a sideways market is described visually and is not mechanical. The suggested 25/25 stop/target mode cannot activate automatically in the faithful baseline without a separately specified, clearly labelled regime rule.

## V5 five-hook sketch

1. **Initialization hook:** validate H1 history, create SMA50, resolve symbol pip/volume metadata, and fail closed on stale/missing mandatory news data.
2. **New-bar regime hook:** read closed H1 price/SMA, compute the nearest forward 25-pip line, apply the declared MA-distance threshold, and emit at most one intent.
3. **Order/risk hook:** create the three-pip-offset stop order with fixed 30/50-pip protection and V5 risk sizing; enforce one intent/position per magic.
4. **Pending/position management hook:** cancel only on rule-9 invalidation, perform the one-way BE+1 ratchet after +10 pips, and never add a time exit or opposite-grid rule.
5. **Exit/audit hook:** record SMA/line/distance/spread/entry/protection/BE/exit fields and use Q-only operator phase naming.

## House and Edge Lab controls

- Mandatory framework news blackout applies to new orders; stale/missing calendar data fails closed. This is a house control, not a source rule.
- No martingale, grid campaign, stacking, averaging, recovery sizing, discretionary intervention, or ML. The evenly spaced round levels are signal landmarks, not permission to maintain multiple grid orders.
- FTMO + DXZ evaluation only; daily drawdown must remain at or below 5% and total drawdown at or below 10%.
- Backtest setfiles require `RISK_FIXED > 0` and `RISK_PERCENT = 0`.
- H1 closed-bar setup evaluation is non-HFT; tick processing is limited to native order execution/protection.
- No T_Live, AutoTrading, or deployment action is authorized.

## Explicit fidelity exclusions

The faithful H1 baseline must not contain a three-bar pending expiry, ten-bar time exit, maximum-spread veto, opposite-grid-distance gate, automatic sideways classifier, Renko/pivot entry, or multiple simultaneous round-level orders. Those rules are absent from the admitted source or belong to a secondary contributor’s different method.

