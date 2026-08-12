# Pipeline Books canonical integration and durable publication receipt

Date: 2026-07-29
Authority: `SOURCE_STATUS_ONLY_NO_RUNTIME_AUTHORITY`
State: completed post-integration evidence

## Bound source history

- Canonical checkout: `C:\QM\repo`
- Canonical branch: `agents/board-advisor`
- Pre-integration Canonical HEAD: `637d5a152ba51607bdec5e856300dae57f6d0388`
- Audited integration target: `be63772bf5370204312ea174d3627c0a74cceaa1`
- W6-W8/dashboard implementation commit: `21c238d5f82702f3f45b21a759dad52916e46c05`
- Historical final-render receipt commit: `be63772bf5370204312ea174d3627c0a74cceaa1`
- Post-checkout publication-hardening commit: `aa67ab8468bb895e438a06a6db15398f7cdc57cd`

The merge base of the pre-integration Canonical HEAD and the target was exactly
`637d5a152ba51607bdec5e856300dae57f6d0388`. Canonical was advanced with one pinned
`git merge --ff-only be63772bf5370204312ea174d3627c0a74cceaa1`; no rebase,
cherry-pick, squash, force checkout or merge commit was used. Both `21c238d5f...` and
`be63772b...` are independently verified ancestors of `aa67ab846...`.

Commit `aa67ab846...` contains exactly seven files and changes 167 insertions / 67
deletions. It closes a Windows-checkout hash portability defect, adds regression tests,
makes the P19 repository test insensitive only to source-free empty directories, advances
the verified test count, and updates the Claude audit handoff to the post-publication
state. The receipt that contains this paragraph is intended to be a documentation-only
successor; its own commit ID must be measured from Git rather than inferred from its text.

## Canonical open-worktree preservation

Before the fast-forward, all existing dirty bytes were copied to the recoverable external
backup:

`C:\QM\integration_backups\20260729T190710+0200_canonical_before_be63772b`

The backup contains ten existing files under `snapshot` and seven temporarily displaced
untracked collision files under `displaced_for_fast_forward`. The deleted old QM20172
receipt was represented by absence plus the byte-identical R100 rename target. No backup
was deleted.

The seven incoming path collisions were classified before mutation. Six were byte-identical
to the target; the scanner Markdown differed only by one additional final LF. After the
fast-forward all seven active files were restored to their exact pre-integration raw bytes.
The six byte-identical files remain Git-clean after an index-stat refresh; the intentionally
different scanner Markdown remains modified. Relevant preserved SHA-256 values:

- `docs/ops/MNT043_044_CLOSURE_DRIFT_SCANNER.md`:
  `5ee59f93ca32e68c08fc1fcebd6a3babe005453d36f23d4fdcb50e02c6f85852`;
- QM20172 quarantined rename target:
  `eae31a552ba21b5ffae59ca7cc8284be705acfdaf7a755aaee1527e7717bb85a`;
- scanner canary:
  `490a1ebdd0075fb34a5da21ba419638874056b6f9cabc630faab94d5d38e8ee9`;
- `mnt_closure_drift.py`:
  `7d152009e3d29ed8ed3ce55f9a2680ab408f56cb8657fac43852cb999c7e8e0c`;
- adjudication schema:
  `ed8e8ba097fad7e252922d21e96b5c3eebac1214ebb030d95a569297a2cf3b8b`;
- drift-report schema:
  `a463c5c4d034fccd010e163553345c7603bd45d5aa0a2384a61d3b739e631d7a`;
- scanner test:
  `8ce3eb51a6f297ca60217953c331c19090843f578dc23f4482999a308ef8e916`.

The three pre-existing public-data changes were never touched by the incoming stack and
remain byte-identical to their pre-integration state:

- `public-data/process-roadmap.json`:
  `a7a4c97e73b069b5fb6f8c59d7a376a4eb9bb1eac8cf4eca7d26fe3818a017f6`;
- `public-data/public-snapshot.json`:
  `aadbabc8d55c808812437c43da1f2e0676912ca723a548730afbb92b3243e5e6`;
- `public-data/strategy-archive.json`:
  `5fe3985754f47bd59382b908aaa7fa4359ef89d08d57f187d775deef5bafd4e2`.

