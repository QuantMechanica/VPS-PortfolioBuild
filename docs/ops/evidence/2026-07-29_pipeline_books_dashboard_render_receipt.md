# Pipeline Books W6-W8 and dashboard final receipt

Date: 2026-07-29
Captured through: 2026-07-29T16:54:32Z
Authority: `SOURCE_STATUS_ONLY_NO_RUNTIME_AUTHORITY`

## Bound implementation

- Branch: `agents/mnt-20260729-implementation`
- Implementation commit: `21c238d5f82702f3f45b21a759dad52916e46c05`
- Parent: `b7805fb5092906da8a6c61ca075dd9529d2c526a`
- Tree: `d0d1d8347e16a030889be40bba6e531db323e9f7`
- Commit delta: 46 files, 12,909 insertions, 99 deletions

The implementation commit contains the W6-W8 source controls, tests, both dashboard
generator changes, the common programme status contract, the master plan, the source-wave
evidence and the complete Claude handoff prompt. This receipt is intentionally a later,
documentation-only commit so it can bind the immutable implementation commit above.

Bound documentation bytes at the implementation commit:

- master plan SHA-256: `175e53e650b12c61decfed2bb9ada3c6f7fca45bfd418bebe82d2fdebbe46796`;
- W6-W8 wave evidence SHA-256: `49fb9710babfeddd13acdaba6be1e26b3cb96036bb532de244aa1d3965a7c6ae`;
- Claude handoff prompt SHA-256: `7ea5e9e5dbd647df426112e2b133a56903fe5cc2782c8f02d22b800f45f59f17`;
- common dashboard status SHA-256: `dbd094799cad2cbb0931a708849e31ebbb74dab91c425a2588fb4a41344ba56b`.

## Verification

### Repository lanes

- Final Green lane: `3005 passed, 1 skipped, 5 deselected, 34 subtests passed` in
  348.21 seconds. Exit code 0.
- Post-count dashboard/status lane: 34 passed.
- Combined focused W6/W7/W8/dashboard contract lane: 244 passed and 9 subtests passed.
- Windows Job/worker/adoption/history-lock/cascade adjacency lane: 115 passed and
  4 subtests passed.
- Python compile check: 28 changed/new Python files compiled.
- Strict JSON check: 6 changed/new JSON files; 5 schema roots use Draft 2020-12.
- `git diff --check`: clean before the implementation commit.

### External residual lane

The separate residual lane produced exactly five failures in 6.05 seconds, with no sixth
failure and no skip/xfail conversion:

1. `tools/strategy_farm/tests/test_dxz_10939_repair_packet.py::test_real_spec_hash_bindings_pass`
2. `tools/strategy_farm/tests/test_dxz_12567_xau_repair_packet.py::test_spec_is_hash_bound_blocked_and_xau_not_xng`
3. `tools/strategy_farm/tests/test_execution_contract_lint.py::test_dxz23_registry_is_source_bound_and_structurally_clean`
4. `tools/strategy_farm/tests/test_execution_contract_lint.py::test_density_execution_contracts_are_source_and_runtime_binding_clean`
5. `tools/strategy_farm/tests/test_execution_contract_lint.py::test_20009_ftmo_news_calendar_is_exact_and_evidence_bound`

They continue to expose the declared DXZ10939/DXZ12567 binding decisions, 25 density
setfile mismatches and the QM20009 calendar hash/coverage/copy drift. No source hash was
silently rebound and no assertion was weakened.

### MQL compile checks

An isolated worktree-local MetaEditor tree compiled the final sources without writing to
T1-T10, T_Live or the repository source tree:

- `runtime_execution_contract_smoke.mq5`: 0 errors, 0 warnings;
- `entry_execution_identity_smoke.mq5`: 0 errors, 0 warnings;
- `basket_order_execution_policy_smoke.mq5`: 0 errors, 0 warnings;
- legacy basket `QM5_10009`: 0 errors, 0 warnings.

