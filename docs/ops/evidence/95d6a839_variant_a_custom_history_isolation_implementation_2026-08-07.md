# Variant A Custom-history isolation — implementation evidence

Date: 2026-08-07
Router task: `95d6a839-dc74-4da1-b09a-be33663f6adb`
Builder: Codex
Required approver: Claude
State at handoff: REVIEW — no runtime activation or MT5 mutation

## Outcome

Variant A now has fail-closed, dry-runnable tooling for a signed archive
manifest, private mutable staging, archive hardlinks, ACL immutability,
file-ID-aware audits, guarded rename cutover, retained rollback, global
containment, worker claim/spawn admission, and the `1 → 2 → 5 → 10` ramp.

Nothing under any `Bases\Custom` path was created, renamed, linked, copied,
ACL-modified, or deleted during implementation. No terminal was started or
stopped, no backtest was interrupted, and T_Live/FTMO/AutoTrading were not
touched. The existing running workers retain their in-memory pre-change code
until the OWNER window’s governed full-fleet recycle.

## Review directives resolved

### Lease release order

Containment release is structurally after both full cutover audits and gate
activation, and before ramp step 1. The release command rejects mismatched
audit paths, a different activation/manifest, any active work/process, or a
remaining lease record. Ramp limit 1 is written immediately after release;
the ramp command refuses while containment is engaged and enforces the exact
`1 → 2 → 5 → 10` transition sequence. An activated gate with no ramp receipt
holds all ten terminals, so the release/write boundary cannot admit the fleet.

Any isolation failure, error `[32]`, history synchronization failure, archive
drift, or archive-write signature automatically re-engages containment.
Rollback permits shared-topology operation only through an explicit
`PASS_SERIALIZED_ROLLBACK` receipt while that global lease is engaged.

### Exact runner and protected roots

T5 is an active runner. The migration set is exactly T1–T10. T5 is not a
protected root.

Protected roots are exactly:

- `C:\QM\mt5\T_Live`
- `D:\QM\mt5\T_Live` (reserved even while absent)
- `D:\QM\mt5\FTMO_STREAM1`
- `D:\QM\mt5\FTMO_STREAM2`
- `D:\QM\mt5\DEV1`
- `D:\QM\mt5\DEV2`
- `D:\QM\mt5\T_Export`

The audit fails on exact aliases, ancestor overlap, missing mutable stores, and
reparse-point runner stores.

### Builder is not approver

Mutation requires a full-hash manifest plus a detached OWNER receipt exactly
matching its embedded approval. That approval must bind the implementation Git
commit and a named Claude review task with verdict `APPROVED`; metadata-only,
unsigned, unreviewed, or terminal-mismatched inputs fail closed. This task
therefore remains in REVIEW and does not self-approve. Mutating commands also
parse the signed timestamps and refuse execution outside the OWNER window.

## Delivered files

| Path | Purpose |
|---|---|
| `tools/strategy_farm/custom_history_contract.py` | Canonical manifest hashing, year classification, file identity, OWNER/Claude approval contract, ACL probe |
| `tools/strategy_farm/custom_history_acl.ps1` | One-process ACL plan/apply/verify with OWNER and content binding |
| `tools/strategy_farm/custom_history_migration.py` | Dry-run plan, idempotent staging, verification, quiescent cutover, DB backup, rollback, activation, containment and ramp commands |
| `tools/strategy_farm/custom_history_lease.py` | Heartbeating global lease bound to PID creation identity and reconciled stale release |
| `tools/strategy_farm/custom_history_gate.py` | Dual-audit activation, per-claim admission, ramp, and serialized rollback receipts |
| `tools/strategy_farm/mt5_history_isolation.py` | v2 topology, reparse, archive manifest, file-ID, link-count, hash and ACL audit |
| `tools/strategy_farm/terminal_worker.py` | Gate before claim and immediately before spawn; lease held through sealed run result |
| `docs/ops/evidence/2026-08-09_custom_history_isolation_variant_a_sunday_runbook.md` | OWNER-window executable checklist and rollback sequence |
| focused tests under `tools/strategy_farm/tests/` | Manifest, tamper, staging, cutover, rollback, lease, activation, ramp, file-ID and worker-boundary regression coverage |

