# Task 8b692228-36f5-4821-9f4b-9f428fe43b4f — SESSION RECEIPT DEBT census + bounded receipt minting

Snapshot time: 2026-10-02T01:00Z-01:10Z. The factory is live; all counts below are a
point-in-time snapshot, not a frozen total — the pulse's own example list from the
payload (QM5_41503, QM5_9251, QM5_9297, QM5_9410) had already rolled off `git status`
by the time this task was worked, and new outputs appeared during this session
(pending-commit count rose 73→75 between two `ftmo_owner_status_pulse.py` runs ~10 min
apart). Treat every number here as "as of" its own command, not a fixed backlog.

## Scope note (read first)

`git status` of `C:/QM/repo` is the canonical source for these untracked outputs; this
session's launch constraints forbid writing/patching files under `C:/QM/repo` (same
cross-checkout write constraint already surfaced the same day by sibling task f865f0a1
— see `docs/ops/evidence/task_f865f0a1*` in this worktree's history, commit 1704cfc646).
That means objective step (4), "commit the admitted .ex5/sets with pathspec," cannot be
executed from this worktree: the admitted bytes physically live in `C:/QM/repo`'s
working tree, not in `C:/QM/worktrees/claude-orchestration-2`. Everything that is
read-only against `C:/QM/repo` (git status, sha256, DB queries) and everything that only
mutates the shared `farm_state.sqlite` (not repo files) was executed for real. The
commit step is handed back to whichever surface can write `C:/QM/repo` (the pump
auto-commit lane for the sets-only group; Codex/OWNER close-out for anything needing a
manual pathspec commit).

## (1) Census

24 EA output directories show untracked `.ex5`/`.set` files in `C:/QM/repo` right now
(73 individual files). Full per-label table: `census.csv`. Classification:

| classification | count | meaning |
|---|---|---|
| `session_attested` (RECEIPTED) | 3 | pump compiled directly, attestation exists, already has a matching governed COMPILE_OK — only the `sets/`/`.ex5` commit is outstanding, owned by pump auto-commit |
| `untracked_ex5_no_attestation` | 2 | `.ex5` itself is untracked **and** has no `session_compile_ok.json` attestation anywhere under `D:/QM/strategy_farm/artifacts/builds/` |
| `sets_only_pump_owned` (ex5 already tracked) | 19 | only generated `sets/*.set` files are untracked; the `.ex5` is already committed. Auto-commit regex (`ftmo_owner_status_pulse._GENERATED_EA_OUTPUT_RE`) owns these; they are explicitly **non-blocking** per the pulse (dirty-guard v2) |

Of the 19 "sets only" labels, 14 have **no COMPILE_OK work_item anywhere** matching
their currently-committed `.ex5` bytes (one is `QM5_1537` with **zero** compile attempts
ever recorded) — their only `compile`-kind work_item, if any, is a single `failed` row.
This is very likely the same population as the `legacy_first_governed_compile_waves`
registry extension that sibling task f865f0a1 found blocked the same day (same
QM5_9xxx legacy-library-mining range, same cross-checkout constraint) — flagging the
overlap rather than re-investigating it under this ticket's narrower session-receipt
scope.

Separately, the broader "attested" population (every EA with a live
`session_compile_ok.json`, regardless of whether it's one of today's 24 dirty
directories) has 12 entries that are **not** `RECEIPTED`:

| state | count | labels |
|---|---|---|
| `UNRECEIPTED` (attested, mintable now) | 2 | QM5_33005, QM5_32001 |
| `UNATTESTED_UNRECEIPTED` (no attestation at all) | 2 | QM5_41152, QM5_9208 |
| `STALE_ATTESTATION` (on-disk bytes moved past the attestation) | 2 | QM5_9273, QM5_41205 |
| `NEEDS_REPAIR_SUCCESSOR` (already has a COMPILE_OK for *older* bytes) | 6 | QM5_41203, QM5_41250, QM5_41265, QM5_41214, QM5_41248, QM5_21505 |

Generated via the repo's own governed tool, read-only:
`python tools/strategy_farm/session_build_receipt.py census --repo-root C:/QM/repo --farm-root D:/QM/strategy_farm`.

