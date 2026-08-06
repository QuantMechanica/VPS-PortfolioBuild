# QM5_11353 FX stale-EX5 Q02 recovery

Date: 2026-08-06
Branch: `agents/board-advisor`
Farm claim: `14164eb0-b1fe-4487-9a99-6b0a1ed8ff15`
Status: `REPAIRED_COMPILE_PASS_Q02_PENDING`

## Outcome

`QM5_11353_rbt-cci14-zone-cross-h1` was blocked on the diverse FX cross basket by a stale compiled binary. The unchanged approved strategy source was recompiled against the current generated magic resolver, all 28 H1 backtest setfiles were regenerated with the canonical fixed-risk contract, and one hash-bound Q02 canary was appended through `farmctl seed-fresh-q02`.

No entry, exit, sizing, filter, or framework source logic changed.

## Selection and farm coordination

- Priority-1 build work was not claimable without collision: `QM5_20254_xauxag-vr-fade` was actively changing in the shared working tree.
- Priority-2 candidate selected: `QM5_11353_rbt-cci14-zone-cross-h1`, an approved 28-pair FX sleeve with fresh deterministic Q02 infrastructure failures.
- Atomic farm claim: `manual:codex:agents/board-advisor:QM5_11353:q02-stale-ex5-recovery:2026-08-06T21:51:23+00:00`.
- Pre-claim DB backup: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11353_q02_repair_claim_20260806T215122Z.sqlite`.

## Failure evidence and root cause

Fresh terminal row `e9233f8f-5a0a-4446-8491-b997d0a6bc1a` ran `EURJPY.DWX` H1 with magic slot 15 and the retained June binary:

- Summary: `D:\QM\reports\work_items\e9233f8f-5a0a-4446-8491-b997d0a6bc1a\QM5_11353\20260806_212540\summary.json`
- Tester log: `D:\QM\reports\work_items\e9233f8f-5a0a-4446-8491-b997d0a6bc1a\QM5_11353\20260806_212540\raw\run_01\20260806.log`
- Log line 2925: `EA_MAGIC_NOT_REGISTERED: ea_id=11353 slot=15 magic=113530015`
- Old EX5 SHA-256: `53d767f23e4425293627e80ef574c334002ece126c5043262cffa8c0376ec355`
- Old EX5 last write: `2026-06-30T13:30:02.7021860Z`

The authoritative registry already contains the active slot-15 row at `framework/registry/magic_numbers.csv:14034`, and the current generated resolver contains magic `113530015`. The resolver file SHA-256 used for the rebuild was `d36d10d09f9f58d1180337035670e0803867e272ba9e84c44f05c6bdae710aaf`; its embedded registry digest is `E9F79F7A6DAD737A174530BB0D9127D07061743FD6F7D3527FE819BD5369E20B`.

This establishes a stale pre-resolver EX5 infrastructure defect. The `.mq5` source remained byte-identical at SHA-256 `c42e5eaed8e6606210f879e27a26bae6d029947682b512055f278030931801c8`.

## Repair

- Recompiled in place with `framework/scripts/compile_one.ps1 -EAPath ... -Strict`.
- New EX5 SHA-256: `8d786847a22752c348277012fee71a95dd83894031565bc1ebc3c98861bdefa8`.
- Regenerated all 28 active-symbol H1 backtest setfiles through `gen_setfile.ps1`.
- Every regenerated setfile contains `qm_ea_id=11353`, its registered symbol slot, `RISK_FIXED=1000`, `RISK_PERCENT=0`, all ten strategy inputs, and a non-pending build hash.
- Sorted 28-file setfile-manifest SHA-256: `7b5605aa459070d3af1d14d910f521d9cd9a3a3b93b9956f713f246a4c0e5f2d`.

## Validation

- Strict compile: `PASS`, 0 errors, 0 warnings.
  - Log: `C:\QM\repo\framework\build\compile\20260806_215400\QM5_11353_rbt-cci14-zone-cross-h1.compile.log`
  - Summary: `D:\QM\reports\compile\20260806_215400\summary.csv`
- `validate_spec_doc.py`: `PASS`.
- `validate_build_guardrails.py`: `PASS`, 29 files checked, 0 findings.
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`, 0 violations.
- `build_check.ps1 -Strict -SkipCompile`: `PASS`, 0 failures, 0 warnings.
  - Report: `D:\QM\reports\framework\21\build_check_20260806_215548.json`
- Resolver SHA-256 was unchanged before and after compile, excluding a concurrent include mutation during the build.

Per the `qm-build-ea-from-card` boundary, this repair did not run a manual backtest phase. The current-binary Q02 row below carries the runtime evidence burden.

## Q02 handoff

At `2026-08-06T21:57:17Z`, host CPU was 27% with four active factory work items, below the backtest ceiling. No manual terminal or tester process was started.

- Pre-enqueue DB backup: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11353_q02_seed_20260806T215823Z.sqlite`.
- Guarded command: `farmctl.py seed-fresh-q02` from pre-binding source row `07d2cb16-4635-4e5b-89fe-a2c98d38e88f`.
- New Q02 work item: `b8dd5a59-73c0-4dd0-a101-74dffbb9d477`.
- State at handoff: `pending`, `claimed_by=NULL`, attempt 0.
- Symbol/timeframe: `EURUSD.DWX` / H1.
- Bound EX5 SHA-256: `8d786847a22752c348277012fee71a95dd83894031565bc1ebc3c98861bdefa8`.
- Bound setfile SHA-256: `db3522549b2bb356abb2c98cad58384f7708f54b5d1118d14689785ae9dc23a6`.
- Risk binding: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Historical work items were preserved; eight existing pending cross-pair Q02 rows were not edited or duplicated.

## Safety boundary

- No `T_Live` file, process, manifest, or AutoTrading setting was touched.
- No portfolio gate or live-deploy artifact was touched.
- No factory process was killed, restarted, or manually dispatched.
- Only `QM5_11353` build artifacts, its SPEC, and this recovery evidence are in the commit scope.
