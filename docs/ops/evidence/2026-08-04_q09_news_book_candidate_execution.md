# Q09_NEWS v2 book-candidate execution — 2026-08-04

## Decision

Execution record for router task `82bd766f-a520-46e7-b069-7636d901b401`.
The OWNER-ordered sequence is strictly serial:

1. `QM5_11422 / USDCAD.DWX`;
2. only after that chain closes, `QM5_13036 / GDAXI.DWX`.

Each chain is fail-closed: a Q09_NEWS refusal or any verdict other than
`CONFIG_LOCKED` stops that candidate; Q10 requires both `CONFIG_LOCKED` and a
fresh same-Q08 `PASS_PORTFOLIO` row. All tester setfiles use
`RISK_FIXED=1000` and `RISK_PERCENT=0`. No T_Live, AutoTrading, or manual
`terminal64.exe` action is part of this execution.

**Outcome: FAIL CLOSED before cell execution.** The ordinary factory worker
constructed a Q09 executor command without the executor's required `--period`
argument. `argparse` refused the command. No cell, Q09 aggregate, adjudication
sidecar, Q09_PORTFOLIO row, Q10 row, or second-candidate row was produced. No
pipeline verdict is claimed.

## Sealed shared input

| Input | Identity |
|---|---|
| Calendar bundle | `q09cal-20150101-20260809-0bb19b5bb9790b76` |
| Manifest | `D:/QM/data/news_calendar/q09_bundles/q09cal-20150101-20260809-0bb19b5bb9790b76/manifest.json` |
| Manifest SHA-256 | `b204d1ab9fe40fe32afc254ae4284ed6c1df112829df07483912e5ed54527461` |
| Event content SHA-256 | `86b2c0b595fd6011a2fe64b7da07f933e755294136a16f584d75389b66c56ce1` |
| Coverage | `2015-01-01T00:00:00Z` through `2026-08-09T02:00:00Z`; 48,245 events |
| Experiment window | full `2019-01-01..2025-12-31`; selection `2019-01-01..2023-12-31`; sealed holdout `2024-01-01..2025-12-31` |
| Window contract | `complete_months=60`; `holdout_complete_months=24` |
| Tester / cost profile | `REAL_TICKS` / `DXZ_CANONICAL_REAL_TICKS_V1` |

## Candidate input identities

| Identity | QM5_11422 / USDCAD.DWX | QM5_13036 / GDAXI.DWX |
|---|---|---|
| Fresh Q08 PASS row | `9fe3eb5f-ab0d-4c84-82fe-d6748c3aa270` | `fb3f0e20-1982-4f51-9e4b-52da2629a5ac` |
| Q08 aggregate SHA-256 | `c611ae3b628dc74b8ae38aa6a6420367290e9cd2fd43e201a20d9f467e2f58f4` | `1f829f2bb451c19349e0055cefa66472862a6f1850f0e01ec4632d650342b966` |
| Historical Q09_NEWS row retained | `87af2578-b9ba-4010-9776-07faa4e729d5` (`PENDING_RUNNER`) | `7efd8e39-4d1c-4b6d-8cfd-637122aad25f` (`PENDING_RUNNER`) |
| Baseline setfile SHA-256 | `715bce2fb8762cef12dcdff86eb6c144069b6d5a487d5e39fcaa1de71248a5ff` | `80dc96e896fa109ef31964af8c617468e6737b1f0823f1616d1117b44c732b70` |
| EX5 SHA-256 | `2b98e9e902313148be78d88513fcbda2476150b1a7605eb15a50b2cca6b32d66` | `2cd0f7270572d37bd67ca0d1f724eaad95d756b4af18859d2dd0203d0045b0be` |
| Include-closure SHA-256 | `a3fbf052f006b46cf0759ed47a7af2945819c8769d5f58de1b30d250506b9172` | `6ed8946b36a0e03028577a9ab4d4140765592f8d9e060bed1e1e49100c98daa2` |

## Governed execution ledger

### QM5_11422 / USDCAD.DWX

