# BLOCKED agent-task backlog disposition — 2026-09-12

## Result

Follow-up task `f239a2d9-2259-4084-bc65-21cf0e50e2b5` to original task
`349a8394-090d-431c-8037-72c3bc04c1c2` is ready for REVIEW. A new
default-read-only sweeper classifies every BLOCKED task, requires a fresh governed
magic-allocation precheck, and permits state changes only through an explicit class,
positive batch limit, atomic task/event transaction, and append-only payload journal.
It never deletes a task or overwrites its artifact path. An exact OWNER manifest is
required for dependency-row disposition; an archive adds an `ARCHIVED` prefix while
preserving the complete prior verdict inline and in the journal.

The concurrent OWNER backlog disposition reduced the observed snapshot from 422
BLOCKED rows to 114 before this paced repair. This cycle then reduced 114 to 103:
ten registry/magic build tasks returned to TODO through the ordinary router predicate,
and one already-terminal review task closed FAILED. The current remaining census is
69 after batch 02, with no unclassified row.

## Dry-run-first class table

| Class | Initial | Applied this cycle | Remaining | Disposition |
|---|---:|---:|---:|---|
| Registry/magic: fresh precheck ready | 11 | 20 -> TODO across batches 01-02 | 0 | Each batch was capped at ten; allocations made nine rows ready in each batch |
| Registry/magic: allocation required | 27 | 18 allocations across batches 01-02 | 18 | Continue in bounded future batches of at most ten router releases |
| Registry/magic: exact hold | 50 | 0 | 50 | 47 cards lack valid target symbols, 2 have identity conflicts, and `QM5_1157` has two approved-card matches; preserve fail-closed |
| Non-EA dependency / OWNER | 24 | 22 -> FAILED; 2 -> TODO | 0 | Exact evidence-pinned OWNER manifest; no deletion |
| Terminal review close | 1 | 1 -> FAILED | 0 | Existing terminal evidence; append-only journal |
| RETEST live-state | 0 BLOCKED | 0 | 0 | Historical census: 13 rows, already terminally assessed (5 PASSED, 8 FAILED) |
| Video | 1 | 0 | 1 | Explicitly untouched |

The initial and refreshed machine-readable plans are
`2026-09-12_blocked_backlog_plan.json` and
`2026-09-12_blocked_backlog_after_plan.json`.

## Registry/magic batch 01

The governed allocator was run in dry-run mode first, then applied for nine cards.
Together with one row already passing the fresh precheck, this formed the ten-build
cycle cap:

- already ready: `5fa16349` / `QM5_38003`
- allocated: `ab03acbe` / `QM5_2135`, `0568432f` / `QM5_9104`,
  `4382291e` / `QM5_9103`, `aca126f7` / `QM5_9102`, `2cdbbe4e` /
  `QM5_9010`, `7b3784ed` / `QM5_9211`, `52ee2c30` / `QM5_9215`,
  `2189218c` / `QM5_9216`, and `973e3dce` / `QM5_9225`.

The apply added 34 active magic rows and one missing EA identity (`QM5_2135`),
deleted zero retired rows, left the pre-existing identity-collision counts unchanged,
and left status-aware magic collisions at zero. The resolver was regenerated from the
registry. Evidence:
`2026-09-12_blocked_backlog_magic_batch01_dry_run.json`,
`2026-09-12_blocked_backlog_magic_batch01_apply.json`, and
`2026-09-12_blocked_backlog_magic_requeue_apply.json`.

## Concurrent scope update and correction journal

While this task was running, another canonical orchestrator changed its state from
IN_PROGRESS to TODO at `2026-09-12T05:34:48Z` and recorded that 95 agy-era rows had
already been requeued. Before that new scope verdict was observed, 74 of those rows
had been interpreted under the original class-4 wording and moved TODO -> FAILED.
The sweeper was extended with a narrow correction mode that recognizes only rows
whose last sweeper journal reason is
`legacy_agy_recycle_requeue_corrected_to_archive`. A dry-run and apply then restored
all 74 to TODO with a second append-only entry. Their effective state is therefore
identical to the concurrent OWNER scope update, while the complete misstep and
correction remain auditable in
`2026-09-12_blocked_backlog_legacy_agy_apply.json`,
`2026-09-12_blocked_backlog_legacy_restore_plan.json`, and
`2026-09-12_blocked_backlog_legacy_restore_apply.json`.

## Follow-up batch 02

The batch-02 snapshot began at 103 BLOCKED rows. The governed allocator first
dry-ran and then allocated 32 active magic rows for nine exact cards:
`QM5_9230`, `QM5_9231`, `QM5_9233`, `QM5_9232`, `QM5_9279`, `QM5_9277`,
`QM5_9276`, `QM5_9275`, and `QM5_9273`. Together with already-ready
`QM5_41141`, the bounded sweeper returned ten rows to TODO. It deleted zero
retired rows, added no identity rows, preserved the pre-existing identity
collision counts, and finished with zero status-aware magic collisions.

The exact OWNER manifest then classified all 24 non-EA dependency rows. The first
apply deliberately refused 21 archives because their verdicts were non-empty; after
a focused test added verbatim inline preservation, those 21 were archived. Across
both applies, 22 rows became FAILED and two actionable rows became TODO. One of the
TODO rows was already claimed by the independent router at verification time. All 24
have an `OWNER_BACKLOG` append-only journal entry, all 22 archives have the required
prefix, and the 21 non-empty prior verdicts remain verbatim after
`PRIOR_VERDICT_PRESERVED:`. Artifact paths were not changed.

