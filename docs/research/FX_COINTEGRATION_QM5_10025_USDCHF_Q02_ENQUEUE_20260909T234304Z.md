# FX cointegration QM5_10025 USDCHF current-binary Q02 enqueue

Recorded: 2026-09-09T23:43:34Z (2026-09-10 01:43 Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

No unbuilt pair remains in the frozen sign-aware 66-pair FX cointegration
frontier. The durable reconciliation records all 66 identities as represented,
so creating another card or EA would duplicate an owned pair. The two preferred
anchors are not blocked at Q02:

- `QM5_12532` AUDUSD/NZDUSD: Q02 row
  `e4890d77-b865-4a48-b946-315faefca920` is `done/PASS`.
- `QM5_12533` EURJPY/GBPJPY: Q02 row
  `76cb11ee-7e9d-4d75-be9d-626c205bca62` is `done/PASS`.

The mission fallback was therefore used to advance the existing approved
`QM5_10025_rw-fx-broad-pairs` card. This is a structural, market-neutral H4 FX
basket sourced to Robot Wealth: at monthly rebalance it selects a partner from
seven FX majors, freezes an OLS hedge ratio, and trades the beta-weighted
two-leg log spread. The approved card expects approximately six round trips per
year per host and contains no ML, grid, or martingale mechanic.

Exactly one append-only current-binary Q02 successor was enqueued for the
USDCHF host:

`3af8c03c-7772-49fc-bfcd-daca0adcce26`

At verification it was `pending`, unclaimed, attempt zero, priority-tracked,
and the sole open Q02 row for the exact EA/host identity.

## Zero-trade lineage

The predecessor `1a8e8377-a2f3-4533-9ae2-c4bcfc84aff0` remains immutable at
`done/ZERO_TRADES`. It used EX5
`9bf2691d4af0a57d553711c37ffceadb513b303e710a25f455c8f2e211eecfcc`.
The successor does not reinterpret that economic outcome and makes no strategy
or parameter change. It asks Q02 to evaluate the current governed executable,
whose identity differs from the predecessor, while retaining an explicit
append-only supersedes edge.

The `requalify-q02` dry run returned `eligible=true`, `would_enqueue=true`, and
`parameter_change_count=0`. The apply receipt is:

- path:
  `D:/QM/strategy_farm/artifacts/receipts/q02_post_binding_requalification/1a8e8377-a2f3-4533-9ae2-c4bcfc84aff0_3af8c03c-7772-49fc-bfcd-daca0adcce26.json`
- SHA-256:
  `413d611aa3fe508a869cbcbc419eefd04cdc736ac9c74b89533da5bf554b29de`

## Artifact and risk binding

| Artifact | SHA-256 |
| --- | --- |
| MQ5 | `db7424efcba0a8df90184240e277e1a7546e8030672eec88a4c72a89c32a5a61` |
| EX5 | `49fcc59b5232531f5fd2e3ba7a0c71f0bac703f54e17f7c92c911e31944d91f1` |
| USDCHF H4 setfile | `571be487c4d8688c79d3b5c0644624ef83579c099d32e856ad2519828567f413` |
| basket manifest | `98237a88f0634810f187a63c6d4585950aac4d5b8f21c157d23f88533691daa0` |

The successor binds governed `COMPILE_OK` work item
`21c7d995-2fd6-44f6-b624-8c5f097c0961` and compile evidence SHA-256
`6a2ca8c03fa628dbb64a67371c3c520312830d3192f1c7ebff880ae313d7fd69`.
Its setfile retains `RISK_FIXED=1000` and `RISK_PERCENT=0`.

## PACER build guard

No MQ5 was generated, written, or edited, and no compile work was enqueued.
Before the Q02 enqueue, the canonical source was nevertheless checked with the
binding audit:

```powershell
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_10025_rw-fx-broad-pairs/QM5_10025_rw-fx-broad-pairs.mq5"
```

It exited zero with `ok=true` and zero
`EA_FRAMEWORK_INPUT_PINNED` findings. An earlier operator path guess returned
exactly `INVALID_SOURCE`; no mutation followed that invocation. The registered
source path was then resolved and the successful audit above was completed.

The initial five one-second CPU samples were 85.7%, 83.6%, 78.3%, 96.4%, and
94.0% (average 87.6%, maximum 96.4%). Immediately before the queue write, the
samples were 47.5%, 51.2%, 43.6%, 43.8%, and 46.1% (average 46.4%, maximum
51.2%). Neither sample window reached the binding 97% ceiling.

No dispatch tick, manual tester launch, portfolio-admission/KPI/Q08-contribution
change, portfolio-gate change, deploy-manifest change, `T_Live` access,
AutoTrading change, or live-use action was performed.

Machine-readable evidence:
`artifacts/fx_cointegration_qm5_10025_usdchf_q02_enqueue_20260909T234304Z_board_advisor.json`.
