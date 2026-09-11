# QM5_41140 current-source compile recovery — blocked

- Observed at: 2026-09-11T00:50:09Z
- Farm task: `5f69b208-6e8b-4900-a8c2-020c779eb030`
- EA: `QM5_41140_nzdjpy-carry-unwind-crisis-momentum`
- Recovery compile: `da503287-086a-4256-8a57-9955e6a99f8e`
- Source SHA-256: `b25ad6366f2dfabb7610170babe56c7d5aaaf57bea44c2b2825778a6686ccff4`
- EX5 SHA-256: `5e82cd3d9d6544a9ba32471e95df967618696a500120451d698c760a2f96dd9a`
- Compile evidence SHA-256: `52018f6655e08951cdbcc6b0484dbda75706c490cac2145b9923927dace6b97c`
- Build result SHA-256: `f743dfaa9b17e21d718598ca2db61d672050c63e0064a5902a82321aafdc85b1`

## Admission and PACER guard

Two five-sample CPU windows admitted the bounded recovery work. The initial
window was `[76, 79, 63, 66, 77]` percent (average 72.2, maximum 79); the
pre-release window was `[84, 57, 53, 57, 81]` percent (average 66.4, maximum
84). Both average and maximum remained below the binding 97 percent ceiling.

Immediately before `enqueue-compile`, the required command was run against the
exact generated source:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_41140_nzdjpy-carry-unwind-crisis-momentum/QM5_41140_nzdjpy-carry-unwind-crisis-momentum.mq5"
```

It returned `ok=true`, verdict `EA_FRAMEWORK_INPUT_PINNED`, and `hit_count=0`.
The registered one-shot source-repair authority is bound to source SHA-256
`b25ad636...` and predecessor compile work item
`c791b8f6-7474-495a-abab-2469b610f332`.

## Result

MetaEditor compilation passed with zero errors and zero warnings. The enclosing
build check correctly failed with three `EA_SYMBOL_NOT_IN_CARD_UNIVERSE`
findings. The approved card's mechanical entry rule requires synchronized D1
returns from `AUDJPY.DWX`, `NZDJPY.DWX`, `CADJPY.DWX`, and `EURJPY.DWX`, while
its machine-readable `target_symbols` contract authorizes only `NZDJPY.DWX`.

Development cannot truthfully remove the three auxiliary series without
changing approved strategy mechanics, and this build operation does not carry
authority to mutate an approved Strategy Card. The farm build task was
therefore recorded as `blocked` with fail code
`approved_signal_dependency_authority_missing` after its bounded retry count
reached three. Its durable build result is at:

```text
D:\QM\strategy_farm\artifacts\builds\5f69b208-6e8b-4900-a8c2-020c779eb030.json
```

Q02 work item `381b2608-c3f1-4493-88f8-9ed119e61d69` remains pending under its
active `SOURCE_REPAIR_AUTHORITY_REQUIRED` hold. No Q02 successor was enqueued,
no stale hold was released, and no backtest, live, deployment, AutoTrading, or
portfolio action was taken. Temporary T8/T10 cache-guard reservations were
released after the compile completed.

## Required authority to resume

OWNER/Research must provide a durable approved-card correction that explicitly
authorizes the three signal-only symbol dependencies, or an equally explicit
governed signal-only dependency contract. Only then may Development rebuild and
append a current-binary Q02 successor.