- New append-only Q09_NEWS row: `33df999d-aa4f-4e66-9c2f-44bdcd3e7852`.
- Run-plan logical SHA-256: `92554c45451ba940b0097defd3014053d3ad1bb2b4e71da3714b40a76ba1f129`.
- Exact run-plan file SHA-256: `32cda8fe8ee21d0a333a7d661b78802503a60579e9fa9d93b074f3d5b6b2fb47`.
- Input-manifest SHA-256: `497ed2ec0f538b32c3143aedec50eeff913db945087d00c19d1092b559ca51a8`.
- Dispatch-binding SHA-256: `a54e6bbbafae91b87f99b85b0186760e31f6d9e4ecd490e44c2c98c28014b2be`.
- Matrix: 40 cells, `7x1_target_compliance`, target compliance `DXZ`.
- Activation hold: released by `bind-q09-plan`; state `RUNNABLE_BOUND`.
- At activation, an older governed USDCAD Q02 row
  `f83e63c3-60f8-4807-9dac-c4bdb5e1a0aa` was active. Symbol serialization
  correctly kept Q09 pending; it was not interrupted.
- After that symbol lock released, the ordinary factory claimed the row on T3
  at `2026-08-04T05:37:49Z` and spawned the Q09 phase runner at
  `2026-08-04T05:38:00Z`.
- The spawned command omitted `--period D1`. The runner refused with:
  `q09_news_runner.py execute: error: the following arguments are required: --period`.
- The generic launch-fault guard correctly returned the row to `pending` with
  `verdict=NULL`, `launch_fault_count=1`, and
  `launch_not_before_utc=2026-08-04T05:43:15Z`; it did not invent an economic
  or pipeline verdict.
- Source mechanism in `tools/strategy_farm/farmctl.py`: the Q09 builder adds
  `--period` at line 5929, then the generic Q-phase bridge removes it at line
  5964. This is incompatible with the Q09 executor parser, which requires the
  argument.
- Mutable worker log SHA-256 at the fail-closed capture (`05:38:15Z`):
  `bddaf889f22f89f800a46c077a112b69a00c102ee5471d71b23e54c2ba72d585`.
- The generic retry policy claimed the same row again at `05:43:15Z`. The
  ordinary worker spawned the same malformed command at `05:43:26Z`, received
  the same `--period` refusal, and returned the row to `pending` at
  `05:43:37Z` with `launch_fault_count=2` and
  `launch_not_before_utc=2026-08-04T05:53:37Z`. Worker-log SHA-256 at cycle
  close: `fe4c0c0265d99c52b3020ccd288df44c7634ebac79c89946aef88bd4e8792d08`.
- Result inventory at capture: zero `cell_receipt.json` files; Q09 output root
  absent; zero `q09_news_tests` rows for this work item; no aggregate or
  evidence path.
- Fresh Q09_PORTFOLIO row: **not created**.
- Q10 append-only rerun of `6f9400fa-9ca2-4835-9fcf-e1087289f9b1`:
  **not created**.

### QM5_13036 / GDAXI.DWX

This candidate was not started because the preceding candidate hit the
explicit machinery-refusal stop condition. No append-only Q09_NEWS row, fresh
Q09_PORTFOLIO row, or Q10 rerun of
`788d2371-4a37-42c3-b9b1-18d9fb09bd3f` was created.

## Verification

- Preflight authenticated both Q08 aggregates, baseline setfiles, current EX5
  binaries, recursive include-closure manifests, and the OWNER-approved calendar
  manifest.
- Representative CONTROL_OFF and POLICY_ON plan setfiles preserved
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the sealed bundle/content identity.
- Focused Q09/Q10 suite: `31 passed`:
  `test_q09_news_runner_v2.py`, `test_q09_news_contract_v2.py`,
  `test_q09_news_farmctl_integration.py`, and
  `test_q10_confirmation_contract_v2.py`.
- The focused suite did not cover the production command-composition
  interaction that removes Q09's required `--period`; the real ordinary-worker
  invocation exposed that missing integration case.

## Required follow-up at first-pass close

The first pass closed with this required follow-up: repair the factory
command-composition contract so Q09_NEWS retains its sealed
period, add a production-command regression test, then create a separately
authorized append-only rerun. Do not manually invoke `execute`, rewrite this
pending row, weaken the gate, or create downstream rows from the refusal.

## Recycle repair and governed resume — 2026-08-04 06:14Z

