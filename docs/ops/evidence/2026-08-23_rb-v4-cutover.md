# rb-v4-cutover evidence — 2026-08-23

## Status

PASS. The activation workflow can promote and temporarily load Gate Manifest v4,
run the complete orchestrator verification list, and restore the worktree to the
board-advisor v3 default. The real runtime activation was not performed; that
remains an orchestrator action in a Factory_OFF window.

Final default anchors are intentionally unchanged:

- `tools/strategy_farm/gate_manifest.py:30` — `SCHEMA_VERSION = SCHEMA_VERSION_V3`
- `tools/strategy_farm/gate_manifest.py:48` — `DEFAULT_MANIFEST = V3_MANIFEST`
- `tools/strategy_farm/config/gate_manifest.v4.json` is absent after worktree-only
  verification.

## What changed

### Activation and open-row cutover

- `tools/strategy_farm/activate_gate_manifest_v4.py:483` adds the append-only
  `gate_contract_cutover_log` table and immutable update/delete triggers.
- `tools/strategy_farm/activate_gate_manifest_v4.py:529` derives the exact
  pending/active work-item and dependency-role rewrite plan from the manifest's
  v3-to-v4 contract-equivalence maps. Only `legacy`, `v2`, or `v3` rows with
  `status IN ('pending','active')` and no verdict qualify. Explicit v4 and all
  done/failed rows remain untouched.
- `tools/strategy_farm/activate_gate_manifest_v4.py:612` applies the rewrite in
  one transaction, checks every update count, records both work-item and
  dependency changes in the cutover log, and restores immutable triggers before
  commit.
- `tools/strategy_farm/activate_gate_manifest_v4.py:851` runs the cutover after
  the additive gate-contract/Q09 migrations and before stamping the activation
  ledger.
- `tools/strategy_farm/activate_gate_manifest_v4.py:1090` adds a standalone
  `--cutover-dry-run` which opens the selected DB read-only and lists the exact
  proposed changes.
- `tools/strategy_farm/activate_gate_manifest_v4.py:1098` adds `--apply --no-db`
  for a worktree-only promote/flip/smoke/verify cycle. Its `finally` restoration
  at line 1296 restores all touched activation anchors even after a failed test.
- `tools/strategy_farm/activate_gate_manifest_v4.py:927` contains the complete
  15-file orchestrator verification list.

### Runtime compatibility

- `tools/strategy_farm/farmctl.py:358` keeps the active NEWS parent gate
  inspection-only while its manifest-declared storage lane remains claimable.
- `tools/strategy_farm/farmctl.py:4846` overlays legacy runner semantics from
  active manifest roles, so v4 `Q10_NEWS` routes as NEWS and v4 `Q11` as the
  incumbent runner.
- `tools/strategy_farm/farmctl.py:10272` and line 18150 allow the promoted v4
  baseline full-run gate to advance only on `PASS`.
- `tools/strategy_farm/farmctl.py:15445` follows the exact
  `promoted_from_work_item` lineage through the new v4 baseline gate to retain
  the frozen Q08 NEWS input and evidence hash.
- `tools/strategy_farm/q09_news_schema.py:749` and line 761 accept the union of
  v3/v4 NEWS and PORTFOLIO dependency-role tokens in qualification checks.
- `tools/strategy_farm/rebaseline_census.py:63` selects the active contiguity
  chain, and lines 80/159 collapse manifest-declared NEWS storage lanes to their
  parent gate without ordinal guessing.
- `tools/strategy_farm/backfill_planner.py:37`, line 42, line 300, and line 516
  derive the contract stamp, NEWS phases, NEWS-hole classification, and frontier
  correction from the active manifest.
- `tools/strategy_farm/evidence_cascade_driver.py:50` derives its upper phase
  bound from the active INCUMBENT role.

### Tests

Default-sensitive tests now derive gates, storage phases, dependency roles,
terminal gates, and labels from the active manifest. Explicit historical
coverage still loads the v2/v3 manifest fixtures directly.

Cutover-specific coverage:

- `tools/strategy_farm/tests/test_activate_gate_manifest_v4.py:284` verifies
  every meaning-changing equivalence for pending/active legacy/v2/v3 rows and
  proves terminal rows are excluded.
- `tools/strategy_farm/tests/test_activate_gate_manifest_v4.py:320` verifies a
  pending Q09 NEWS row with an active hold plus a dependency edge. The cutover
  produces `Q10_NEWS`, preserves the hold and sidecar identity, rewrites the
  dependency token, leaves completed evidence unchanged, rejects cutover-log
  deletion, and becomes claimable under the v4 lane only after the sealed-plan
  binding is present and the hold is released.

## Verification output

### v3 default — complete orchestrator integration list

Command:

