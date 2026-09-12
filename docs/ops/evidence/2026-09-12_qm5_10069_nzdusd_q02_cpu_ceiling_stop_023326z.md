# QM5_10069 NZDUSD Q02 recovery — paced CPU stop at apply boundary

Recorded: 2026-09-12T02:33:46Z (04:33 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `a6c2cd5820`

## Outcome

The frozen 66-pair FX cointegration frontier remains fully mechanized, and
the two preferred logical baskets do not need Q02 repair: `QM5_12532` has
Q02 PASS followed by Q04 PASS/Q05 FAIL, while `QM5_12533` has Q02 PASS
followed by Q04 FAIL. Creating another card, EA identity, basket manifest,
compile row, or Q02 row for that scan would be duplicate work.

The selected non-duplicate existing-forex fallback was the prepared
append-only Q02 recovery for `QM5_10069_mql5-hs-rev` on `NZDUSD.DWX`, H1.
The source row `727fd995-bf25-4943-bf14-422f59adab65` preserves the
stale-binary `INFRA_FAIL` (`ONINIT_FAILED;INCOMPLETE_RUNS`). The governed
current-binary compile row `7deba014-7ca5-4e79-bd20-789bad639b69` remains
`COMPILE_OK`.

No Q02 successor was open. The canonical `farmctl requalify-q02` dry run
returned `ok=true`, `eligible=true`, `would_enqueue=true`, and
`parameter_change_count=0`. It selected the current EX5 and canonical
NZDUSD setfile.

## PACER guard and artifact bindings

No MQ5 source was generated or modified and no compile command was enqueued.
A fresh precautionary source audit nevertheless passed:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_10069_mql5-hs-rev/QM5_10069_mql5-hs-rev.mq5
exit 0; ok=true; EA_FRAMEWORK_INPUT_PINNED hit_count=0
```

The current artifacts remained hash-bound:

- MQ5: `d6243b426c4290aae893cc64088aecc9cca6cbf696abfe8792859588a60ba77c`
- EX5: `4f474930fa4c53657df8252416dc55efa7f3bc974ca706d63faacd54b1db7c55`
- NZDUSD setfile: `9e52a5bfafe2585eb86f86c8f6bc8446596d45e79dacaefbf0ab53a975da3dd1`

The selected setfile retained `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`qm_magic_slot_offset=7`. The requalification comparison covered only the
governed strategy inputs, EA ID, magic offset, and fixed-risk mode; its
parameter diff was empty.

## Binding CPU ceiling

The initial five-sample admission window was below the ceiling (maximum
`90.633569%`), so the exact fallback preflight proceeded. Immediately before
the append-only mutation, the mandatory second five-sample window read:

```text
81.456705%, 93.088616%, 98.051081%, 98.536043%, 93.366752%
average=92.899839%
maximum=98.536043%
ceiling=97%
```

The maximum crossed the hard ceiling. The stop latched for this run and no
Q02 successor, compile work, smoke, dispatch tick, tester launch, terminal
reservation, or terminal control followed. At the post-stop read, the farm
held six active and 6,733 pending work items; factory terminals T1, T5, T6,
T7, T8, and T9 were running. `T_Live` was observed only for exclusion.

## Resume condition and safety

A later paced wake may repeat the current EX5 hash, source-pin audit,
no-open-successor check, dry run, and five-sample CPU admission. It may apply
the exact append-only successor only if both average and maximum remain
strictly below 97 percent at the apply boundary.

No portfolio-admission, portfolio-KPI, Q08-contribution, deploy-manifest,
`T_Live`, AutoTrading, or live surface was changed. Unrelated shared-worktree
changes were preserved and excluded from this evidence commit.

Machine-readable companion:
`docs/ops/evidence/2026-09-12_qm5_10069_nzdusd_q02_cpu_ceiling_stop_023326z.json`.