Router task `82bd766f-a520-46e7-b069-7636d901b401` was recycled with an
explicit repair-and-resume delta. Commit `e21136822` (`Fix Q09 sealed period
dispatch`) implements both required layers:

1. `q09_news_runner.py execute` now derives its tester period from the
   authenticated Q08 `baseline_run.period` inside the sealed Q09 input
   manifest. The executor re-authenticates the baseline setfile and EX5
   identities, accepts an optional explicit `--period`, and fails closed if
   that value contradicts the sealed period.
2. The `farmctl.py` Q-phase bridge no longer strips `--period` from
   `Q09_NEWS`. This is the clean command contract for the next worker load;
   other Q runners retain the existing strip behavior.

This ordering makes the executor-side layer effective immediately because the
Q09 executor is a fresh process on every claim. No resident terminal worker
was restarted, and no Factory OFF/ON action was taken.

### Focused verification

- Python syntax compilation: PASS for the two implementation files and two
  changed test files.
- Q09 runner/contract/farmctl plus Q10 confirmation suite: `32 passed in
  13.07s`.
- The production regression test builds the command through
  `farmctl._phase_runner_cmd_for_work_item`, proves Q09 retains the detected
  period, and parses the resulting real executor argument vector with the
  executor parser.
- Executor tests prove omitted-period derivation and refusal of an explicit
  period that contradicts the hash-bound Q08 baseline.
- `git diff --check` on the scoped implementation and test paths: PASS.

### Ordinary-worker runtime proof

The same pending row `33df999d-aa4f-4e66-9c2f-44bdcd3e7852` remained the only
Q09 row used; no replacement row was created. Its governed retry time was
`2026-08-04T06:14:20Z`.

- T3 reclaimed the row at exactly `06:14:20Z` and spawned the Q09 executor at
  `06:14:32Z` as PID `18596`.
- The resident worker's logged executor command still omitted `--period`, as
  expected from its pre-repair loaded `farmctl.py`.
- The fresh executor crossed the former argparse refusal and spawned governed
  `run_smoke.ps1` as its child with `-Period D1`, derived from the sealed Q08
  evidence, for the first CONTROL_OFF selection cell.
- At the `06:16:14Z` capture the work item remained `active`, claimed by T3,
  with `verdict=NULL`, `evidence_path=NULL`, and `launch_fault_count=3`
  unchanged. This is pipeline work in progress, not a pipeline verdict.

No cell receipt or aggregate existed at capture, so the serial chain correctly
remains open. No Q09_PORTFOLIO row, Q10 rerun, or QM5_13036 Q09 row has been
created. Those steps remain gated on a genuine `CONFIG_LOCKED` result and then
a fresh same-lineage `PASS_PORTFOLIO`; nothing in this repair reinterprets or
predicts either verdict.

## Recycle round 2 — logger reset diagnosis and receipt repair

The resumed row terminalized at `2026-08-04T06:18:59Z` as
`done/REVIEW_REQUIRED`. Its aggregate is
`D:/QM/reports/work_items/33df999d-aa4f-4e66-9c2f-44bdcd3e7852/QM5_11422/Q09_NEWS/USDCAD_DWX/aggregate.json`,
SHA-256 `1d742e7407f8d83b1f926c714b18c439e5319594b1a9d0478fcc29b31ca91437`.
It truthfully reported `partial_cell_execution`, zero authenticated cells, and
40 missing cells. The executor failure artifact has SHA-256
`045ca86a4dd15eba0f1f0e5944f513cbc019011acc0247ce6fe0fb07b24cfc49`
and says `run_smoke logger sample authentication failed`.

### Exact T3 mechanism

This was not a 4.5-minute matrix budget or a silent child exit. The first
CONTROL_OFF seed-42 selection tester completed `PASS` and captured an exact
918,574-byte structured logger from source offset zero. The immediately
following holdout tester also completed `PASS`, but its `run_smoke.log`
records:

```text
WARNING: Structured logger capture skipped: a pre-run logger file was truncated:
'D:\QM\mt5\T3\Tester\Agent-127.0.0.1-3001\MQL5\Files\QM\QM5_11422_ea-11422.log'.
```

