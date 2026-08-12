---
title: FTMO Book 3 — QM5_13108 standalone diagnostic preregistration v1
date: 2026-07-30
status: OWNER_AUTHORIZED_SOURCE_CONTRACT
measurement_contract: FTMO_BOOK3_STANDALONE_DIAGNOSTIC_V1
evidence_vintage: FTMO_BOOK3_20260730_R2_STANDALONE_DIAGNOSTIC_V1
factory_on_authorized: false
live_authorized: false
---

# FTMO Book 3 — QM5_13108 standalone diagnostic preregistration v1

## Purpose and boundary

This contract authorizes exactly one new, content-addressed standalone
diagnostic measurement for `QM5_13108` on `XTIUSD.DWX`, D1, terminal T10.  Its
sole purpose is portfolio-component evaluation after the Book-3 V2 joint
fidelity ladder stopped at J1.

The diagnostic is not R2, is not a V2 ladder rung, does not supersede any V2
row, cannot consume a fidelity receipt, cannot admit a joint EA, cannot release
a hold, cannot enqueue or promote another phase, and does not authorize
Factory ON or live trading.  In particular, pending V2 R2 work item
`034a2bcd-1a69-5437-9654-6e4b3e9b0ff9` remains pending, unclaimed, without a
verdict or evidence. The diagnostic binds and revalidates its complete
15-column `work_items` preimage, canonical row hash, raw payload hash, and
complete active/non-releasing nine-column hold preimage and hold hash. Any
change, including timestamps, attempt count, parent, setfile, payload text or
hold metadata, fails before execution and again after the isolated run.

## Exact measurement

| Field | Required value |
|---|---|
| Contract | `FTMO_BOOK3_STANDALONE_DIAGNOSTIC_V1` |
| Diagnostic code | `D13108` |
| EA / magic | `QM5_13108` / `131080000` |
| Symbol / timeframe | `XTIUSD.DWX` / `D1` |
| Setfile | `QM5_13108_xti-mtsm-s2_XTIUSD.DWX_D1_backtest.set` |
| Terminal | T10 only; exact deny-list `T1,T2,T3,T4,T5,T6,T7,T8,T9,T_LIVE` |
| Window / model | `2018.07.02`–`2025.12.31`, MT5 model 4 |
| Account | USD 100,000 |
| Risk | `RISK_FIXED=1000`, `RISK_PERCENT=0` |
| Timeout | exactly 240 minutes |
| Money basis | `FULL_POSITION_LIFECYCLE_ACTUAL_V1` |
| Post-run source | governed FILE_COMMON `QM/q08_trades/13108_XTIUSD_DWX.jsonl` |

The content identity binds the authoritative Git commit, MQ5, setfile, staged
EX5 and compile manifest, framework include tree, controller and worker source
manifests, preregistration, the exact canonical 307 execution-input artifacts,
calendar and cost bundles, official-rule snapshot/rulepack, and the excluded V2
R2 full row, payload and hold hashes. Its report directory is derived from the
resulting RFC-4122 content UUID under `D:\QM\reports\work_items`; `report_root`
is forbidden in the work-item payload. The entire derived directory must be
absent at runner preflight and immediately before launch. The dispatch boundary
then creates it atomically with `exist_ok=false`; any incumbent file or empty
directory blocks the run.

The runtime-source manifest includes transitive import/load dependencies, in
particular `q09_news_contract.py` (imported by `q09_news_schema.py`),
`phase_runner_allowlist.v1.json` (loaded while importing `farmctl.py`),
`framework/registry/tester_defaults.json` (consumed by `run_smoke.ps1`),
`process_identity.py`, and `windows_job_object.py`. All are source-scoped,
content-addressed and re-hashed after execution.

## Fail-closed run acceptance

Preparation and execution both require the exact, unchanged FACTORY_OFF bytes,
an empty Factory process census, the Factory mutation lock, current source and
artifact hashes, and a non-releasing diagnostic hold.  Preparation creates the
work item and hold with absence-CAS inside `BEGIN IMMEDIATE`; snapshot, intent,
snapshot attestation, receipt, worker log and harvested evidence paths are
create-only. Apply outputs must be absolute, non-aliased, distinct, outside all
bound source/input paths, and below the exact governed
`D:\QM\strategy_farm\artifacts` or `D:\QM\reports\work_items` roots. Runtime
import closure and the strict portable-compile manifest, controller, four
MQ5/EX5/log result triples and selected EA binding are parsed and re-hashed at
preflight and after the worker returns. The diagnostic compile policy is
`MANIFEST_PINNED_STAGED_EX5_NO_RECOMPILE_V1`: dispatch validates the already
staged source/destination EX5 and manifest and structurally bypasses the generic
compile fallback. It never invokes a generic compile or rewrites the repository
EX5.

