# QM5_10069 NZDUSD Q02 infrastructure recovery — CPU ceiling stop

Date: 2026-09-12 (Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

The current-binary append-only Q02 recovery is deterministically eligible, but
no work was enqueued because the binding paced-fleet CPU ceiling fired.

- Coordination task: `374ba9a6-478d-4df3-9881-4c99d143f967`
- EA: `QM5_10069_mql5-hs-rev`
- Target: `NZDUSD.DWX`, H1
- Preserved infrastructure row: `727fd995-bf25-4943-bf14-422f59adab65`
- Preserved failure: `ONINIT_FAILED;INCOMPLETE_RUNS` on the stale binary
- Governed recovery compile: `7deba014-7ca5-4e79-bd20-789bad639b69`, `COMPILE_OK`

This is a distinct FX instrument recovery. It does not create another EA,
change strategy mechanics, or repeat the already recovered USDCHF sleeve.

## Deterministic preflight

The canonical artifacts still match the prior recovery authority:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `d6243b426c4290aae893cc64088aecc9cca6cbf696abfe8792859588a60ba77c` |
| EX5 | `4f474930fa4c53657df8252416dc55efa7f3bc974ca706d63faacd54b1db7c55` |
| NZDUSD setfile | `9e52a5bfafe2585eb86f86c8f6bc8446596d45e79dacaefbf0ab53a975da3dd1` |

The setfile remains fixed-risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`qm_magic_slot_offset=7`.

The required framework-input audit exited zero on the canonical MQ5 with
`ok=true`, predicate `EA_FRAMEWORK_INPUT_PINNED`, and zero findings. No source
was written and no compile enqueue was attempted.

The canonical `farmctl requalify-q02` dry run against the preserved row returned
`ok=true`, `eligible=true`, `would_enqueue=true`, and
`parameter_change_count=0`. It selected the governed current EX5 and canonical
NZDUSD setfile. No open NZDUSD Q02 successor existed at preflight.

## Binding CPU stop

Five read-only processor-load samples were taken immediately before the planned
append-only mutation:

```text
samples=[99,100,100,100,100]
average=99.8
maximum=100
ceiling=97
```

Both the average and maximum breached the ceiling. `farmctl mt5-slots` reported
seven active factory terminals: `T1`, `T3`, `T4`, `T5`, `T6`, `T7`, and `T10`.
The separately visible `T_Live` and FTMO processes were not included in that
factory count and were not controlled.

No Q02 successor, compile work, smoke, or manual backtest was launched.

## Resume condition

A later paced wake must repeat the current EX5 hash check, the source-pin audit,
the no-open-successor check, and a fresh five-sample CPU window. It may apply the
exact `requalify-q02` successor only when both average and maximum CPU are
strictly below 97 percent.

Machine-readable evidence:
`docs/ops/evidence/2026-09-12_qm5_10069_nzdusd_q02_cpu_ceiling_stop.json`.

`T_Live`, AutoTrading, the portfolio gate, and the deploy manifest were not
mutated.