The tester agent recreates the EA's FILE-sandbox logger between independent
tester processes. `run_smoke.ps1` had snapshotted the 918,574-byte selection
file before the holdout launch, then observed the shorter newly-created
holdout file. `Save-QmLoggerDelta` correctly refused to treat a rewritten file
as an append-only delta. Consequently the holdout summary carried
`logger_sample_path=null`; `_validate_window_summary` refused it before the
cell could write `cell_receipt.json`; and the partial collector could only see
40 absent receipts. The child failure was present in `execution_failure.json`,
but not represented as a row-bound failed cell.

### Additive fail-closed repair

Commit `744d6111f` (`Fix Q09 multi-window receipt execution`) adds two narrow
contracts while leaving default smoke behavior unchanged:

1. Q09 production dispatch passes `-RequireFreshLoggerSample`. Before each
   child launch, `run_smoke.ps1` proves metatester-writer quiescence, hashes and
   moves every matching prior EA logger into that run's
   `pre_run_logger_archive`, verifies the original paths are empty, and then
   requires an exact fresh logger sample. The archive manifest and its hash
   are embedded in `run_smoke/v2`. Isolation or capture uncertainty throws;
   it cannot silently publish a Q09-usable summary.
2. An executor exception writes immutable `q09-news-cell-failure/v1` evidence
   beside the intended receipt. It binds work item, run identity, paired base,
   arm/config/seed, explicit error, and hashes of every artifact available at
   failure. `collect_run_plan_status` authenticates this sidecar and emits
   `cell_execution_failed` with a failed-cell count. A genuine first-cell
   failure is therefore `1 failed + 39 unattempted`, not `0/40 missing`.

Relevant implementation anchors are
`framework/scripts/run_smoke.ps1:41,1224,2456-2560` and
`tools/strategy_farm/q09_news_runner.py:38,800-894,1018,1545` at this commit.
No stale-news threshold, tester model, verdict threshold, EA source, EX5,
setfile risk value, T_Live setting, or AutoTrading state changed.

### Focused verification

- Python syntax compilation: PASS.
- `Test-RunSmokeLoggerSample.ps1`: PASS, including the exact shorter-file
  selection-to-holdout reset case.
- Q09 runner unit suite: 12/12 PASS. The new production-path regression runs
  all 40 cells x 3 windows through the real dispatcher command shape, writes
  receipts, and reaches fixture `CONFIG_LOCKED`; every one of the 120 child
  commands carries `-RequireFreshLoggerSample`.
- Q09 runner/contract/farmctl plus Q10 suite: `34 passed in 15.95s`.
- Failure regression proves an injected tester exception produces one
  authenticated failed-cell sidecar plus 39 genuinely unattempted cells.
- `git diff --check` on all four implementation/test paths: PASS.

## New append-only governed resume

The terminal `33df999d-aa4f-4e66-9c2f-44bdcd3e7852` row was preserved. A new
same-Q08 append-only Q09_NEWS row was created:

| Identity | Value |
|---|---|
| New work item | `fd88398c-7288-4f6d-b3b0-4847487e35a8` |
| Rerun of | `33df999d-aa4f-4e66-9c2f-44bdcd3e7852` |
| Q08 predecessor | `9fe3eb5f-ab0d-4c84-82fe-d6748c3aa270` |
| Candidate lineage key | `c963164be8b0677f76ec6cc812f40b0f7f5a9149eb493c31735a85a38c298a7b` |
| Logical plan SHA-256 | `e5d7e271936467bb69f293c1c0c3b044149b8f6d24dd96de01455b08d6f61ede` |
| Exact plan-file SHA-256 | `e8fefa85befbe0ffbb0cd9b1215287bf32b5170b37bc93e6f7ab861f9872a7ea` |
| Input-manifest SHA-256 | `cfa8750a8f865ad09e93f3be0dca5e525b93b37895c082d38208ebbf9ad1af37` |
| Dispatch-binding SHA-256 | `b02bc9a698438a59d2f6271b093869a6b06748e31c9438c9bbebd7abb2c56950` |