The recovery snapshot is identity- and hash-bound through the mutation/run
window. Preparation revalidates it before mutation, inside `BEGIN IMMEDIATE`
immediately before commit, immediately after commit, and before receipt
publication. The runner retains an open snapshot handle and revalidates the
same object immediately before worker launch, after execution, and before its
receipt. Identity loss cannot produce a successful receipt.

The isolated run must produce a fresh Q08 stream after worker start.  The
harvested stream must contain at least one closed trade and every selected
closed trade must have symbol `XTIUSD.DWX`, magic of JSON type integer and exact
value `131080000`, canonical BUY/SELL side, positive lifecycle
times/prices/volume, full-lifecycle money basis, and reconciling commission and
net components. `mae_acct` is a mandatory Q08 field on every selected closed
trade and must be finite and non-positive. A missing, stale,
legacy-money, mixed-magic, malformed, empty, or non-reconciling stream fails the
runner receipt.  Before decode/parse the controller enforces a 256 MiB file
limit, 1 MiB per JSONL line, 2,000,000 total lines and 1,000,000 closed-trade
rows.  The Q08 validator reads the harvested target once and requires its
SHA-256, byte count and line count to equal the harvested fingerprint exactly.
Its `selected_trade_count` is an explicit downstream-evaluator gate and must be
recounted from the same bound stream.

The authoritative read-only census uses the bound
`factory_process_scope.ps1` semantics and covers worker daemons, allowlisted
phase runners, run-smoke wrappers, Factory terminals, tester agents, and
review-required near matches. Post-run global discovery is observe-and-fail
only. On Windows the worker is created suspended, assigned through its retained
process handle to a kill-on-close Job Object, identity-bound, and only then
resumed. Cleanup closes that exact retained Job; there is no PID-reopen or
`taskkill` fallback. T5, T_Live and unrelated processes are never targets.

No V2 fidelity receipt may be supplied.  The diagnostic receipt is not a V2
fidelity operand and cannot satisfy any V2 release or progression gate.

## Controlled runbook

Do not use these commands until the controller, runner and this preregistration
are committed together and the exact commit has been independently reviewed.
No command below removes FACTORY_OFF or changes scheduled tasks.

1. Establish a clean, exact source commit and create the dry-run manifest:

   ```powershell
   $diagCommit = (git -C C:\QM\repo rev-parse HEAD).Trim()
   python -B C:\QM\repo\tools\strategy_farm\prepare_ftmo_book3_standalone_diagnostic.py `
     --source-commit $diagCommit `
     --out D:\QM\strategy_farm\artifacts\ftmo_book3_v2_full_lifecycle_20260730_a02\r2_diagnostic_prepare_plan.json
   ```

   `--out` is absolute and create-only; an existing target is refused and is
   never truncated or overwritten.

2. Independently inspect `valid`, `errors`, `plan_id`, the FACTORY_OFF and DB
   hashes, `operation_count=1`, `execution_input_artifact_count=307`, the new
   work-item ID, and the excluded V2 R2 binding.  Hash the plan, then apply it
   with create-only snapshot and receipt paths by passing all exact values to:

   ```powershell
   python -B C:\QM\repo\tools\strategy_farm\prepare_ftmo_book3_standalone_diagnostic.py `
     --source-commit <40-hex> --apply `
     --manifest <absolute-plan.json> `
     --expected-manifest-sha256 <64-hex> `
     --confirm-plan-id <64-hex> `
     --expected-factory-off-sha256 <64-hex> `
     --expected-db-state-sha256 <64-hex> `
     --snapshot-path D:\QM\strategy_farm\artifacts\<diagnostic-id>\prepare-before.sqlite `
     --receipt-path D:\QM\strategy_farm\artifacts\<diagnostic-id>\prepare-receipt.json
   ```