Immediately after the hardening commit, Canonical had only these four intended unstaged
paths: the scanner Markdown plus the three public-data files. None was included in either
the hardening commit or this receipt commit.

## Checkout-portable status binding

The first automatic Cockpit render after the fast-forward correctly failed closed as
`INVALID`. System Git configuration has `core.autocrlf=true`; all six bound text artifacts
were LF Git blobs but CRLF working-tree files. The pre-hardening helper hashed raw checkout
bytes, so every `file_sha256` binding mismatched even though the committed content was
identical.

Commit `aa67ab846...` establishes the explicit
`TEXT_BYTES_CRLF_TO_LF_SHA256_V1` contract. Only CRLF byte pairs map to LF before SHA-256;
BOM, standalone CR, whitespace and all other bytes remain significant. The six existing
declared hashes already equal the LF-normalized Git content, so no source artifact was
silently rebound. Q08 policy and both target rulepacks retain their separate semantic
canonical hashes.

The contract is explicit and identical in config, schema, helper and tests. New negative
coverage verifies missing/unknown contract, BOM drift, standalone-CR drift and material
byte drift; LF and CRLF checkout forms are positively equivalent. Binary files are not
covered by this text contract.

The updated Claude handoff is:

`docs/ops/CLAUDE_HANDOFF_AUDIT_W6_W8_DASHBOARDS_2026-07-29.md`

At commit `aa67ab846...` its Git-blob / CRLF-to-LF SHA-256 is
`461edb05954d5591583e744f990679d67ebc9a666300febbfc4610567f39f8a7`.
The current Windows CRLF worktree representation measured
`29a63797f9b9979520a5ea808b409469c0d1667e063ae6c0d6496c82513e38b7`;
the distinction is intentional and auditable under the named contract.

## Verification lanes

Final Green lane against the source committed as `aa67ab846...`:

`3010 passed, 1 skipped, 5 deselected, 34 subtests passed in 350.18s`

The five deselections were only the exact node IDs declared in
`tools/strategy_farm/config/test_lanes.v1.json`. Their separate fail-closed run produced
exactly five failures in 5.53 seconds and no sixth failure:

1. `tools/strategy_farm/tests/test_dxz_10939_repair_packet.py::test_real_spec_hash_bindings_pass`
2. `tools/strategy_farm/tests/test_dxz_12567_xau_repair_packet.py::test_spec_is_hash_bound_blocked_and_xau_not_xng`
3. `tools/strategy_farm/tests/test_execution_contract_lint.py::test_dxz23_registry_is_source_bound_and_structurally_clean`
4. `tools/strategy_farm/tests/test_execution_contract_lint.py::test_density_execution_contracts_are_source_and_runtime_binding_clean`
5. `tools/strategy_farm/tests/test_execution_contract_lint.py::test_20009_ftmo_news_calendar_is_exact_and_evidence_bound`

Additional focused results:

- dashboard/status portability lane: 36 passed before the additional negative cases;
- final status/renderer fixture lane: 39 passed;
- status plus P19 filesystem-portability lane: 28 passed;
- restored scanner implementation/test: 8 passed;
- Python compilation of the status helper and restored scanner module: exit 0;
- commit diff check for `aa67ab846...`: clean.

One intermediate Canonical full run exposed four source-free empty EA skeleton directories;
the test was corrected to consider only directories containing an MQ5 source while still
failing on any extra source-bearing identity. A second intermediate run exposed only four
deterministic fixture-clock failures after the honest `as_of_utc` advance. The fixture clocks
were advanced instead of backdating the production claim. Both causes are closed in the
single final Green result above.

## Durable dashboard publication

Both existing ALWAYS_ON tasks continue unchanged and execute Canonical source:

- `QM_StrategyFarm_Cockpit_2min` executes
  `C:\QM\repo\tools\strategy_farm\render_cockpit.py`;
- `QM_StrategyFarm_Dashboard_Hourly` executes
  `C:\QM\repo\tools\strategy_farm\dashboards\render_dashboards.py` with working directory
  `C:\QM\repo`.

No task was started, stopped, enabled, disabled, registered or rewritten during integration.