### Exact 24-row OWNER disposition table

| Task | Final disposition | Evidence pin / reason |
|---|---|---|
| `3a32ab4b-807f-4367-8ce1-fcfca1b2e6a8` | FAILED | batch-02 census; titleless, acceptance-less legacy handoff |
| `61cfbaf3-a51d-437d-923c-a3eeff7f5116` | FAILED | `CODEX_BRIEF_mnt_review_corrections_2026-07-28.md`; T5-only premise disproved |
| `a3ba2414-a8ae-4809-b1ba-3cc168649e00` | FAILED | `OPEN_ITEMS_STATUS.md`; stale 304-build premise |
| `14487282-3868-43cb-b22d-00ea049de0b8` | FAILED | Q09 binder; superseded legacy rerun batch |
| `84c988e6-fe11-47ed-b9f3-413096628bd2` | FAILED | `NEWS_CALENDAR_CONTRACT_V2_2026-08-22.md`; duplicate contract task |
| `1437b4f1-1cb5-420e-98d8-e74e33fc0cb0` | FAILED | Q09 binder; superseded unbounded epoch task |
| `3aa38252-fea5-4b51-b082-4a3f56da3a05` | FAILED | vault cleanup evidence; stale redaction backlog |
| `42d5b50b-209c-458a-88c0-5b2335a2bf27` | FAILED | batch-02 census; unpinned cost-model task |
| `2f36c28c-6430-4a55-8af7-8d213f372cc6` | FAILED | backup retention manifest; superseded generic dry run |
| `3d68f538-ffd9-48ed-a4b9-bfab1b33f7e2` | FAILED | `OPEN_ITEMS_STATUS.md`; superseded FTMO filter task |
| `41aa55bc-0780-474d-8f26-332db8fb9e1b` | FAILED | `OPEN_ITEMS_STATUS.md`; OWNER-key-dependent restore drill |
| `74a78403-733e-40c7-a80e-f222f36c942f` | FAILED | `OPEN_ITEMS_STATUS.md`; deferred by OWNER backup-key decision |
| `f8cf3ca4-e4e0-43a8-80fa-c36f3d97e537` | FAILED | News Contract V2; duplicate point-in-time semantics task |
| `74e72403-399b-41c9-8627-0fdaa0bc8e08` | FAILED | Strategy Archive v4 reconciliation; superseded numbering |
| `942fd7c2-c094-40f8-8e45-49730c88ec17` | FAILED | `OPEN_ITEMS_STATUS.md`; no current trust-domain authority |
| `8c46a30d-5aab-46a1-aeb5-2ca9507d3014` | FAILED | News Contract V2; superseded blackout-view task |
| `3c365266-68b6-4474-87ac-9049af52c7ec` | FAILED | vault cleanup evidence; no fresh deletion authority |
| `5578e607-5c07-4c17-bef1-a1d09024282e` | FAILED | `OPEN_ITEMS_STATUS.md`; stale four-sleeve Q11 task |
| `027fb63f-07a8-4799-a3e3-5c6fd3558d4b` | FAILED | camofox host preflight; outside active research lane |
| `8f0b1b9e-9e5c-5922-9a4e-b266a4fa385e` | FAILED | CEO audit; same-program activation rolled back |
| `4ce6ec32-a28a-491a-b4ec-5d17a756ff0c` | TODO | exact backup writers pinned to `farmctl.py` and governed hold helper |
| `5ff527e8-c6e4-408e-a9d0-a53063c32382` | TODO / router-claimed | independent review pinned to immutable commit `3e7f5752c2` |
| `7cc4ab4c-ae16-4eb7-9409-4ce5ff179d77` | FAILED | batch-02 census; no provider account or current manifest pin |
| `235e5119-061d-406a-a58c-4d7d6cd3535a` | FAILED | batch-02 census; empty unactionable row |

The authoritative full reasons and absolute evidence paths are in
`2026-09-12_blocked_backlog_owner_dispositions.json`; the two-stage apply receipts
are `2026-09-12_blocked_backlog_owner_dispositions_apply.json` and
`2026-09-12_blocked_backlog_owner_dispositions_remaining_apply.json`.

The final dry-run census is 69: 18 future allocation candidates, 50 exact holds,
and the untouched OWNER-video row. The 50 exact holds split into 47 invalid/missing
target-symbol contracts, two identity conflicts, and one ambiguous exact approved
card (`QM5_1157`). Evidence is
`2026-09-12_blocked_backlog_batch02_final_plan.json`.

## Verification

- `pytest test_blocked_agent_task_sweeper.py test_governed_magic_allocator.py`: **17 PASS**
- `py_compile blocked_agent_task_sweeper.py`: **PASS**
- batch-02 registry apply: **32 active rows added, 0 retired rows deleted**
- allocator post-check: **0 status-aware magic collisions**
- 24/24 OWNER rows journal-bound; 22/22 archive prefixes; 21/21 non-empty prior
  verdicts retained inline; artifact fields unchanged
- no task deletion, no video action, no T_Live/FTMO action, and no test launch

## Review disposition

`REVIEW`: accept the sweeper, batch-01/batch-02 registry changes, and exact OWNER
dispositions. Subsequent scheduled cycles may process at most ten newly ready
registry/magic builds after a fresh precheck. The 50 exact holds remain fail-closed
until their named card or identity defects change; the video row remains OWNER-only.
