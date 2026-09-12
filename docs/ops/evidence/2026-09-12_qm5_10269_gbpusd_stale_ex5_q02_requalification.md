# QM5_10269 GBPUSD.DWX Q02 stale-EX5 recovery

Date: 2026-09-12

Branch: `agents/board-advisor`

EA: `QM5_10269_gawd-wma30-trend`

Symbol/timeframe: `GBPUSD.DWX` / `D1`

## Outcome

The failed Q02 work item `138e5d99-97e1-4d75-83ff-5ef8bea16940` was append-only requalified against the current governed binary. Successor work item `74380fe2-02ab-4e41-8de7-5c6d8394d0b0` was enqueued at Q02 and the factory subsequently claimed it on T5. No strategy parameter, MQ5 source, setfile, registry, portfolio-gate, T_Live, manifest, or AutoTrading state was changed.

This priority-2 recovery was selected after the diversity-first build backlog was checked: candidate pending build tasks were either already represented by downstream work items or excluded from Q02 by the active routing policy. Rebuilding one would have duplicated work rather than improved funnel throughput. This GBPUSD D1 lane is a low-frequency structural FX sleeve and had a concrete stale-artifact failure to recover.

## Claim and collision control

- Farm task: `79eba454-53b2-4549-8620-55bfb810ea6b` (`infra_repair`)
- Claimant: `codex:agents/board-advisor`
- Claim time: `2026-09-12T08:36:33.441824+00:00`
- Pre-claim database backup: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10269_gbpusd_requal_claim_20260912T083633Z.sqlite`
- Backup SHA-256: `6fab327537f99b7265e3c4c5a2c40328f85c31aeccfe3bcda6964d8d063dca65`
- The transactional claim guard found no active/pending repair for this EA and no active work item for this EA before inserting the task.

## Diagnosis

The original run evidence is at `D:\QM\reports\work_items\138e5d99-97e1-4d75-83ff-5ef8bea16940\QM5_10269\20260908_134525\summary.json`. It reports `INFRA_FAIL`, `ONINIT_FAILED`, zero bars, and zero trades; the tester stopped because `OnInit` returned code 1.

The failed run was bound to EX5 SHA-256 `13e0f1e170447b6a951a19f617b8f8534337bc428219467d48f0d7a57cb8680c`, built before the GBPUSD registry expansion. The current registered GBPUSD slot is `6`, with magic `102690006`. The current strict-compile-PASS artifact is:

- MQ5 SHA-256: `ba1bdd99f02957c30d854a243aa870fdbda719cdee8fc0d76b8d788a1c0b1801`
- EX5 SHA-256: `284d46702d34032f95322197fed9295d6e4296ffd387da49c5aa76b7961aecf6`
- Setfile SHA-256: `e976cde6d525ea148d0dd31829783150107373a196aed820af8e84e35ad965a5`
- Compile work item: `3a92321c-deb2-45a0-872e-c39d8602d5cb`
- Compile evidence: `D:\QM\reports\work_items\3a92321c-deb2-45a0-872e-c39d8602d5cb\QM5_10269\COMPILE_EA\compile_evidence.json`
- Compile evidence SHA-256: `224f984c0cdd03c3f5d0d35075f0aa39f40eee449e24b912b60ee59f5ea2fb74`
- Strict compile result: 0 errors, 0 warnings

An ad-hoc `build_check.ps1` invocation was refused by the live-factory guard because terminal processes were active. No unsafe compile was attempted; the current governed compile evidence above was used.

## PACER build guard

Immediately before the applied requalification, the required command was run:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_10269_gawd-wma30-trend/QM5_10269_gawd-wma30-trend.mq5"
```

Result: `ok=true`, predicate `EA_FRAMEWORK_INPUT_PINNED`, hit count `0`. The source therefore contains no prohibited framework-input equality pin. No enqueue-compile command was issued because the source was unchanged and already had current strict compile evidence.

The backtest setfile remains fixed-risk: `RISK_FIXED=1000` and `RISK_PERCENT=0`. Requalification recovered the exact historical predecessor setfile bytes (SHA-256 `9628b9121d6bb82a6034543e3d5f55fba09ace49d533e300fb945284de86eb29`) and compared them semantically with the current setfile. Parameter change count was `0`.

## Q02 requalification

Both dry-run and applied `farmctl.py requalify-q02` checks were eligible. The applied append-only result was:

- Predecessor: `138e5d99-97e1-4d75-83ff-5ef8bea16940` (`done`, `INFRA_FAIL`), preserved
- Successor: `74380fe2-02ab-4e41-8de7-5c6d8394d0b0` (enqueued `pending`, then claimed `active` on T5 at `2026-09-12T08:41:38+00:00`)
- Parameter changes: `0`
- Receipt: `D:\QM\strategy_farm\artifacts\receipts\q02_post_binding_requalification\138e5d99-97e1-4d75-83ff-5ef8bea16940_74380fe2-02ab-4e41-8de7-5c6d8394d0b0.json`
- Receipt SHA-256: `91e33d745a29ab22b2045edc879e3592c45b50137e5cc54153dedc0798b42a96`

Before enqueue, five CPU samples were `82.09`, `92.39`, `88.23`, `76.08`, and `72.83` percent (average `82.33`, maximum `92.39`). The configured ceiling of `97` percent was not reached. No local backtest was launched; only the governed Q02 queue item was appended.