The fixtures were compiled, not executed in a terminal. Immediately before cleanup all
four logs still contained `Result: 0 errors, 0 warnings`. The exact generated temp tree
contained 337 files / 127,675,908 bytes and was then removed; no EX5 or compile log was
retained in the repository or on `D:`.

## Read-only production projections

### W6 lifecycle and history

Against productive database SHA-256
`28c3eac195c2aeb778f2d677679990949f124f05407d8f9116f7ed30be8f6cc5`:

- lifecycle row count: 104,120;
- lifecycle plan SHA-256:
  `4527d105d2c7f239f4509f8e2da29c8ed3182c2d841df116643048ee1575636b`;
- ACTIVE 0, BLOCKED 28, FAILED 77,314, PENDING 2,175, QUARANTINED 165,
  SUCCEEDED 24,425, WAITING_INPUT 13.

The history topology audit remained `FAIL_CLOSED`:

- 27 inventory rows;
- one exact cross-terminal mutable-store collision;
- eight cross-terminal ancestor/descendant overlaps;
- audit SHA-256:
  `b00efde1c0dfdb4cbb189e8f60ec0f8c4ff1bbaa7e1a98fc2ffeabb31e9ea325`.

No junction, history directory or database row was changed.

### W7 Q08 dry run

The exact reproducible invocation used the default source label `farm_state.sqlite`, no
current-target manifest, no artifact root and an empty shadow-binding manifest:

- rows: 536;
- disposition: CURRENT 0, ELIGIBLE_REEVALUATION 194, INVALID 0,
  LEGACY_UNVERIFIED 341, SUPERSEDED 1;
- 46 blocking collision groups affecting 315 rows;
- inventory SHA-256:
  `9165e1f976260dcbdfc090ea5dbe244231a8621dfc5e6a5e2042ce8975411fb8`;
- normalized empty-shadow manifest SHA-256:
  `17a94c94ecb536aac1dd7ced7bc678a92814f4f17a7ad503199a2232ab8a3d79`;
- plan SHA-256:
  `5c3c2b84e0657f3c28b02fc9a11e016108520deefe69be76a9a20b6b39b83010`;
- overlay: COLLISION_HOLD 315, NO_RESULT 220, NOT_ELIGIBLE 1, all candidate
  states 0;
- `runtime_action=NONE`, `apply_supported=false`.

The database SHA was identical before and after the lifecycle/W7 read-only commands.

### W8 outcome boundary

No real DXZ challenger or FTMO challenge evidence was supplied. The implementation is a
strict source/shadow evaluator only. Both target lanes remain `NOT_EVALUATED`; no dossier
in this wave establishes `READY_FOR_OWNER_DECISION`, and every runtime, Factory, MT5,
purchase and deployment action remains `NONE`.

## Dashboard source and publication boundary

Both generator sources now consume the same hash-bound W0-W8 programme status and render
the Q08-v3 states, separate DXZ/FTMO lanes, exact residuals and OWNER blockers. The full
hourly generator suppresses its ancillary `ea_metrics` writer while Factory OFF is present
or unreadable and uses read-only/query-only SQLite for all remaining dashboard queries.

The integration generators were exercised once against the two requested managed paths
before final hardening:

- `D:\QM\strategy_farm\dashboards\strategies.html`: 1,160,868 bytes,
  SHA-256 `ee51c3d207874568f5102c9adbc2fe547d5d0604b09912e1b1b116c76574696a`;
- `D:\QM\strategy_farm\dashboards\cockpit.html`: 62,556 bytes,
  SHA-256 `9dee332daf1728ac163c759d9564da3310dfe580c9f66a9e69c58900627c2241`.

Both previews contained the new programme markers. They were intentionally not presented
as durable deployment: the enabled ALWAYS_ON tasks execute the older canonical checkout
and replaced both previews at their next normal runs. No task was stopped, disabled,
repointed or rewritten to preserve a worktree preview.

