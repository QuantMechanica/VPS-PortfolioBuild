# Q08 round-trip commission handoff - 2026-07-10

## Owner boundary

**Status: reproducible framework defect / CTO + Quality-Tech change required.**

Development did not modify `framework/include/QM/QM_Common.mqh`. The V5 build
boundary assigns shared framework includes to CTO + Quality-Tech. Downstream
FTMO analysis compensates for the defect only on verified one-entry/one-exit,
fixed-volume streams.

## Defect

`QM_FrameworkOnTradeTransaction` returns immediately for `DEAL_ENTRY_IN` after
recording only the position id and entry time. On `DEAL_ENTRY_OUT`, the emitted
Q08 row calculates:

```text
net = exit profit + exit swap + exit commission
```

The entry-side deal commission is absent from `net`, `commission`, and MAE. The
state is also removed after the first closing deal, which is not sufficient for
partial closes or scale-in positions.

Affected source: `framework/include/QM/QM_Common.mqh`, current lines 610-641.

## Real reconciliation anchors

All rows below are fresh model-4 MT5 streams with one entry and one exit per
position. In that restricted shape, the missing entry commission equals the
observed exit commission.

| EA / symbol | Q08 emitted net | Missing entry commission | Corrected net | MT5 Net Profit |
|---|---:|---:|---:|---:|
| `QM5_10375 / NDX.DWX` | `$59,503.21` | `-$3,530.69` | `$55,972.52` | `$55,972.52` |
| `QM5_12969 / USDJPY.DWX` | `$11,836.97` | `-$862.19` | `$10,974.78` | `$10,974.78` |
| `QM5_12986 / GDAXI.DWX` | `$39,015.58` | `-$5,907.94` | `$33,107.64` | `$33,107.07` |

The `$0.57` GDAXI difference is consistent with per-row two-decimal emission
rounding across 1,790 trades.

## Required framework contract

The position MAE state must additionally retain:

- cumulative entry commission;
- remaining opened volume;
- enough state to allocate entry commission across partial closing deals;
- state continuity while any owned volume for the position remains open.

For each closing deal, Q08 must emit:

```text
allocated_entry_commission = position entry commission allocated to closed volume
exit_commission            = closing deal DEAL_COMMISSION
commission                 = allocated_entry_commission + exit_commission
net                        = profit + swap + commission
mae_acct                   = min(observed account MAE including entry costs, net)
```

The emitter should add explicit `entry_commission` and `exit_commission` fields
while retaining `commission` as the round-trip total for consumers. State may be
removed only after the position has no remaining owned volume. `DEAL_ENTRY_INOUT`,
`DEAL_ENTRY_OUT_BY`, scale-ins, and partial closes require explicit tests rather
than inheriting the one-entry/one-exit assumption.

## Acceptance tests

1. One-entry/one-exit: sum of Q08 `net` reconciles to MT5 Net Profit within the
   stream's two-decimal row-rounding bound.
2. Entry commission differs from exit commission: emitted values use actual
   deal history, not mirrored exit cost.
3. Two entries plus one exit: both entry commissions are included once.
4. One entry plus two partial exits: entry commission is allocated once across
   the two rows and state survives the first exit.
5. `OUT_BY` and `INOUT`: no cost is dropped or double-counted.
6. MAE never becomes less adverse by adding a commission and is at most `net`
   on a losing close.
7. Recompile and rerun the three anchors above; attach report path, Q08 stream
   path, row count, summed net, MT5 Net Profit, and tolerance to the review.

## Downstream containment

`tools/strategy_farm/portfolio/ftmo_phase1_mae.py` currently adds the observed
closing commission once more for the three qualified one-entry/one-exit streams.
That compensation must be removed only after new binaries emit the round-trip
schema and the three acceptance anchors reconcile.
