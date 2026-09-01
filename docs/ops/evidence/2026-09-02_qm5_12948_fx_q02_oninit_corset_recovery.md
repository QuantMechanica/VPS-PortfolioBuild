# QM5_12948 diverse-FX Q02 infrastructure recovery

Date: 2026-09-02

Branch: `agents/board-advisor`

Outcome: `COMPILE_OK; EURUSD Q02 HASH-BOUND AND PENDING`

## Selection and collision control

No collision-free higher-diversity approved card remained in the build backlog:
the contemporaneous energy build was already owned by another paced agent. This
unit therefore advanced priority 2, the approved structural
`QM5_12948_mql5-mfi-trend-card` sleeve. Its H1 registry universe is
`EURUSD.DWX`, `GBPUSD.DWX`, and `XAUUSD.DWX`; the EURUSD canary adds FX breadth
relative to the index/metal/energy Q08 survivors.

- Paced-fleet task: `38921c7e-b8e1-4c78-9a92-a7a26f41dcf4`.
- Scoped lease key:
  `manual:codex:agents/board-advisor:QM5_12948:q02-infra-recovery:20260901T220221Z`.
- Governed build task: `5c335ec2-49ff-4015-b35c-b1c437427f3b`.
- The approved card remains G0 `APPROVED`, with R1-R4 `PASS`. No card,
  registry, magic allocation, signal threshold, sizing rule, or symbol scope
  changed.

## Bound failure and repair

Historical EURUSD Q02 row `424738fb-94db-4f6e-bf39-c6135a1728f1` ended
`done / INFRA_FAIL` with
`run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS`. It executed stale EX5 SHA-256
`bed127f9d9d35a577d315c8f1ba977b109a44a109b4f01cf3fe342c6d9be347c`.
The exact replacement row `4f9fb7eb-21e6-4e84-9bb4-b3c2b39b7854` remained
pending but was held by `MAE_HOOK_RECOMPILE_REQUIRED` and quarantined from
claiming.

The latest governed compile predecessor,
`d9641f79-f3c5-413f-bcfc-70a0fbb7b18d`, had already compiled with zero errors
and zero warnings. Its only strict-check failure class was
`EA_FRAMEWORK_RAW_SERIES_CALL`, caused by two direct closed-bar `iClose` reads.
The repair replaces those reads with the pooled V5 one-period SMA reader,
which is exactly the completed-bar close. It also refreshes the current
framework corset by zero-initializing the entry request and keeping the central
news blackout on entry only so ordinary management and exits remain reachable.
No strategy mechanic or parameter changed.

## Governed compile

Compile work item `adaa76e1-53d7-4cc5-abca-801ae8781343` was released through
the reviewed compile-wave ceremony, bound to the exact active build task, and
claimed by resident worker T8. It completed at `2026-09-01T22:38:24Z`:

- status/verdict: `done / COMPILE_OK`;
- strict build check: PASS, zero failures and zero warnings;
- MetaEditor: PASS, zero errors and zero warnings;
- MQ5 SHA-256:
  `547c1859462963269c4b6ff564aeea16c153e034ce0a62c60f9bb2cab03d5dda`;
- EX5 SHA-256:
  `9ddbd7a08389dd4ce14302da686dde32e1dcf785df2f242b111d24af3d132e20`;
- receipt:
  `D:\QM\reports\work_items\adaa76e1-53d7-4cc5-abca-801ae8781343\QM5_12948\COMPILE_EA\compile_evidence.json`.

The three regenerated H1 presets retain the fixed-risk contract and registered
slots 0-2:

| Symbol | Setfile SHA-256 | Risk |
| --- | --- | --- |
| EURUSD.DWX | `98dcd931ec1192f5548be1caa107ea1a35bcc22337a3c60dd9e1daced2cb9025` | `RISK_FIXED=1000`, `RISK_PERCENT=0` |
| GBPUSD.DWX | `54fbb4932c5dc8973a0ac7647eb3073f943aaccb1fbe9637d141f4ad634c5645` | `RISK_FIXED=1000`, `RISK_PERCENT=0` |
| XAUUSD.DWX | `26c241c67f0db5390d8e5dcb46eddfba260a72ade2de6c2f1700de366add7a36` | `RISK_FIXED=1000`, `RISK_PERCENT=0` |

## Q02 handoff

Because the exact EURUSD replacement already existed as an unclaimed
pre-binding row, creating another seed would have duplicated the Q02 identity.
A guarded `BEGIN IMMEDIATE` compare-and-swap instead refreshed that row in
place, preserving its historical predecessor and queue identity. Transition
ledger sequence 2703 records the operation.

At `2026-09-01T22:43:59Z`, work item
`4f9fb7eb-21e6-4e84-9bb4-b3c2b39b7854` was:

- `pending`, unclaimed, attempt 0, with no verdict;
- bound to the exact MQ5, EX5, and EURUSD setfile hashes above;
- bound to `EURUSD.DWX / H1` and expert
  `QM\QM5_12948_mql5-mfi-trend-card`;
- SH3 identity enforcement enabled;
- fixed-risk bound at `1000 / 0`;
- released from `MAE_HOOK_RECOMPILE_REQUIRED`.

The stale-binary poison quarantine was released at `2026-09-01T22:44:11Z`.
The recoverable pre-image journal is
`D:\QM\strategy_farm\artifacts\ops\qm5_12948_q02_binding_refresh_20260901T224226Z.json`.
Execution remains owned by the paced farm; this unit did not manually dispatch
or run Q02.

## Verification and safety boundary

- `skill_build_ea_guard.py`: registry row, magic rows, and EA directory PASS.
- `validate_spec_doc.py`: 1 PASS, 0 FAIL.
- `validate_build_guardrails.py`: PASS, zero findings.
- Pre-handoff host samples averaged 80.70% CPU and peaked at 88.68%, below the
  97% stop ceiling; the same snapshot found no factory `terminal64` or
  `metatester64` process.
- No T_Live write, AutoTrading action, portfolio-gate change, deploy-manifest
  change, live-use authorization, or certification claim was made.

Machine-readable companion:
`artifacts/qm5_12948_fx_q02_infra_recovery_20260902.json`.
