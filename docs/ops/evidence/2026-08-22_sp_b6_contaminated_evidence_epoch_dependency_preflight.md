# SP-B6 Contaminated Evidence Epoch Dependency Preflight

Date: 2026-08-22

Router task: `1437b4f1-1cb5-420e-98d8-e74e33fc0cb0` (`SP-B6`)

## Verdict

DEPENDENCY_HOLD — no report was marked superseded and no rerun binding was
written. The routed task explicitly permits supersession only after each
corresponding rebuild wave completes. The magic, full-burn/timeout, and DST
waves are demonstrably incomplete; the 4-hour basket-clamp cohort also lacks a
closed rebuild manifest and deterministic lineage cutoff.

Writing markers now could include new-generation reports produced while the
waves are still moving. That is the exact false-supersession failure the task's
sequencing constraint forbids.

No historical verdict, work item, evidence file, ledger row, source, setfile,
terminal, T_Live, or AutoTrading state was changed during this preflight.

## Wave-state evidence

### Host-slot magic defect — Stage B not run

The accepted affected-set artifact
`docs/ops/evidence/2026-08-16_host_slot_magic_affected_set.json` binds 858 true
`(EA, symbol)` pairs across 175 EAs. The reviewed implementation artifact
`docs/ops/evidence/2026-08-16_host_slot_magic_fix_review.md` states:

- Stage A consists of only QM5_11424, QM5_10649, and QM5_2002;
- Stage B is the remaining deterministic set of 172 EAs; and
- mass rebuild/requalification was intentionally not self-approved from that
  task.

The accepted router verdict for task `18954866-6166-4529-8ec6-8485ef25c023`
likewise says Stage B “must be planned as its own program.” No completed Stage
B manifest or 858-pair successor binding was found. Therefore the pre-fix
magic epoch has no complete lower/upper lineage boundary yet.

### Full-burn / timeout rebuilds — queue still open

The read-only router snapshot contained 456 non-terminal `build_ea` rows:

| State | Count |
|---|---:|
| TODO | 347 |
| APPROVED | 14 |
| REVIEW | 2 |
| PIPELINE | 88 |
| RECYCLE | 5 |

The COMPILE_EA rollout review states that 86 revival rows remain governed-held.
The DL-089 Wave-1 review separately records 16 held force-rebuild rows. These
are active build/rebuild facts, not a terminal wave manifest. The SP-B6 payload
itself identifies the colliding Codex full-burn as 355 rebuilds; nothing in the
current evidence closes that cohort.

Consequently a timeout-contaminated epoch cannot yet be cut at a stable final
binary generation or bound exhaustively to successor rows.

### DST/news semantics — implementation is gated

SP-B2 (`84c988e6-fe11-47ed-b9f3-413096628bd2`) is in REVIEW with a measured
dependency hold:

- ROT-2 authoritative-source / impact-taxonomy decision is pending;
- the active Q09_NEWS pilot had 22/40 receipts and no final aggregate; and
- the 41-row append-only rerun wave remains BLOCKED behind that pilot.

The downstream schedule-view and point-in-time tasks SP-B4 and SP-B5 remain
TODO. Therefore no completed DST-corrected rebuild/rerun generation exists to
serve as a successor boundary. Marking the pre-DST rows now would be an
unbound assertion rather than lineage.

### Four-hour basket clamp — affected lineage is not yet sealed

The SP-B6 payload names the four-hour basket-clamp epoch but does not bind an
affected-pair inventory, defect-fix commit, pre-fix binary cutoff, completed
rebuild manifest, or successor work-item set. Canonical docs and active router
records contained no closed artifact supplying all five. Without those
identities, “all affected reports” cannot be selected reproducibly and a bulk
label would be guesswork.

## Current ledger boundary

The canonical `work_item_supersedes` relation was inspected read-only:

- rows: 970;
- rows with successor work-item IDs: 879;
- `operator:record` rows: 3;
- most recent `recorded_at`: `2026-08-22T07:34:07.973324+00:00`.

Those values were not changed. No existing work-item verdict was updated.

One implementation prerequisite was also found: the current
`work_item_supersedes.py record --apply` path uses `INSERT OR REPLACE` for the
`(work_item_id, source_encoding='operator:record')` key. Re-running it for the
same work item can replace a prior operator relation even though it appends an
event. SP-B6's strict append-only requirement needs an insert-only,
identity-addressed epoch binding (or exact idempotent replay validation) before
mass application; replacement semantics must not be used for this wave.

## Deterministic resume conditions

Re-route SP-B6 only after all of the following durable inputs exist:

1. one signed or reviewed wave manifest per contamination class, binding the
   defect-fix commit, affected EA/symbol set, pre-fix binary/evidence cutoff,
   and exact expected count;
2. every listed rebuild/requalification is terminal and each historical row
   either has an authenticated successor work-item/evidence hash or an
   explicit reviewed no-successor disposition;
3. the 172-EA magic Stage B and the named 355 full-burn are closed rather than
   merely queued/held;
4. the four-hour basket-clamp affected set and rebuilt successor generation are
   sealed;
5. the DST/news-semantics implementation and its append-only reruns are closed;
6. the supersession writer is append-only and its dry-run proves complete,
   duplicate-free coverage without modifying `work_items.verdict`; and
7. a before/apply/readback receipt records ledger row IDs and hashes while all
   historical evidence remains byte-for-byte present.

Only then can the acceptance condition — every affected report superseded or
rerun-bound, with no overwritten verdict — be evaluated honestly.