3. Re-run the isolated runner in dry-run mode for the newly created diagnostic
   UUID.  It must be valid with diagnostic isolation true, zero ladder rungs,
   `no_ladder_progression=true`, no fidelity receipt, and all source/input
   bindings valid.

4. Execute only after the dry-run values are independently transcribed:

   ```powershell
   python -B C:\QM\repo\tools\strategy_farm\isolated_work_item_runner.py `
     --root D:\QM\strategy_farm --terminal T10 `
     --work-item-id <diagnostic-uuid> `
     --worker-script C:\QM\repo\tools\strategy_farm\terminal_worker.py `
     --repo-root C:\QM\repo --timeout-minutes 240 --apply `
     --expected-factory-off-sha256 <64-hex> `
     --expected-db-state-sha256 <64-hex> `
     --expected-payload-sha256 <64-hex> `
     --expected-worker-sha256 <64-hex> `
     --snapshot-path D:\QM\strategy_farm\artifacts\<diagnostic-id>\run-before.sqlite `
     --receipt-path D:\QM\strategy_farm\artifacts\<diagnostic-id>\run-receipt.json `
     --worker-log-path D:\QM\strategy_farm\artifacts\<diagnostic-id>\worker.log
   ```

   Do not pass `--fidelity-receipt-path` or
   `--expected-fidelity-receipt-sha256`.

5. Accept the measurement only if the create-only run receipt has
   `success=true`, every success check true, `diagnostic_q08.valid=true`, a
   positive selected-trade count, `diagnostic_hold_unchanged=true`, an exact
   `diagnostic_hold` pre/post match, an unchanged FACTORY_OFF hash, quiescent
   full post-run process census, and the excluded V2 R2 full row and hold still
   exact and untouched.

## Failure, rollback and supersession

If prepare fails before commit, the database transaction rolls back.  Preserve
any create-only intent, snapshot or snapshot attestation for audit; do not
overwrite it.  The prepare controller writes the hash-bound snapshot
attestation before `BEGIN IMMEDIATE`.  A crash after DB commit but before the
normal receipt is therefore fail-closed: do not re-apply the manifest.  An
operator may publish only a database-read-only reconciliation receipt by supplying the
exact manifest, intent and snapshot-attestation hashes, the exact plan/source/
FACTORY_OFF bindings, and an independently captured current logical DB hash:

```powershell
python -B C:\QM\repo\tools\strategy_farm\prepare_ftmo_book3_standalone_diagnostic.py `
  --source-commit <40-hex> `
  --reconcile-intent <absolute-prepare-receipt.json.intent.json> `
  --manifest <absolute-plan.json> `
  --expected-manifest-sha256 <64-hex> `
  --expected-intent-sha256 <64-hex> `
  --expected-snapshot-attestation-sha256 <64-hex> `
  --confirm-plan-id <64-hex> `
  --expected-factory-off-sha256 <64-hex> `
  --expected-post-db-state-sha256 <64-hex> `
  --receipt-path <new-absolute-prepare-receipt.json>
```

Reconciliation never writes the database, but it deliberately acquires the
temporary Factory mutation lock and creates the final receipt plus immutable
publication sidecar. It succeeds only when the exact
pending diagnostic row/hold is already committed, the excluded V2 R2 binding
is unchanged, the report root is still absent and the Factory process census
is empty.  If the MT5 run fails after claim or produces an invalid stream,
preserve the work item, hold, artifacts, failure receipt and worker log.  The
diagnostic explicitly forbids harvest recovery from a failed receipt. Hard-link
publication retains immutable temp names, and any caught partial publication
retains target residue under policy
`RETAIN_FAIL_CLOSED_RESIDUE_NO_PATH_UNLINK`; automatic rollback/cleanup by path
is forbidden because it has a check/unlink ABA gap. Never
reset or reuse that content ID.  Any retry requires a new explicitly versioned
diagnostic evidence vintage/content identity and a new create-only work item.

The V2 R2/J2 rows remain governed by their original V2 contract and holds.
Closing or superseding them is a separate OWNER action requiring its own
hash-bound abort/supersession controller.  A future repaired ladder must use a
new measurement contract/generation; it must not retag, delete or duplicate a
sequence inside the existing V2 ladder.
