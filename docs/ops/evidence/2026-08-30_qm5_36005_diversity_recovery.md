# QM5_36005 FX-diversity recovery

Date: 2026-08-30
Branch: `agents/board-advisor`
EA: `QM5_36005_nnfx-coral-trendlord-woodies-harvester`
Review-repair task: `ddb87b6b-a6db-4f8d-be8f-337341238a8c`
Build task: `85404c3e-51d0-4a7e-85f3-f4658bc1dea9`
Compile work item: `59333bce-ff98-4059-9e34-56d306932f90`

## Why this EA

The approved card is a low-frequency D1 forex sleeve with active allocations
for `GBPJPY.DWX`, `EURJPY.DWX`, and `AUDNZD.DWX` and an expected 25 trades per
year per symbol. It therefore adds more instrument diversity than another
index, metal, XNG, or WTI build. The card retains `g0_status: APPROVED`, all
R1-R4 gates are PASS, and the mechanism is structural/non-ML.

The EA source had already passed the scoped static rework. Review task
`ddb87b6b` recycled only the artifact package: the three fixed-risk presets
declared source SHA-256 `f1869369...`, while the canonical committed `.mq5`
blob is `d4111544f3b6184d89fbdc3303694e38d8dcaddad19c1032f6703119ac89fe8c`.
The Windows working-copy bytes are CRLF-normalized and hash to
`12f7871acb352c23f79e6fe3a8268c816929898d340f56247031582279b911e9`;
that transient hash is retained only as the compile work item's execution
binding and is not used as durable Git provenance.

## Repair

- Rebound all three backtest preset headers to the canonical committed source
  blob SHA-256. Their executable parameters are unchanged and remain
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, with registered slots 0/1/2.
- Added an exact one-task/one-label append-only compile authority for review
  task `ddb87b6b`. It waives only the existing bound-setfile guard for this EA;
  it grants no backtest, gate-verdict, registry, or live authority.
- Tightened the EA regression so every preset must equal
  `canonical_blob_sha256()` for the committed `.mq5`, preventing recurrence of
  the CRLF/working-copy hash defect.
- Created the standard `codex_build_ea` task and enqueued the source-hash-bound
  governed compile item for all three symbols. Candidate classification was
  `ELIGIBLE`; its only waived reason was `BOUND_SETFILE_HASH_EXISTS`.

## Validation and stop boundary

`python -m pytest tools/strategy_farm/tests/test_compile_work_items.py tools/strategy_farm/tests/test_qm5_36005_review_rework_static.py -q`
passed (`51 passed in 60.41s`). The compile rollout dry-run found exactly one
source-fresh item and no deferred item.

Immediately before release, a three-sample host reading reported 90.6% average
CPU (31.1 GiB free of 63.1 GiB). This met the paced-fleet backtest CPU ceiling,
so the compile hold was deliberately **not** released. The work item remains
`pending`, unclaimed, under active hold
`COMPILE_EA_WORKER_ROLLOUT_PENDING`. No smoke or Q02 backtest was started, and
no Q02 row is claimed by this evidence.

After CPU headroom returns, continuation is the exact held item through
`release_compile_wave.py --work-item-id 59333bce-ff98-4059-9e34-56d306932f90`
(inspect first, then the governed bounded apply). On `COMPILE_OK`, record the
build result through `farmctl record-build`; that standard transition will
enqueue the diverse Q02 canary. Do not create a second build or compile row.

## 2026-08-31 paced continuation

The paced fleet claimed the existing build task rather than creating a
duplicate. The claim was CAS-guarded against build task `85404c3e`, review task
`ddb87b6b`, compile item `59333bce`, and any other active `QM5_36005` build.
The pre-mutation database backup is
`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_36005_paced_claim_20260831T094202Z.sqlite`.

The exact compile release dry-run again proved the source binding:

- expected and actual working-copy SHA-256:
  `12f7871acb352c23f79e6fe3a8268c816929898d340f56247031582279b911e9`;
- `8 passed` in the scoped card/registry/corset regression;
- `validate_spec_doc.py` returned `PASS`;
- one releasable item, zero deferred items.

At `2026-08-31T09:42:47Z`, `release_compile_wave.py` removed the activation
hold for exact item `59333bce-ff98-4059-9e34-56d306932f90`. Its automatic DB
backup is
`D:/QM/strategy_farm/state/backups/farm_state_before_compile_wave_20260831T094243Z_42641ffe.sqlite`
(SHA-256 `fb0e0ee82713a498ba1d80b9b8150004ca8e23c40fab0a1f00726d48b886254c`).
The release receipt is
`D:/QM/reports/work_items/59333bce-ff98-4059-9e34-56d306932f90/compile_release.json`.

The post-release census then showed **9 active work items**, above the farm's
defined 7-row tester-drain saturation threshold. The mission's CPU-ceiling
stop rule therefore fired: no manual compile, smoke, Q02 enqueue, terminal
reservation, or backtest was launched.

The resident worker had already claimed the released utility row on T5 at
`2026-08-31T09:43:45Z` and completed it at `09:44:31Z`. The durable receipt is
`D:/QM/reports/work_items/59333bce-ff98-4059-9e34-56d306932f90/QM5_36005/COMPILE_EA/compile_evidence.json`:

- work-item verdict `COMPILE_OK`;
- strict build check `PASS`, zero failures and one non-blocking event-vocabulary
  warning for `STRATEGY_TOTAL_DD_HALT`;
- compile `PASS`, zero compiler errors and zero compiler warnings;
- EX5 SHA-256
  `e11e8103deacb817642e1de7013b6c153569011d4751dba4c03c9e3d10dad258`;
- three active magic rows and three fixed-risk backtest presets.

The worker's transient setfile regeneration was not retained because it
replaced the reviewed canonical source-blob binding with three different
per-file values. The committed presets remain byte-identical to the reviewed
inputs, and the scoped regression still requires all three headers to bind
`d4111544f3b6184d89fbdc3303694e38d8dcaddad19c1032f6703119ac89fe8c`.

The compile is complete, but Q02 remains deliberately **not enqueued** at the
CPU ceiling. The sole continuation is the standard build-result/Q02 handoff
after tester headroom returns. Do not create a second compile or build row.

## Scope assurance

No EA strategy mechanics, registry allocation, portfolio gate, T_Live file,
T_Live manifest, terminal process, factory state, or AutoTrading setting was
changed.
