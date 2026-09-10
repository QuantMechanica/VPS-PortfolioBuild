# QM5_41140 paced-fleet CPU ceiling stop

Date: 2026-09-11 (Europe/Berlin; sample ended 2026-09-10T23:05:21Z)

Branch: `agents/board-advisor`

## Selection and claim

The farm claim guard reported 32 claimable pending `build_ea` rows. The
deterministic strategy-priority scorer ranked
`QM5_41140_nzdjpy-carry-unwind-crisis-momentum` highest at `21.35`. It is a
diverse single-symbol NZDJPY.DWX D1 carry-unwind sleeve. Task
`5f69b208-6e8b-4900-a8c2-020c779eb030` was atomically claimed with key
`paced_fleet:diversity_build_rework:QM5_41140:20260911` and then released back
to `pending` after the CPU stop.

The current source already contains the bounded review repair from commit
`12bd4c8b2f`: it uses framework-owned D1 cadence rather than the rejected
file-scope timestamp gate. The open build task still requires a governed
current-source compile and an honest smoke disposition.

## Binding framework-input audit

Before considering any compile enqueue, the required PACER command was run on
the exact canonical source:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_41140_nzdjpy-carry-unwind-crisis-momentum/QM5_41140_nzdjpy-carry-unwind-crisis-momentum.mq5
```

It exited zero with `ok=true`, predicate `EA_FRAMEWORK_INPUT_PINNED`, and zero
findings. This audit result does not waive the requirement to run the same
check again immediately before a future `enqueue-compile` command.

## CPU ceiling

The mission's five-sample host preflight returned `97, 100, 94, 99, 91`
percent. Average load was `96.2%`; maximum load was `100%`. The paced-fleet
stop condition is average or maximum greater than or equal to `97%`, so the
maximum triggered the binding stop.

No compile work was enqueued, no smoke or backtest was started, and no new Q02
row was created. Existing Q02 row `381b2608-c3f1-4493-88f8-9ed119e61d69`
remains pending and was not modified. `T_Live`, AutoTrading, the portfolio
gate, and the live manifest were not touched.

Machine-readable evidence:
`artifacts/qm5_41140_fx_rework_cpu_stop_20260910T230521Z_board_advisor.json`.

## Resume condition

A later paced wake must obtain a fresh five-sample CPU window whose average
and maximum are both below 97 percent. It must then re-run the binding
framework-input pin audit immediately before any compile enqueue.