Final read-only state at 16:53Z:

- `strategies.html`: 1,145,089 bytes,
  SHA-256 `4965685190883ee38c47d99da9d96dfa0b81e9dff3b657aca6f524dc6424d69a`,
  last write 16:00:17Z, new programme marker absent;
- `cockpit.html`: 46,916 bytes,
  SHA-256 `2894a765b9c0cc0be88ed51845a43c199d3d707e8b39a7f86bb0eebb1328a24e`,
  last write 16:53:24Z, new programme marker absent.

Task evidence explains this exact state:

- `QM_StrategyFarm_Dashboard_Hourly`: Ready, last run 18:00 local, result 0,
  action `C:\QM\repo\tools\strategy_farm\dashboards\render_dashboards.py`, working
  directory `C:\QM\repo`;
- `QM_StrategyFarm_Cockpit_2min`: Ready, last run 18:53 local, result 0,
  action `C:\QM\repo\tools\strategy_farm\render_cockpit.py`.

Therefore the source change for both requested files is complete and tested, while durable
publication at the two `file:///D:/...` URLs requires the reviewed implementation commit
to be integrated into `C:\QM\repo`. The unchanged ALWAYS_ON tasks then publish it. A
transient final re-render was deliberately not left behind as a false deployment claim.

## Productive DB drift attribution

The first census saw the 350,314,496-byte DB at SHA-256
`de3c74d740f266f994d36122245e3f8884effb5c5989a75a364d41dacbc835ae`.
The old canonical hourly renderer ran at 18:00 local (16:00Z) and the DB mtime became
16:01:04Z;
the current same-size file hashes to
`28c3eac195c2aeb778f2d677679990949f124f05407d8f9116f7ed30be8f6cc5`.
This is an observed autonomous pre-integration dashboard-writer effect, not a write from
the lifecycle, W7, status or audit commands. The new source closes that writer while OFF
once it is integrated into canonical.

Timezone precision: the earlier source-wave evidence calls `16:01:04` a local time. The
filesystem value is `16:01:04Z`, equivalent to 18:01:04 Europe/Berlin; this final receipt
is the authoritative correction and does not alter the hash-bound source-wave bytes.

## Final safety snapshot

At 16:53:39Z:

- `FACTORY_OFF.flag`: present, 66 bytes, SHA-256
  `09cc4f83e8d5f384f03bc51306beff2cdd165108559a00dbf665097c60b47f1c`,
  byte-identical to the accepted OFF baseline;
- `FACTORY_MUTATION.lock`: absent;
- all 30 managed Factory/AI/respawn/quiescence tasks: Disabled;
- all 5 `ENFORCE_DISABLED` hazards: Disabled;
- Factory worker, smoke, owned phase-runner, review-required phase-runner,
  T1-T10 terminal/metatester and MetaEditor scans: empty;
- T_Live: PID 5220, `C:\QM\mt5\T_Live\MT5_Base\terminal64.exe`, process start
  09:25:43 local; it remained outside Factory scope and was not restarted or touched.

The canonical worktree remained outside implementation scope. At the final snapshot its
pre-existing dirty set was still visible: the QM20172 evidence deletion, three modified
`public-data` files, the MNT043/044 scanner/evidence additions, its two schemas and test.
No canonical file was staged, cleaned, committed, copied over or otherwise changed by this
wave.

## Non-claims and next release step

- Factory remains intentionally OFF; this receipt is not restart authorization.
- W6 remains partial and opt-in; no legacy EA cohort was migrated or run.
- W7 remains a dry-run; no historical Q08 row or overlay was written.
- W8 remains shadow/no-go; no real book was admitted and no FTMO purchase or trade was
  authorized.
- AutoTrading, live deploy, scheduler state and T_Live were untouched.
- Durable dashboard publication is the explicit next release step after controlled
  integration of commit `21c238d5f82702f3f45b21a759dad52916e46c05` into canonical;
  scheduler modification is neither required nor authorized.
