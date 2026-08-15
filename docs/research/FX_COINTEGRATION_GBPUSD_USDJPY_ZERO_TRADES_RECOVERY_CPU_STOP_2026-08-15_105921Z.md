# FX cointegration GBPUSD/USDJPY — zero-trades recovery CPU stop

Date: 2026-08-15

Branch: `agents/board-advisor`

Status: valid Q02 zero-trade evidence; deterministic implementation repair
identified; strict compile blocked by resource exhaustion

## Outcome

The frozen sign-aware 66-pair frontier remains fully mechanized, so no new
Strategy Card, EA, registry row, basket manifest, setfile, or duplicate Q02 row
was created. The two anchor baskets remain beyond Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

The non-duplicate fallback remains frozen-scan rank 58,
`GBPUSD.DWX` / `USDJPY.DWX`, implemented as pair slot 8 in the approved
`QM5_1257_lemishko-fx-cointpair` Card. Its one governed logical Q02 identity is
work item `d4cd660c-c81a-41d3-8a4c-ad21d3319816`.

This pass advanced the recovery investigation from an infrastructure-ambiguous
retry to a valid zero-trade result and located the first deterministic
implementation failures. A source repair was prepared locally, but the required
strict compile raised `System.OutOfMemoryException`. The uncompiled source edit
was therefore rolled back and the existing EX5 was preserved. Per the explicit
resource-ceiling rule, no compile retry, tester launch, dispatch, requeue, or
queue mutation followed.

## Bound Q02 evidence

The worker-owned T8 attempt produced a non-empty, identity-bound report rather
than ONINIT, NO_HISTORY, or NO_REPORT evidence:

| Field | Bound value |
|---|---|
| Work item | `d4cd660c-c81a-41d3-8a4c-ad21d3319816` |
| Logical basket | `QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1` |
| Actual host / period / model | `GBPUSD.DWX` / H1 / Model 4 real ticks |
| Actual window | `2018.07.02` through `2022.12.31` |
| Result | `FAIL`, reason `MIN_TRADES_NOT_MET` |
| Trades | `0` (minimum required: `25`) |
| ONINIT / log bomb | `false` / `false` |
| MQ5 SHA-256 observed by runner | `28bd88d0a7a7401ec7fe3b3a4f99ef3ba6b9fec146298c512b1c76e1adf7e12b` |
| Deployed EX5 SHA-256 | `86c6e9f077e37ddd5aea1e15b253cd4509c7f180c846cc6aebd806fa17d95cbd` |
| Setfile SHA-256 | `f7efb0a2183acdaee85f0882a0858447014f970a2e5782227e1c4980e98298d4` |
| Summary SHA-256 | `76fcd6351b98f8cc16250a5fd7e3bc2fb47e6b868cd9ce4619102c5f64bc1526` |
| Report SHA-256 | `22e10ae2cb3b9080164f89a5b78f141c7f02be4d8752b55e3f68a201ab7b766f` |
| Logger sample SHA-256 | `b4baef4f3ae9ce6d4b76bf8e742188fc341a24952abf7315e87c646b486afab7` |

Evidence root:
`D:/QM/reports/work_items/d4cd660c-c81a-41d3-8a4c-ad21d3319816/QM5_1257/20260815_082908/`.

The summary was written at `2026-08-15T08:46:23Z`. At the durable database
sample (`2026-08-15T10:59:21Z`), the exact row was still `pending`, unclaimed,
at `attempt_count=2`, with no verdict or evidence path. Its `updated_at` remained
`2026-08-15T08:39:29Z`, earlier than the valid summary. The report has therefore
not been ingested into canonical state. Creating or requeueing another row would
be duplicate work.

## Zero-trades layer classification

The harness and setup layers pass: the report is non-empty, the requested
multi-year window ran under Model 4, deployed hashes were stable, both custom
symbols were privatized on claim, and initialization completed. The first failed
layer is the EA's entry implementation.

Four same-lineage defects are directly relevant to this negative-beta basket:

