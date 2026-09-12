# QM5_10069 NZDUSD current-binary Q02 requalification enqueue

Recorded: 2026-09-12T17:19:08Z (19:19:08 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `c3411c90a340319e7cc75abde31fe8b19ec1dca7`

## Outcome

The frozen 66-pair FX cointegration scan remains fully mechanized. Its two
published survivors are already built and beyond Q02: `QM5_12532` has Q02
PASS and Q04 PASS before Q05 FAIL, while `QM5_12533` has Q02 PASS before Q04
FAIL. The repository's approved next-best Edge Lab reconciliation also has no
unbuilt pair. No duplicate Strategy Card, EA, basket manifest, registry row,
compile row, or pair-Q02 row was created.

The permitted existing-forex fallback was advanced instead. The stale-binary
NZDUSD Q02 predecessor for the approved, structural, low-frequency H1 card
`QM5_10069_mql5-hs-rev` remained terminal `INFRA_FAIL` with no open successor:

- predecessor: `727fd995-bf25-4943-bf14-422f59adab65`
- current governed compile: `7deba014-7ca5-4e79-bd20-789bad639b69`, `COMPILE_OK`
- appended Q02 successor: `1f5ada0e-2ffd-4289-b369-91201e44fe8d`
- symbol/timeframe: `NZDUSD.DWX`, H1
- parameter changes: 0
- runtime receipt: `D:/QM/strategy_farm/artifacts/receipts/q02_post_binding_requalification/727fd995-bf25-4943-bf14-422f59adab65_1f5ada0e-2ffd-4289-b369-91201e44fe8d.json`
- receipt SHA-256: `d8211d19931d7d2f7bb162b259dc84e9a98ca0711494f49f0f8c179ce0f501f6`

The canonical append-only `farmctl requalify-q02` dry run returned `ok=true`,
`eligible=true`, `would_enqueue=true`, and an empty parameter diff. The apply
then returned `applied=true`. A resident worker claimed the successor on T7
almost immediately; no manual dispatch tick, terminal reservation, tester
launch, or terminal control was performed by this run.

## PACER guard and artifact binding

No MQ5 source was generated or changed and no compile command was enqueued, so
the binding post-write/pre-compile audit trigger did not arise. A precautionary
absolute-path audit was nevertheless run:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_10069_mql5-hs-rev/QM5_10069_mql5-hs-rev.mq5
exit 0; ok=true; EA_FRAMEWORK_INPUT_PINNED hit_count=0
```

Current artifact bindings:

| Artifact | SHA-256 |
| --- | --- |
| MQ5 | `d6243b426c4290aae893cc64088aecc9cca6cbf696abfe8792859588a60ba77c` |
| EX5 | `4f474930fa4c53657df8252416dc55efa7f3bc974ca706d63faacd54b1db7c55` |
| NZDUSD H1 setfile | `9e52a5bfafe2585eb86f86c8f6bc8446596d45e79dacaefbf0ab53a975da3dd1` |

The selected setfile retains `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`, `qm_ea_id=10069`, and `qm_magic_slot_offset=7`.
Requalification compared only those governed fields and the `strategy_*`
parameters; it did not compare RNG, news, Friday-close, or stress values.

## Capacity and safety

The initial five-sample whole-host CPU window was 71.780189%, 72.143308%,
75.795872%, 68.269507%, and 59.182719% (average 69.434319%, maximum
75.795872%). The immediate apply-boundary window was 76.369872%, 54.513069%,
51.002695%, 63.577829%, and 73.244820% (average 63.741657%, maximum
76.369872%). Both cleared the 97% hard ceiling. The post-enqueue window also
cleared it: average 58.878715%, maximum 69.159153%.

At the first post-enqueue observation the farm had 6 active and 5,847 pending
work items. The successor was `active`, attempt 0, claimed by T7, with no
verdict yet.

- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface was touched.
- No T_Live manifest, deploy artifact, or AutoTrading state was touched.
- No Card, EA source, EX5, setfile, basket manifest, registry, or magic row was
  changed.
- Pre-existing unrelated shared-worktree changes were preserved and excluded
  from this evidence commit.

Machine-readable companion:
`docs/ops/evidence/2026-09-12_qm5_10069_nzdusd_q02_requalification_enqueue.json`.
