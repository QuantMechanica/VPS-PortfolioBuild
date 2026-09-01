# QM5_41192 XTI/XNG Q02 binary recovery — CPU-ceiling stop

Date: 2026-09-01  
Branch: `agents/board-advisor`  
Outcome: `RECOVERY_AUTHORIZED_COMPILE_HELD_CPU_CEILING`

## Selected diversity unit

`QM5_41192_xtixng-mdaily-hl-rv` is the approved low-frequency XTI/XNG
monthly Hodges-Lehmann relative-value basket. It contributes a paired energy
spread mechanic rather than another directional index, metal, or standalone
XNG sleeve. The existing logical Q02 row is
`06e46647-e8b6-4148-8d51-586cb8114acd`.

The farm router claim is the exact ops task
`000bb713-5f0f-4e2e-b4bf-558fcbc86d7c`, assigned to Codex and moved to
`IN_PROGRESS` before any mutation.

## Diagnosis

The Q02 item remained `pending`, unclaimed, attempt zero, and verdict-free,
but its required compiled artifact was absent:

- expected path:
  `framework/EAs/QM5_41192_xtixng-mdaily-hl-rv/QM5_41192_xtixng-mdaily-hl-rv.ex5`;
- filesystem result: missing;
- the sealed 2026-08-29 enqueue receipt records that the prior EX5 was not
  tracked by Git;
- no source, signal, lifecycle, risk, setfile, card, registry, or magic repair
  was required.

Current bytes still match the sealed Q02 receipt exactly:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `630cf4a9c18a2ec5ff4d86b04df000a48a4ecf793e09d8d028f3d094a7cf238d` |
| SPEC | `06a3361970f3522844a0bb462e902948a76b28837717ac4ea4be582e3231ed4a` |
| Basket manifest | `7580f8f49964b7f42b0b6af9bed77573e599a07a78862d9940f1f42e073cd136` |
| Logical Q02 setfile | `ec71135e05f7de648c3d37b5c36d1baaede967c2580a412a1e409df7ac6569a5` |
| Approved card | `4a29a6e1bad3d9da53d97b7e762ccdae342354f8b479e357e85a0a37a4a2c4e2` |

The approved card and queued payload retain `RISK_FIXED=1000` and
`RISK_PERCENT=0`, D1 host timing, XTI/XNG two-leg scope, and monthly
frequency.

## Fail-closed recovery and verification

Commit `219b094cca` adds a one-router-task/one-EA append-only binary-recovery
authority to the governed `COMPILE_EA` path. It waives only the expected
`WORK_ITEMS_EXIST` and `BOUND_SETFILE_HASH_EXISTS` classifier findings for
this exact label. It grants no authority to alter strategy mechanics, run a
backtest, issue a gate verdict, overwrite another EA, or create another Q02
row.

Verification completed before queue mutation:

- exact recovery tests: `4 passed, 49 deselected`;
- complete compile-work-item suite: `53 passed in 73.65s`;
- EA deterministic reference suite: `9 passed`;
- SPEC validator: PASS;
- card schema and G0 linters: PASS;
- V5 registry/magic/directory build guard: PASS;
- live-factory ad-hoc compile interlock: correctly refused before MetaEditor;
  no manual compile occurred.

The governed enqueue appended compile work item
`0d00bf54-535c-4049-ad7f-fde0c6b13f12`, source-bound to the MQ5 hash above
under authority
`router_ops_issue:000bb713-5f0f-4e2e-b4bf-558fcbc86d7c`.

At the stop boundary the compile row is `pending`, unclaimed, attempt zero,
verdict-free, and protected by the active
`COMPILE_EA_WORKER_ROLLOUT_PENDING` release-on-restart hold. The original Q02
row is unchanged: `pending`, unclaimed, attempt zero, verdict-free. No
duplicate Q02 item was appended.

## Mandatory CPU stop

The first fresh five-sample whole-host window remained below the 97% ceiling
(`75.70, 70.61, 72.31, 69.17, 67.58`; maximum `75.70%`). The immediately
following binding window was:

```text
samples_pct = 99.02, 89.10, 88.87, 90.83, 86.45
average_pct = 90.85
maximum_pct = 99.02
ceiling_pct = 97.00
ceiling_hit = true
```

The mission requires an immediate stop when any sample reaches the backtest
CPU ceiling. Therefore the activation hold was not released. No worker claimed
the compile item, no EX5 was produced, no tester was launched, and the Q02 row
was not advanced.

## Safe continuation

After a new five-sample window remains strictly below 97%, release only compile
item `0d00bf54-535c-4049-ad7f-fde0c6b13f12` through
`tools/strategy_farm/release_compile_wave.py`. Require `COMPILE_OK`, strict
zero-error/zero-warning build evidence, and a current source-bound EX5. Then
leave the already-pending logical Q02 row to the normal worker selector; do not
enqueue a duplicate or launch a manual tester.

No AutoTrading setting was changed. No `T_Live` control, live/deploy manifest,
portfolio gate, gate threshold, or historical verdict was touched.