```text
python -m pytest -q tools/strategy_farm/tests/test_gate_manifest.py tools/strategy_farm/tests/test_gate_contract_version.py tools/strategy_farm/tests/test_advancement_centralization.py tools/strategy_farm/tests/test_v4_runtime_wiring.py tools/strategy_farm/tests/test_book_build_guard.py tools/strategy_farm/tests/test_backfill_planner.py tools/strategy_farm/tests/test_operator_surfaces_rebaseline.py tools/strategy_farm/tests/test_activate_gate_manifest_v4.py tools/strategy_farm/tests/test_q09_news_schema_v2.py tools/strategy_farm/tests/test_q09_news_farmctl_integration.py tools/strategy_farm/tests/test_farmctl_cascade.py tools/strategy_farm/tests/test_render_cockpit_v2.py tools/strategy_farm/tests/test_mission_control_v2_data.py tools/strategy_farm/tests/test_factory_runtime_activation.py tools/strategy_farm/tests/test_include_mirror.py
```

Output:

```text
208 passed, 3 skipped, 6 subtests passed in 74.93s (0:01:14)
```

### temporary v4 default — activation tool full verification

Command:

```text
python tools/strategy_farm/activate_gate_manifest_v4.py --apply --no-db
```

Output:

```text
[PASS] flip smoke: v4 default loads and renders
[PASS] db migration: --no-db skipped; runtime DB and factory state were not inspected
[PASS] verify: pytest activation + orchestrator integration suites
208 passed, 3 skipped, 6 subtests passed in 76.16s (0:01:16)
[PASS] --no-db worktree files restored
```

Full pytest output from the last temporary-v4 run is in the ignored local path
`scratch/rb-v4-cutover/activation_verify.log`.

### Additional touched-module tests

```text
python -m pytest -q tools/strategy_farm/tests/test_rebaseline_census.py tools/strategy_farm/tests/test_q09_news_runner_v2.py
61 passed in 74.46s (0:01:14)

python -m pytest -q tools/strategy_farm/tests/test_activate_gate_manifest_v4.py
22 passed in 2.21s

python -m py_compile tools/strategy_farm/activate_gate_manifest_v4.py tools/strategy_farm/farmctl.py tools/strategy_farm/rebaseline_census.py tools/strategy_farm/backfill_planner.py
exit 0

git diff --check
exit 0 (only repository line-ending conversion warnings)
```

## Read-only runtime evidence

Command:

```text
python tools/strategy_farm/activate_gate_manifest_v4.py --cutover-dry-run --db-root D:/QM/strategy_farm
```

Observed against `D:/QM/strategy_farm/state/farm_state.sqlite` via `mode=ro`:

```text
[PASS] cutover pending rows
work_item rewrites=23
dependency-role rewrites=0
all 23 observed rows: Q09_NEWS -> Q10_NEWS, legacy -> v4
```

This census is point-in-time and may change before the Factory_OFF activation
window. No runtime row was mutated.

The stale attempt-1 activation ledger row was queried read-only and deliberately
left intact:

```text
SELECT id,contract_version,activated_at,manifest_sha256,backup_path,git_head
FROM gate_contract_activations WHERE id=1;

id=1
contract_version=v4
activated_at=2026-08-23T14:05:28.689282Z
manifest_sha256=f71c1ea63f1e847b3670904a6de25bcb4b337df9e0a7cff8ee6405d9c3aa2c83
backup_path=D:\QM\strategy_farm\backups\farm_state_pre_v4_20260823T140524Z.sqlite
git_head=922ab2ed6a1457585219792723ee3a611950dd61
```

`SELECT COUNT(*) FROM gate_contract_activations` returned `1`; the new
`gate_contract_cutover_log` table does not exist in the live DB yet and will be
created only by the orchestrated apply. The attempt-1 evidence document remains
`docs/ops/evidence/2026-08-23_gate_manifest_v4_activation.md`. The separately
referenced `activate_apply_20260823T1405Z.log` was not present in this worktree or
under `D:/QM/strategy_farm` during the read-only evidence search.

## Risks and activation notes

- The live census is volatile. The real apply re-runs the eligibility plan under
  `BEGIN IMMEDIATE`, fails closed on unsupported versions, nonblank verdicts,
  dependency collisions, or unexpected update counts, and rolls back partial
  rewrites.
- The activation ledger intentionally retains stale row `id=1`; a successful
  orchestrated activation appends a new row rather than overwriting or deleting
  it.
- The v4 activation still requires Factory_OFF. No factory state, gate criteria,
  threshold, verdict, backtest queue, or live terminal was changed by this
  ticket.

## Rollback

Code rollback:

```text
git revert <this-ticket-commit>
```

Activation rollback, if the later orchestrated apply fails after DB migration:

1. Keep Factory_OFF.
2. Restore the v3 source anchors by reverting the activation commit (not this
   preparatory ticket), and remove its promoted `gate_manifest.v4.json`.
3. The cutover and activation ledgers are append-only; do not delete their rows.
4. Ordinarily retain the additive schema. If OWNER explicitly requires a DB
   restore, use the pre-v4 backup path recorded by that activation run only after
   stopping all DB writers and preserving the failed DB for evidence.
5. Re-run the v3 verification matrix before returning the factory to service.
