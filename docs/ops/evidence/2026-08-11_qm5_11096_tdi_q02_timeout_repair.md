# QM5_11096 Q02 TDI timeout repair

Date: 2026-08-11
Branch: `agents/board-advisor`
EA: `QM5_11096_tdi-mbl-cross`
Scope: Q02 infrastructure repair and append-only FX requalification; no economic verdict

## Selection and coordination

- The approved build backlog had no clean, unclaimed forex/crypto/rates/pairs card ready for a non-duplicate build. `QM5_11096` is an approved, reputable-source H1 TDI card spanning three major-FX pairs plus XAU, with 48 historical Q02 `INFRA_FAIL` rows and no economic Q02 verdict.
- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_11096_tdi-mbl-cross.md`; its G0 and R1-R4 fields are approved/pass.
- EA registry row `11096` is active. Active magic slots are 0/1/2/3 for `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, and `XAUUSD.DWX` respectively.
- Farm claim: `agent_tasks.id=f6a35af4-66fd-4d2b-9e53-e99498781ea3`, assigned to `codex:agents/board-advisor` before source changes.
- Pre-claim DB backup: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11096_tdi_perf_20260811T172118Z.sqlite`.

## Diagnosed infrastructure defect

The prior `OnTick()` called `Strategy_ExitSignal()` before the `QM_IsNewBar()` gate. While a position was open, that exit hook rebuilt TDI state for closed bars 1 and 2 on every tick. Each TDI state made `2 + 7 + 34 + 34 = 77` pooled RSI reads (price line, signal line, market-base line, and band deviation), or about 154 reads per tick. Entry was bar-gated, but the identical exit inputs were not.

This is consistent with the repeated terminal rows that never produced a usable Q02 summary:

| Symbol | Terminal source row | Recorded class | Historical bound EX5 |
|---|---|---|---|
| `EURUSD.DWX` | `19692f23-7fa5-46ff-b5cd-152d7b5055b3` | `DETERMINISTIC_NO_SUMMARY` | `382cb168d63f75dc89d095e564ede3870f1e82e6fe804cde5eaa75a295e1b09d` |
| `GBPUSD.DWX` | `3d452e18-76f4-430b-9a94-8de2b1a91da9` | `DETERMINISTIC_NO_SUMMARY` | `382cb168d63f75dc89d095e564ede3870f1e82e6fe804cde5eaa75a295e1b09d` |
| `USDJPY.DWX` | `48e9c802-b915-49b3-9ccd-3a44327ae1da` | `DETERMINISTIC_NO_SUMMARY` | `382cb168d63f75dc89d095e564ede3870f1e82e6fe804cde5eaa75a295e1b09d` |

The historical MQ5 binding on those rows was `08f6463ac2ff8bfc6b76d52a710e93f7645b98e9927ffb73fbec7fb07610433e`. This repair addresses execution cost only; it does not reinterpret an economic failure.

## Repair

- Added `Strategy_UpdateTdiClosedBarState()` and four cached entry/exit cross decisions.
- Refresh the shared TDI state once after `QM_IsNewBar()` reports a new chart bar.
- Entry and strategy-cross exits consume the same cached closed-bar state.
- The 18-bar elapsed-time stop still scans open positions every tick, so exit timing and card mechanics are preserved.
- Regenerated all four canonical backtest setfiles from the approved card with eight explicit `strategy_*` inputs. Every setfile binds `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the registered symbol slot.

Current artifact bindings:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `770f5b3652ba16da6fcd6869c29762e8b9baafc2f875a6ec0d955d25fc6e42ab` |
| EX5 | `4d534db56ba67f13812ad2b06dc4661db8d1e80c5843cc4b52397e9a04703d9e` |
| EURUSD set | `24ae0dd9c5f8dc4ce6b5463cd71dcab4328bdcf40c00caf919fe23632a3b362d` |
| GBPUSD set | `6bdc0b437c7aa32c8c727e62dad4c56f071cb1debbd8a53677878b0496065c97` |
| USDJPY set | `bcc1f163a923f84907c179bc9e49189835fcc2e27e40817952f9e8c3886bec2d` |
| XAUUSD set | `d0bed2d8f9074fd3162648e02fea353a4d10e5218e036c2fca33e72a755a2dfc` |

## Verification

- `pwsh framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_11096_tdi-mbl-cross/QM5_11096_tdi-mbl-cross.mq5 -Strict`: PASS, 0 errors, 0 warnings.
- Final compile log: `C:\QM\repo\framework\build\compile\20260811_172703\QM5_11096_tdi-mbl-cross.compile.log`.
- `pwsh framework/scripts/build_check.ps1 -EALabel QM5_11096_tdi-mbl-cross -Strict`: PASS, 0 failures, 0 warnings.
- Build-check report: `D:\QM\reports\framework\21\build_check_20260811_172703.json`.
- Static setfile audit: four fixed-risk files, eight explicit strategy parameters each, no pending build hash.
- Factory scan immediately before enqueue showed T2/T7/T8 active (3 of 10 factory terminals), so the backtest CPU ceiling was not active. No manual tester was launched.

## Q02 handoff

Only the diversity-priority FX sleeves were enqueued. Historical rows remain append-only.

| Symbol | New Q02 work item | Source row | Enqueue mode | Canonical setfile SHA-256 |
|---|---|---|---|---|
| `EURUSD.DWX` | `b5a4436c-a96c-4443-84f4-70b86b9440be` | `19692f23-7fa5-46ff-b5cd-152d7b5055b3` | repaired-INFRA append-only rerun | `24ae0dd9c5f8dc4ce6b5463cd71dcab4328bdcf40c00caf919fe23632a3b362d` |
| `GBPUSD.DWX` | `a5f3977e-665a-414f-9947-fee9570c00ec` | `e5fae6bf-cd90-44b5-9f3b-b98b48fbea0b` | targeted stranded-INFRA append | `6bdc0b437c7aa32c8c727e62dad4c56f071cb1debbd8a53677878b0496065c97` |
| `USDJPY.DWX` | `c14eb4d1-d44b-46ba-aa4d-f316b905339c` | `c9e687a2-0818-4d93-b37b-8e9dda319fc9` | targeted stranded-INFRA append | `bcc1f163a923f84907c179bc9e49189835fcc2e27e40817952f9e8c3886bec2d` |

The newer USDJPY terminal row named a missing log file, so the guarded append-only path correctly refused it; an authenticated pre-binding seed was used for the first handoff. At 17:30 UTC, the scheduled worktree cleaner archived and restored the still-uncommitted tracked EX5 while the GBPUSD and USDJPY workers were between staging and spawn. The runner identity guard correctly recorded both as `staged_ex5_sha256_mismatch_before_spawn` without launching a tester (`e5fae6bf-cd90-44b5-9f3b-b98b48fbea0b` and `c9e687a2-0818-4d93-b37b-8e9dda319fc9`). The exact compiled binary was recovered from `C:\QM\archive\repo-dirty-20260811T173009Z\tracked-before-restore\...` with SHA-256 `4d534d...03d9e`, then the standard targeted stranded-INFRA sweep appended the final GBPUSD and USDJPY rows shown above. At the last audit those replacements were active on T3/T4 with the repaired EX5 hash, while EURUSD remained pending with its full current-artifact binding.

XAUUSD was deliberately not enqueued because the mission prioritises instrument diversity and the surviving certified funnel is already concentrated in metals/indices/energy.

No portfolio gate, T_Live artifact, live manifest, or AutoTrading setting was touched.