All 40 regenerated setfiles retain `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`qm_news_stale_max_hours<=336`. Their ordered run identities and setfile
SHA-256 values exactly equal the previous experiment. `bind-q09-plan`
authenticated the exact plan hash and released the activation hold as
`RUNNABLE_BOUND`.

### Production proof on T8

The ordinary factory claimed the row on T8 at `2026-08-04T06:51:40Z`; no
manual terminal start occurred. The command contains the sealed D1 period and
`-RequireFreshLoggerSample`. The first CONTROL_OFF seed-42 cell completed all
three windows and published the first real receipt:

| Artifact | Evidence |
|---|---|
| Cell run identity | `97832746b7c45318588ea7ee41e4a43303e951c796164b8a6b50f0e5deb4ac16` |
| Cell receipt SHA-256 | `1e0639073d8bc18b11f374c60071e8b67aa270e949ec70d3dc45c532d3f234c3` |
| Selection summary | `PASS`; logger 918,574 bytes; fresh offset 0; SHA-256 `7ab6ccfd5cec2468bdef61ad1c0a84cd2923ceab7095fcb16b2259a3d4f8af23` |
| Holdout summary | `PASS`; archived the 918,574-byte selection logger; fresh logger 348,712 bytes from offset 0; SHA-256 `fa852778e62cc462f1b83645879bc5f7bc6a2bfc470044ad7c843559dc4e386e` |
| Full summary | `PASS`; fresh offset 0; logger SHA-256 `9ae72e68290753a9e20c119f0f7412a9685699282c6d8e42ddd8f9a8f748941a` |

The receipt's report-manifest and cell-evidence hashes verify, and its metrics
equal the hash-bound evidence metrics. This is production proof that the exact
selection-to-holdout truncation mechanism is repaired and that the complete
execute-to-receipt path works. At cycle close the row remains `active` on T8,
has advanced to the next cell, carries no pipeline verdict, and has no
cell-failure sidecar.

The matrix is deliberately serial and the first cell took about nine minutes;
40 cells are therefore a multi-hour ordinary-factory operation. No aggregate,
Q09 sidecar, Q09_PORTFOLIO successor, Q10 rerun, or QM5_13036 Q09 row is
claimed or created in this cycle. The chain remains fail-closed until this row
produces a genuine `CONFIG_LOCKED`; then a fresh same-Q08 `PASS_PORTFOLIO` is
still required before Q10. The historical verdicts are not reinterpreted.

## Round 4 append-only governed resume — 2026-08-04 12:57Z

Router task `177ac748-059e-4d74-bea4-afdc9b440c70` authorized a new
append-only attempt after the OWNER factory-reload window. The round-3 row
`fd88398c-7288-4f6d-b3b0-4847487e35a8` remains terminal
`done/REVIEW_REQUIRED`; it was not rewritten or retried in place.

| Identity | Value |
|---|---|
| New Q09_NEWS work item | `6a305d8a-81ef-49a3-94bb-2fd1aaeb822e` |
| Append-only rerun of | `fd88398c-7288-4f6d-b3b0-4847487e35a8` |
| Exact Q08 predecessor | `9fe3eb5f-ab0d-4c84-82fe-d6748c3aa270` |
| Candidate-lineage key | `c963164be8b0677f76ec6cc812f40b0f7f5a9149eb493c31735a85a38c298a7b` |
| Logical plan SHA-256 | `7f6853822f81f7657ea9738c5b250c181e794e30282c2ba3ff7f2ec53311ddc5` |
| Exact plan-file SHA-256 | `319727ee2fc9107467d33e7a8658414e7ee4a10ef6e5efca6a810c2d28e0edb3` |
| Input-manifest SHA-256 | `9be7e12377ecddc7a0255a47c5d93c8ff843aa99c2dd49377daa80ab39d7b326` |
| Dispatch-binding SHA-256 | `98ccf9ae73e5d2e317555d0834a52fcfafcb4cd99a09ac79c3aa9549b61472e9` |

### Preflight and plan verification

- The Q08 aggregate, baseline setfile, current EX5, recursive include closure,
  and OWNER-approved calendar manifest still match the sealed SHA-256 values
  recorded above: `c611ae3b...`, `715bce2f...`, `2b98e9e9...`,
  `a3fbf052...`, and `b204d1ab...`, respectively.
- The new plan contains 40 cells and retains the exact ordered tuple of
  `(run identity, setfile SHA-256, arm, compliance mode, temporal mode, seed)`
  from round 3. The work-item-specific plan and manifest hashes change because
  their paths and row binding are new; the experiment identities do not.
- All 40 generated setfiles have `RISK_FIXED>0`, `RISK_PERCENT=0`, and no
  `qm_news_stale_max_hours` value above 336. The input manifest retains
  `REAL_TICKS`, `DXZ_CANONICAL_REAL_TICKS_V1`, the same full/selection/holdout
  windows, and the same content-addressed calendar bundle.
- `bind-q09-plan` authenticated the exact plan-file hash, wrote the dispatch
  binding, and released the activation hold as `RUNNABLE_BOUND` with a
  3,600-second per-cell timeout.

### Ordinary-worker activation and fail-closed handoff

T3 claimed the row at `2026-08-04T12:53:17Z`. Its row-bound log proves that
the ordinary worker, not a manual terminal launch, spawned
`q09_news_runner.py execute` with the exact plan hash, `--period D1`, the
reserved `T3` slot, and the canonical output root. At the `12:57:13Z` capture,
the executor was running the first CONTROL_OFF seed-42 cell and its holdout
child carried `-RequireFreshLoggerSample`; there were zero failure sidecars,
zero published receipts, and no aggregate yet.

This is active pipeline execution, not a verdict. Therefore no fresh
Q09_PORTFOLIO row, Q10 rerun, or QM5_13036 Q09_NEWS row was created in this
single scheduler pass. The continuation contract remains unchanged:

1. only a genuine round-4 `CONFIG_LOCKED` may open a fresh same-Q08
   Q09_PORTFOLIO row;
2. only a genuine `PASS_PORTFOLIO` may open the append-only Q10 rerun;
3. only after the QM5_11422 chain closes may QM5_13036 begin; and
4. any refusal, non-good verdict, or genuine `REVIEW_REQUIRED` stops the chain
   for review rather than creating a retry loop.

## Round 5 restart-idempotence repair and governed activation — 2026-08-04 20:14Z

Router task `a652b078-1bdd-43ff-a4c9-feaa76e06f7f` authorized the persistence
repair and a new append-only round. The round-4 row
`6a305d8a-81ef-49a3-94bb-2fd1aaeb822e` remains terminal
`failed/INFRA_FAIL`; its 40 immutable receipts and failed-row history were not
rewritten.

### Restart-idempotent persistence repair

Canonical-checkout commit `c8ee2dabe` (`Fix Q09 restart-idempotent
persistence`) changes the final Q09 sidecar transaction as follows:

- an existing `q09_news_tests` summary is accepted only after every immutable
  content field matches the newly authenticated result;
- each existing global cell `run_identity_sha256` is compared across all
  stored authenticated and verdict-relevant fields, including setfile,
  evidence, report, window metrics, seed stability, and flat-at-event receipt
  identities;
- an identical row is an explicit no-op, allowing persistence to resume;
- any contradiction raises a structured fail-closed error containing the row
  kind, exact identity, and divergent field names; there is no overwrite,
  `INSERT OR REPLACE`, or mutable reconciliation path; and
- locked-arm rows receive the same exact-match/no-op treatment. The runner no
  longer returns early after checking only verdict and aggregate SHA-256.

Focused verification passed 30 tests: five schema tests, the existing fresh
40-cell persistence test, two new restart/divergence regressions, eight Q09
contract tests, ten farm-control integration tests, and four Q10 dependency
tests. Python syntax compilation and scoped `git diff --check` also passed.
The new regressions prove both matching partial-state completion and a
divergent cell refusal whose error names the exact run identity and
`evidence_sha256` field.

### Round-5 append-only row and sealed plan

The Q08 aggregate, baseline setfile, current EX5, recursive include closure,
and calendar manifest re-authenticated at the same recorded SHA-256 values:
`c611ae3b...`, `715bce2f...`, `2b98e9e9...`, `a3fbf052...`, and
`b204d1ab...`. No Q09_NEWS row for this candidate was pending or active before
the enqueue.

| Identity | Value |
|---|---|
| New Q09_NEWS work item | `3c1fea0e-3a81-40fb-809a-a9b19156887e` |
| Append-only rerun of | `6a305d8a-81ef-49a3-94bb-2fd1aaeb822e` |
| Exact Q08 predecessor | `9fe3eb5f-ab0d-4c84-82fe-d6748c3aa270` |
| Candidate-lineage key | `c963164be8b0677f76ec6cc812f40b0f7f5a9149eb493c31735a85a38c298a7b` |
| Logical plan SHA-256 | `58edeec64aa7f5d41a97b1f273d6607ddfc6b09a6f55afd0133327991960d642` |
| Exact plan-file SHA-256 | `6ff5dfc14257fd688dc09b4144821c8fbf8db59f09a20de29777b584cb9afa3f` |
| Input-manifest SHA-256 | `6b4eaa4aa6ccf58ffbceb904a0a57fc0709102123b537acce26c4baa14bf1d93` |
| Dispatch-binding SHA-256 | `c73c8b9847acc0bda1650feba41f206d77837214a7976dbf371055b260b62fdc` |

The new plan has 40 cells. Its ordered tuples of run identity, setfile
SHA-256, arm, compliance mode, temporal mode, and seed exactly match round 4.
All 40 setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`; none sets
`qm_news_stale_max_hours` above 336. `bind-q09-plan` authenticated the exact
file hash and released the activation hold as `RUNNABLE_BOUND` with a
3,600-second per-cell timeout.