1. `ComputeHalfLife()` regresses `delta_residual` on lagged residual but rejects
   every coefficient `theta <= 0`. A mean-reverting residual requires a negative
   delta-regression coefficient, so the code rejects the stationary state it is
   intended to admit. The frozen scan computes positive half-life as
   `-log(2) / log(phi)` for `0 < phi < 1`; the equivalent EA repair is
   `phi = 1 + lambda`, followed by the same formula.
2. `SpreadCostOk()` compares raw GBPUSD and USDJPY price spreads with a
   log-residual reversion distance. The mixed units, amplified by the JPY price
   scale, can reject otherwise valid signals. Costs must be converted to
   relative/log-price units and combined as `cost_b + abs(beta) * cost_a` for
   residual `log(b) - beta*log(a)`.
3. `OpenPair()` assumes a positive hedge ratio when choosing the second-leg
   direction. The bound scan beta is `-0.388288093234`; a long residual therefore
   requires both legs long, and a short residual requires both legs short. The
   current code instead opens opposite directions.
4. Both legs are sent with pair slot 8 magic, and `OpenPair()` reports success if
   either order opens. The registry assigns the companion USDJPY leg slot 29.
   The Card requires registered per-leg identity and immediate flattening if
   either leg fails; success must require both legs.

The monthly screen also needs an explicit qualification latch so a failed monthly
Engle-Granger/half-life decision is not recomputed every H1 bar. Bounded monthly
qualification and pre-order signal events are the required recovery diagnostics.
These are implementation and observability corrections, not threshold changes,
new filters, refits, or altered economics.

Repository cross-checks:

- `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py` uses the
  stationary `0 < phi < 1` half-life convention.
- `QM5_11241_ht-coint-spread` documents the negative delta-regression coefficient
  for a reverting spread.
- `QM5_12533_edgelab-eurjpy-gbpjpy-cointegration` resolves and validates a
  distinct registered magic slot for each basket leg.

## Compile stop

Required command:

```powershell
powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 `
  -EAPath framework/EAs/QM5_1257_lemishko-fx-cointpair/QM5_1257_lemishko-fx-cointpair.mq5 `
  -Strict
```

Result: exit code `1`, `System.OutOfMemoryException` from `compile_one.ps1`.
The EX5 remained at SHA-256
`86c6e9f077e37ddd5aea1e15b253cd4509c7f180c846cc6aebd806fa17d95cbd`.
Because strict compile did not pass, the repair was not retained, no hashes were
restamped, and the Q02 identity was not refreshed.

The post-stop read-only sample at `2026-08-15T10:59:21Z` showed four factory
terminals (`T1`, `T3`, `T9`, `T10`), ten worker daemons, three active work items,
and 20.95 GiB free of 63.12 GiB physical memory. The observed compile OOM is the
binding resource-ceiling signal for this pass; a later-looking free-memory sample
does not authorize an immediate retry after that failure.

## Recovery handoff

When paced capacity is explicitly available:

1. Reapply the five implementation/diagnostic corrections above without changing
   thresholds or the pair binding.
2. Strict-compile serially and require zero errors, zero warnings, a new EX5, and
   registry-clean build evidence.
3. Refresh the existing work item in place with the new MQ5/EX5/setfile hashes;
   do not create a second logical Q02 identity.
4. Rerun the same bound basket and use the monthly qualification diagnostics to
   distinguish a legitimate half-life/ADF rejection from an entry/order defect.
5. Treat non-zero trades only as `trade-capable`; all normal Q02 and downstream
   gates still apply. If the corrected card rules legitimately produce zero
   entries, retire this adverse rank-58 binding without rescue tuning.

Machine-readable evidence:
`artifacts/fx_cointegration_gbpusd_usdjpy_zero_trades_recovery_stop_20260815T105921Z_board_advisor.json`.

## Safety

No portfolio admission, portfolio KPI, Q08 contribution path, T_Live manifest or
terminal, AutoTrading state, live-deployment artifact, registry, Card, EA source,
EX5, setfile, basket manifest, external queue row, or factory process was changed.
Concurrent unrelated untracked Strategy Card files were left untouched.