After commit `aa67ab846...`, both requested outputs were explicitly published from Canonical
at 2026-07-29T17:39Z. Productive database SHA-256 before and after both commands was exactly
`2b05cf0632a8c9f9f022779746a75c7493f23844f645ee5df1cc873709366769`.

Immediate committed-source outputs:

- `D:\QM\strategy_farm\dashboards\strategies.html`: 1,160,868 bytes,
  SHA-256 `1a0f79b53d6de7a31a5d769d3b34ad52bc7a1b4b9710734bc077bbcc249f6fe9`,
  mtime 2026-07-29T17:39:20.5938589Z;
- `D:\QM\strategy_farm\dashboards\cockpit.html`: 62,399 bytes,
  SHA-256 `911c0cb4655716887323c51b579b3bd2c226e8017bd2598e14d04087cab4efd3`,
  mtime 2026-07-29T17:39:44.7962358Z.

Both contained the fresh hash-bound programme, W0-W8, the Q08-v3 five-state contract,
Darwinex Zero and FTMO lanes, `3010 passed`, the exact five external residuals and all six
OWNER blockers. Neither page grants runtime, Factory, Scheduler, MT5, deployment, purchase,
money or AutoTrading authority.

Natural persistence observations, without manually starting a task:

- Cockpit run at 2026-07-29T19:41:41+02:00: result 0; output mtime
  2026-07-29T17:41:25.6327516Z; SHA-256
  `3c2c1c516039478b3a544fb49ae09318e5c76cf3f6d881db6510144ca0086416`;
  `PROGRAM SOURCE FRESH`, `3010 passed`, `DXZ_BETTER_BOOK_V1` and
  `FTMO_2S_100K_SWING_V1` remained present; database SHA-256 remained unchanged.
- Hourly run at 2026-07-29T20:00:00+02:00: result 0 and state `Ready` after
  completion; `strategies.html` was autonomously rewritten to 1,160,868 bytes at
  2026-07-29T18:00:10.7842493Z with SHA-256
  `288656bb526bab79e77879016711fb82f380ca35ee9fe05a5fe90dee0c5d90db`;
  `FRESH`, `3010 passed`, DXZ and FTMO markers remained present. Database SHA-256
  and mtime remained exactly unchanged. The next scheduled run is
  2026-07-29T21:00:00+02:00.

The pre-integration Hourly task at 19:00+02:00 still used the old Canonical renderer and
changed the database from
`28c3eac195c2aeb778f2d677679990949f124f05407d8f9116f7ed30be8f6cc5` to
`2b05cf0632a8c9f9f022779746a75c7493f23844f645ee5df1cc873709366769` at
2026-07-29T17:01:03.4801854Z. That autonomous pre-integration drift is historical evidence.
The integrated renderer now suppresses its `ea_metrics` writer while Factory OFF is present
or cannot be read safely; all other database access in both renderers is read-only.

## Safety closeout

Final read-only safety census at 2026-07-29T18:01:32Z, after both natural persistence
observations:

- `FACTORY_OFF.flag`: present, 66 bytes, SHA-256
  `09cc4f83e8d5f384f03bc51306beff2cdd165108559a00dbf665097c60b47f1c`;
- `FACTORY_MUTATION.lock`: absent;
- 30/30 versioned managed OFF tasks: disabled;
- 5/5 `ENFORCE_DISABLED` hazards: disabled;
- `QM_StrategyFarm_UnreadableLinks_Friday`: still disabled; no OWNER-policy assumption made;
- strict Factory worker/phase/smoke/MT5 process matches: 0;
- T_Live: one process, PID 5220,
  `C:\QM\mt5\T_Live\MT5_Base\terminal64.exe`, started
  2026-07-29T07:25:43.1696410Z;
- productive database: 350,314,496 bytes, SHA-256
  `2b05cf0632a8c9f9f022779746a75c7493f23844f645ee5df1cc873709366769`,
  mtime 2026-07-29T17:01:03.4801854Z.

Factory was intentionally left OFF. T_Live, AutoTrading, terminals, Scheduler configuration,
deployment, presets, live books, FTMO purchase/money state and productive DB contents were not
mutated by this integration. Dashboard publication is not runtime or trading authorization.
