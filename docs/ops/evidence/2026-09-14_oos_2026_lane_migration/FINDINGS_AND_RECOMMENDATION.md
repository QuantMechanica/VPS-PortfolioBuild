# OOS-2026 campaign: lane-migration investigation — no safe apply this cycle

Ticket `53d15c01-db62-4a81-8c09-9d4751d239c8`. Read-only throughout: no DB write, no
`--apply`, no terminal start. All DB facts below are from live, read-only `SELECT`
queries against `D:/QM/strategy_farm/state/farm_state.sqlite` (`mode=ro`), verified
independently (not just taken from the research handoff).

## Part 1 of the ticket — window repair — already done, re-verified stable

`docs/ops/evidence/2026-09-13_oos_2026_reenqueue/` documents an apply on
2026-09-13T21:06:00Z. Live re-verification today:

- 70 total campaign rows (`payload_json->>'$.diagnostic_campaign_id' = 'oos-2026-confirmation-v1'`,
  the actual field — not the top-level `campaign_id`, which is null on these rows).
  55 `pending/NULL` (37 patched + 3 unchanged-tainted + 15 minted successors), 15
  `done/REVIEW_REQUIRED` (untouched, still carrying the separate 2026-09-13T16:01Z
  INVALID_EVIDENCE review-lane disposition). Matches `repair_receipt.json`'s counts
  exactly.
- Spot-checked one patched row: `from_date=2026.01.01 to_date=2026.04.06`,
  `campaign_plan_sha256=6ade6b3491dabe74773abc2bfb31d597f48db78f01ece41759667b9b5088dfad`
  — matches the ticket's cited sha.
- `OOS_WINDOW_MISMATCH` holds: zero rows show this code today, but this is **not** a
  discrepancy — `work_item_holds.work_item_id` is the primary key (one slot per item,
  not a history table). Traced via `events`: `21:06:54Z work_item_hold_released`
  (the window repair) followed 38 minutes later by `21:44:03Z
  news_calendar_taint_hold`, which overwrote the same row's `hold_code` in place
  (`ON CONFLICT(work_item_id) DO UPDATE ... WHERE active=0`). **Release confirmed
  37/37 via the append-only `events` trail, not inferred from the hold table's current
  snapshot.**

**This part of the ticket is done and needs no further action.**

## Part 2 — Q09_NEWS → Q10_NEWS lane migration — investigated, not applied

### Finding 1: the cited precedent is not a lane-migration tool

The ticket's evidence pointer ("the lane closure today, commits `ac67e36f1f`/
`737207452a`/`b9daf49ec8`, `apply_q09_news_review_dispositions.py`, is the pattern for a
governed lane migration") does not hold up under a full read of all three commits:

- `ac67e36f1f` ships the news-impact-mapping v2 module, default-off, no `phase` writes.
- `737207452a` (`apply_q09_news_review_dispositions.py`) and `b9daf49ec8`
  (`apply_q10_news_review_dispositions.py`) both adjudicate the **historical review
  backlog** — `WHERE phase=? AND status='done' AND verdict='REVIEW_REQUIRED'` — minting
  disposition receipts (`CONFIG_LOCKED`/`INVALID_EVIDENCE`) for rows that already ran.
  **Neither writes to `work_items.phase`, and neither touches `pending` rows.** Grepped
  both full diffs for `SET phase`, `phase='Q10_NEWS'`, `lane_migrat` — zero matches.

These are "governed tool" precedent in the general sense (plan/apply split, backup,
append-only receipts) — not a reusable phase-migration function, and not applicable to
this campaign's 55 **pending, unverdicted** rows.

### Finding 2: in-place phase rewrite is architecturally forbidden, not just risky

Verified directly against the live schema:
```sql
CREATE TRIGGER trg_work_items_phase_immutable
    BEFORE UPDATE OF phase ON work_items
    WHEN OLD.phase IS NOT NULL AND trim(OLD.phase)<>'' AND NEW.phase IS NOT OLD.phase
    BEGIN SELECT RAISE(ABORT, 'work_item phase is append-only; append a successor'); END
```
Any `UPDATE work_items SET phase='Q10_NEWS' WHERE ...` on these 55 rows (all of which
have a non-null `phase`) **hard-fails with a SQLite `IntegrityError`** — this is not a
policy choice a tool could work around; the database itself refuses it. The only DB-legal
pattern is minting brand-new `phase='Q10_NEWS'` successors with explicit lineage back to
the Q09_NEWS originals (the same append-only-successor pattern the window repair itself
already used for its 15 successors) — and then deciding what happens to the Q09_NEWS
originals (retire/hold/supersede), which is unspecified anywhere in the ticket or its
evidence.

### Finding 3: no such tool exists yet, and the target payload shape is a real open question