### Ordinary-worker handoff

T1 claimed the row through the ordinary factory at
`2026-08-04T20:14:32Z` and spawned PID `21792`. The row-bound command uses the
exact plan-file hash, sealed `--period D1`, canonical Q09 output root, and the
fresh-process executor at `C:/QM/repo/tools/strategy_farm/q09_news_runner.py`.
No terminal was started manually and no active T1-T10 job was interrupted.

At the cycle capture the row is `active` on T1 with `verdict=NULL` and
`evidence_path=NULL`. It has zero published cell receipts, zero cell-failure
sidecars, and no `q09_news_tests` summary. This is active pipeline execution,
not a pipeline verdict. Therefore no fresh Q09_PORTFOLIO row, Q10 append-only
rerun, or QM5_13036/GDAXI.DWX row was created. Those actions remain strictly
gated on a genuine `CONFIG_LOCKED`, then a fresh same-Q08 `PASS_PORTFOLIO`,
and the serial-chain stop rules stated above.

### Round-5 terminal stop captured at cycle exit

After the active handoff capture, the first CONTROL_OFF seed-42 selection run
completed and published authenticated artifacts, but the immediately following
holdout child refused at `run_smoke.ps1:2258`:

```text
Terminal instance is already running for D:\QM\mt5\T1. Stop it first or pass -AllowRunningTerminal.
```

