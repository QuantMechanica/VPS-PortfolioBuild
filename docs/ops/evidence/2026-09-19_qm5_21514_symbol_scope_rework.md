# QM5_21514 symbol-scope rework and governed compile handoff

Router task: `b8c2e67c-773b-4698-913b-9de744f6317e`  
EA: `QM5_21514_qs-klinger-vol-osc-xag`  
Source repair commit: `ba7181fa1c`  
Disposition: **BLOCKED — source repaired; governed compile authority and fresh build identity required**

## Result

The historical build remained byte-identical to its August evidence, but the
current build gate correctly rejected its hard-coded
`_Symbol != "XAGUSD.DWX"` comparison. That comparison would permanently block
the entry path on bare-symbol Darwinex Zero or FTMO charts.

The source now declares `strategy_host_symbol` as an input and compares
canonical base names with `QM_MagicSymbolCanonical`. Both shipped XAGUSD D1
setfiles bind the factory value `XAGUSD.DWX`, retain `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `qm_news_stale_max_hours=336`, and carry
`build_hash: pending` for the governed compiler to seal. `SPEC.md` records the
deployment-bound input. No entry, exit, sizing, KVO, timeframe, or risk logic
changed.

Repaired source SHA-256:
`5f051d625df5a0c546f043e6bffc34189aed6100ee6d0a4fe0113f492af4868a`.

## Verification

- Focused regression: `2 passed` in
  `docs/test_qm5_21514_symbol_scope.py`.
- Symbol-literal lint: `OK: no hardcoded .DWX symbol literals in EA sources`.
- `validate_build_guardrails.py --max-news-stale-hours 336 <EA directory>`:
  `PASS`, zero findings.
- `audit_framework_input_pins.py --check-source <mq5>`: `ok=true`, zero hits.
- `validate_spec_doc.py <EA directory>`: `PASS`.
- Approved runtime card remains `g0_status: APPROVED`; active registry identity
  remains EA `21514`, slot `0`, `XAGUSD.DWX`, magic `215140000`.

## Governed compile boundary

Ad-hoc `build_check`/compile was correctly refused while terminal processes
were active (`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`). The required
`farmctl enqueue-compile` path was then invoked with the exact router task ID.
It made no queue mutation and refused with:

- `BUILD_TASK_BINDING_NOT_FOUND` — this legacy agent-router task is not an open
  build row in the compile inventory;
- `EX5_ALREADY_PRESENT` — the historical binary is immutable without an exact
  force/source-repair authority;
- `WORK_ITEMS_EXIST` — the EA already has append-only pipeline lineage.

No gate was weakened, no source-repair authority was invented, no historical
EX5 was overwritten, no pipeline phase was enqueued, and no terminal,
`T_Live`, or AutoTrading state was touched. A fresh 0-error/0-warning compile
can occur only after Claude/OWNER supplies an exact compile-only authority for
this task/source binding. The historical compile verdict is not presented as a
verdict on the repaired source.

The required router transition to `REVIEW` was attempted and independently
refused by D6 as `build_identity_json_missing_review_dispatch_refused`. D6
requires a JSON packet binding a committed current MQ5, freshly compiled EX5,
setfiles, and strict-build PASS. Those facts do not yet exist and were not
fabricated. The truthful terminal router disposition for this cycle is
therefore `BLOCKED`.

RESULT: `BLOCKED_COMPILE_AUTHORITY_AND_BUILD_IDENTITY_REQUIRED`.