Searched `tools/strategy_farm/session_tools/` and `tools/strategy_farm/` broadly —
nothing beyond the already-applied `apply_oos_2026_reenqueue_0913.py` references
`oos_2026`/`oos-2026`; `oos_2026_confirmation.py`'s only CLI surface is
`repair-basket-payload` / `repair-oos-window` (used) / `report-misphased-rows`
(read-only). No `q09_to_q10`/`lane_migration`/`news_lane` migration tool exists.

Live Q10_NEWS rows (322 in the DB) carry a structurally different payload shape than this
campaign's Q09_NEWS diagnostic rows — `promoted_from_phase`, `promotion_source`,
`q09_activation_state`, `q09_autoseal_failure`, `smoke_year_count` (the normal
Q08→admission cascade shape) versus this campaign's `diagnostic_campaign_id`,
`diagnostic_non_admission`, `q09_dispatch_binding_sha256`, `q09_run_plan_path` (a
diagnostic, non-admission shape). A diagnostic campaign row doesn't naturally arise from
the Q08→Q09→Q10 admission cascade that produces the Q10_NEWS-native fields, so a
migration tool cannot simply copy the Q09_NEWS payload onto a new Q10_NEWS row — it needs
an explicit decision about which Q10_NEWS-native fields (if any) a diagnostic,
non-admission successor should carry, or whether the NEWS runner needs a
`diagnostic_non_admission`-aware code path at all. **This design decision is not made
anywhere in the ticket, its evidence, or the codebase**, and choosing one unilaterally
here — on a task whose only hard limits are "append-only" and "no gate criteria
changes" — risks getting the NEWS-lane admission semantics wrong under time pressure.

### Finding 4: even a correct migration would not unblock execution today

Live, re-verified: **all 55 pending campaign rows currently carry an active
`NEWS_CALENDAR_TAINTED` hold** (`news_calendar_taint.py`'s 10-minute sweep,
`tools/strategy_farm/config/news_calendar_taint.v1.json`: `enabled: true`, tainted
calendar-bundle sha `86b2c0b5...`, `lift_condition`: E1-C acceptance or a full
remeasurement seal — neither has happened). This containment reasserted itself within
1–38 minutes of the 09-13 window-repair apply and is independent of, and in addition to,
the lane-mismatch problem. **This is exactly the "calendar containment (taint sweep)"
the ticket asks the receipt to name** — recorded here since no apply/receipt was produced
this cycle to carry it.

## Decision: no apply this cycle

Given (a) in-place mutation is DB-blocked by design, (b) no reusable or even
purpose-built dry-run tool exists for this specific migration, (c) a real, unmade design
decision (Q10_NEWS-native payload shape for a diagnostic successor / disposition of the
Q09_NEWS originals) sits in the middle of it, and (d) the calendar-taint containment
independently blocks execution regardless — building and applying a brand-new
phase-migration mutation in a single pass, with no dry-run precedent for this exact
operation, would not be prudent on a NEWS-admission-adjacent pipeline component. This
matches the same judgment the 09-13 README itself made when it explicitly deferred this
exact lane migration as "a follow-on orchestrator ticket, not part of the window
re-enqueue."

**Recommendation for the next ticket**: (1) an OWNER/Codex decision on the Q10_NEWS
successor payload shape for diagnostic/non-admission campaign rows; (2) a
`repair-oos-window`-shaped two-step tool (`report-` read-only plan → `--apply`, pre-lock
backup, `FactoryMutationLock` + `_connect_under_mutation_lock` short timeout, CAS guards,
append-only successor + supersede-edge writes, atomic non-clobbering receipt — the exact
pattern already proven safe by the 09-13 apply); (3) explicit disposition for the 55
Q09_NEWS originals once successors exist; none of this is time-critical today since the
calendar-taint containment blocks execution regardless of lane.

## RESULT line for `docs/ops/OPEN_ITEMS_STATUS.md` (draft)

> **OOS-2026 lane migration (53d15c01)**: window-repair part CONFIRMED done and stable
> (live re-verified: 70 campaign rows, 55 pending correctly windowed, 37
> `OOS_WINDOW_MISMATCH` holds released — confirmed via `events`, not just the hold-table
> snapshot). Lane-migration part NOT APPLIED this cycle: the cited precedent
> (`ac67e36f1f`/`737207452a`/`b9daf49ec8`) is not actually a phase-migration tool (verified
> by full diff read, zero `phase=` writes in any of the three); in-place phase rewrite is
> DB-blocked by `trg_work_items_phase_immutable` (verified live); no dry-run tool exists
> for this migration; the Q10_NEWS-native payload shape for a diagnostic successor is an
> unmade design decision. Also: all 55 pending rows are, right now, independently blocked
> by an active `NEWS_CALENDAR_TAINTED` hold (taint sweep, unlifted) — a correct lane
> migration would not unblock execution today regardless. Recommend routing the design
> decision + tool build as its own ticket. Evidence:
> `docs/ops/evidence/2026-09-14_oos_2026_lane_migration/`.