Notable single finding: **QM5_41152**'s `.mq5` source does not exist anywhere in git
history or the current working tree (`git log --all` for that path returns nothing;
only `SPEC.md` was ever committed for that EA, via "pump auto-commit 5 factory artifact
path(s)"). The 447 KB `.ex5` on disk is an orphan binary with no reproducible source and
no `agent_tasks` build row at all — it cannot be re-anchored by any governed compile
path. A `docs/strategy_card.md` does exist for it, so the mechanization can be redone
from the card if OWNER wants this strategy kept; otherwise it is an undispositioned
orphan (not deleted — evidence is never deleted — but it cannot be committed through any
governed receipt path as-is).

## (2) Receipts minted

Two EAs were `UNRECEIPTED` (attested, below the 3-failure cap) and eligible for
`enqueue-compile --receipt-session-build` right now. Both were minted for real (DB
writes only, no repo file writes — `farmctl.py enqueue_compile_eas` inserts a
`work_items` row, it does not touch `C:/QM/repo` files):

- **QM5_33005_andrea-unger-dax-intraday-bias-breakout** → work_item
  `c460dbd6-ee97-452a-a520-078f356c559f`, enqueued `pending`. Within the same minute the
  live pump recompiled this EA again (current `ex5_sha256` changed under the queued
  receipt), so it will likely resolve back to `STALE_ATTESTATION` rather than
  `RECEIPTED` — a live-target race, not a tooling fault.
- **QM5_32001_nq-micro-momentum-apex-scalper** → work_item
  `b66fda0d-b048-4aa4-9c43-cb9cac7d8332`, claimed and failed within ~20s:
  `COMPILE_FAIL` / `SETFILE_GENERATION_FAILED` (NDX.DWX / M1 setfile generation,
  infra-side, not a source defect). `failed_receipt_attempts` is now 3 of the
  `SESSION_RECEIPT_MAX_FAILED_ATTEMPTS=3` cap — **do not re-enqueue blindly**; route to
  `triage_failure` for the setfile-generation defect first, or the next failure caps it
  as `RECEIPT_FAILED_CAPPED`.

Full detail: `receipts.jsonl`.

## (3) Unattested / stale / needs-repair — proposed governed path (not executed)

Not minted this cycle — each needs a different, judgment-bearing governed verb than the
one this task was scoped to run, or is blocked outright:

- **QM5_41152** (no source, no attestation, no build task): no compile path applies.
  Propose OWNER/Codex decision — re-mechanize from `docs/strategy_card.md` or formally
  mark the orphan `.ex5`+`SPEC.md` for archival (not deletion).
- **QM5_9208** (mq5 present, `.ex5` untracked, 2 prior failed COMPILE_EA rows,
  `WORK_ITEMS_EXIST`/`BOUND_SETFILE_HASH_EXISTS` refusals on a plain `enqueue-compile`
  probe): governed path is `--build-task-id` bound to one of its open BLOCKED
  `build_ea` tasks (`4039e92e-5cee-40f0-81fd-55573fe19f2d` or
  `ef5aad39-d138-46d1-9227-d9765d5baaa8`) or `--repair-successor-of` against the failed
  predecessors (`25ebda0c…`, `a393caaa…`) — both require the operator to assert *why*
  the predecessor failure is now resolved, which this ticket's mandate does not cover.
- **QM5_9273** (`STALE_ATTESTATION`, current `.ex5` is **absent from disk entirely**)
  and **QM5_41205** (`STALE_ATTESTATION`, rebuilt since attestation): the recorded
  attestation no longer describes reality; propose a fresh build-session pass (new
  attestation) rather than trying to force the stale one through.
- **NEEDS_REPAIR_SUCCESSOR ×6** (QM5_41203/41250/41265/41214/41248/21505): each already
  holds a governed COMPILE_OK for *older* bytes; the live session rebuilt them. The
  correct verb is `--repair-successor-of` / `--reanchor-successor-of` against the prior
  COMPILE_OK work_item, which is a distinct authority decision (asserting the rebuild is
  a legitimate successor, not a regression) — proposing it rather than asserting it here.

## (4) Commit

Not performed — see Scope note above. Nothing in `C:/QM/repo`'s working tree was
written by this session.

## (5) Pulse warning, before/after

| metric | before | after |
|---|---|---|
| `COMPILE_OUTPUT_PENDING_COMMIT` (file count, live, moves independently of this task) | 73 | 75 |
| attested-but-not-`RECEIPTED` entries (this task's actionable scope) | 10 | 9 (`UNRECEIPTED` 2→1; `STALE_ATTESTATION` 2→3 as QM5_33005 rolled over) |
| `STALL_FOUND` | YES (unrelated: 3 `ORPHAN` paths under `QM5_1537_aa-vol-sma10/calendar/` block 2 builds) | YES, unchanged |

The active `TECHNICAL_STALL` is **not** a `COMPILE_OUTPUT_PENDING_COMMIT` item — it's 3
`ORPHAN`-classified calendar CSV/manifest files for `QM5_1537_aa-vol-sma10` (1294+ min
old, no live build log), outside this ticket's `.ex5`/`sets/`/`SPEC.md` scope. Flagging
for router visibility; not actioned here (out of scope, and would be a second task).

## Verdict

Partial completion within the constraints of this worktree: real, verified census
produced (governed tool, read-only); 2 of 2 eligible receipts minted for real through
the governed `--receipt-session-build` path (one already raced by the live factory, one
failed on an unrelated setfile-generation defect and is now at the failure cap); 10
non-mintable items classified with a proposed next governed verb each; the final commit
step is blocked by the documented cross-checkout write constraint and handed back to the
pump auto-commit lane / Codex-or-OWNER close-out.