## Safety mechanics

- Archive classification accepts only 2017–2025 `.hcc`/`.tkc` files whose
  stem begins with the declared four-digit year. 2026 files, `.hc`, `.dat`, and
  every unclassified path are private mutable copies.
- Manifest rows bind relative path, size, SHA-256, year, volume/file ID,
  link count, and mtime. Case collisions and path traversal are rejected.
- Staging is beside live `Custom`, never inside it. Existing staged files are
  verified for idempotent reuse; no cleanup/delete shortcut exists.
- Staging, cutover, rollback, and ACL application all require a present
  `FACTORY_OFF.flag`, engaged containment, and a quiescent farm before mutation.
- Archive files retain the manifest file ID and receive an explicit deny for
  runner write, delete, permission change, and ownership takeover. Full ACL
  verification receipts bind the two fresh-process audits.
- Mutable file IDs may occur in only one terminal tree and may never alias an
  archive ID. The pre-ramp full audits also require the same mutable path/size
  set on all ten runners. Archive sharing is allowed only for the same
  manifest path/hash.
- Cutover uses per-terminal timestamp/window-bound renames, retains every old
  topology object, checks quiescence and containment, and takes a SQLite backup
  before the first rename. Hash-bound progress journals make interrupted
  cutover and rollback renames resumable without deleting either tree.
- Stale global leases are never released on age alone. The owner PID creation
  identity must be absent/reused, the terminal inactive, and the database claim
  reconciled. Live/unreadable/ambiguous owners stay blocked.
- The activation file is absent today, so the new worker gate cannot throttle
  current work before the OWNER window.

## Read-only live dry run

The live topology audit returned `FAIL_CLOSED` as expected:

- audit SHA-256: `1596c4b0130d6dc499b93dbf4bc53d7fe07675b9544eeef2f6328e9e861f6abe`;
- T1–T10 all resolve `Bases\Custom` to `D:\QM\mt5\T1\Bases\Custom`;
- T2–T10 are reparse points;
- T5 was correctly included in the collision.

The metadata-only planner, against the live tree and without output retention,
measured:

- 4,329 total files;
- 3,946 archive hardlink candidates;
- 383 private mutable files per terminal;
- 44,231,653,718 archive bytes;
- runner identity `WIN-B95G5LPSJ1O\qm-admin` from the ten live worker owners;
- plan SHA-256 `fc801eb8effcc2a9e14be230b083cff0b21aa9bc72a2cd207171084d0c1e2230`.

The full content-hash dry run completed in 94.6 seconds, read 3,946 archive
files / 44,231,653,718 bytes, produced draft-only manifest SHA-256
`965db5b952e36ec1961f1e1e03f0fb018f5f289523bb513ac0dfbe80b44f96aa`, and
wrote no manifest. The Sunday manifest will have a different identity because
its creation timestamp and live metadata are rebuilt inside the signed window.

## Verification

Passing checks:

- Python compilation for all six Python implementation files and the modified
  worker/auditor;
- PowerShell parser: zero errors for `custom_history_acl.ps1`;
- focused suite: `26 passed`;
- existing worker atomic-claim suite excluding one unrelated baseline failure:
  `61 passed, 1 deselected`.

The excluded existing test is
`test_watchdog_reset_handover_has_transactional_claim_interlock`. It fails on
the pre-existing `Factory_ON.ps1` source-order assertion (`clear_pos=62584`,
first `start_terminal_workers.py` text occurrence `=10489`). None of this
task’s bounded paths changes `Factory_ON.ps1`; the other 61 tests pass.

## Review and execution boundary

Claude should review the implementation line by line, especially:

1. OWNER/Claude receipt binding and dry-run/`--execute` separation;
2. ACL rights and manifest/file-ID equality;
3. lease stale-release reconciliation and claim-to-result lifetime;
4. gate activation, ramp hold, automatic containment, and rollback mode;
5. Sunday ordering and Factory ON runtime-decision remint.

No manifest is OWNER-approved yet, no Sunday time is signed, dual cutover
audits do not yet exist, and no Q-only pipeline evidence follows from these
unit/read-only checks. Runtime use remains prohibited until the runbook’s
OWNER and independent-review conditions are satisfied.