Neither prohibited response was taken: the running terminal was not stopped,
and `-AllowRunningTerminal` was not added. The executor wrote immutable
`q09-news-cell-failure/v1` evidence for run identity
`97832746b7c45318588ea7ee41e4a43303e951c796164b8a6b50f0e5deb4ac16`,
binding ten available artifacts. The cell-failure SHA-256 is
`9f02e7c4f6ad94e3b85124df2cc5d3313ab5365fde043755fdf19294df698a2d`.

The row terminalized at `2026-08-04T20:19:01Z` as
`done/REVIEW_REQUIRED`, reason `cell_execution_failed`: zero authenticated
cells, one failed cell, and 39 unattempted cells. The immutable result
identities are:

| Artifact | SHA-256 |
|---|---|
| Aggregate | `b640d8d1fc281a99c26af4ab788fc00867e59d61b81dede605d70df4bff4a6eb` |
| Q09 evidence | `b63fcab431d6be508a6043c815b5b9d440d45db6c019fe470133db4ef638bcb4` |
| Execution failure | `60562a8b8403b12fe3675c6f14bac0ad165104d06dc3358a131968e031e05203` |

The final Q09 summary sidecar persisted successfully as `RECORDED`; no
`q09_news_cells` row was inserted for this work item. This is a genuine
`REVIEW_REQUIRED` machinery refusal and therefore Claude review input, not a
retry authorization. The sequence stops here: no Q09_PORTFOLIO row, Q10 row,
or QM5_13036/GDAXI.DWX row was created.
