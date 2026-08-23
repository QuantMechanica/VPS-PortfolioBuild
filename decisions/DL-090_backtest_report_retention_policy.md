# DL-090 — Backtest Report Retention: keep merit and every standing rejection, compress the kept set

**Date:** 2026-08-23
**Status:** ADOPTED (OWNER-authorized)
**Authority:** OWNER, 2026-08-23, in chat: *"B′ + C, setz die Regel fest"* — ratifying the
recommendation in `docs/ops/evidence/2026-08-23_strategy_archive_matrix_prototype.md` §5.2 after
asking whether old backtests are deleted automatically.
**Scope:** the native MetaTrader 5 backtest artifacts under `D:\QM\reports\**`. No verdict, no
gate criterion, no database row is touched by this policy. The `*.log` journal purges
(`reports_log_purge.ps1`, `prune_workitem_logs.py`) are unchanged and remain the disk-pressure
control.

## 1 · The problem this closes

There was **no retention decision at all** for `report.htm`. Measured 2026-08-23:

- Both automated purges delete **only** `*.log` and explicitly keep `.htm` / `.json` / `.set`.
- Yet **no report directory older than 2026-07-07 exists**: 20.057 directories, 69 GB. Sampled by
  work-item id — May 0/300, June 0/300, July 87/300, August 240/300.
- Cause: the **one-time manual disk reclaims** of the D: crises (2026-06-10, 405 GB;
  2026-07-22, 153,7 GB) removed whole trees. Not the documented rules.
- Result: **17.468 of 111.396 runs (15,7 %)** still have a native report; last 30 days 95 %,
  before 2026-06-01 zero.

The evidence therefore survived by accident and vanished by accident. The concrete cost is on the
board: `QM5_13213 | XAUUSD.DWX` carries a single `Q02 = RETIRE` row with no `verdict_reason` and no
surviving artifact, so whether that rejection was a genuine no-signal or a session/parameter
artifact **can only be answered by re-running it** (`QM-TODO-20260823-504`).

## 2 · The rule

**Keep indefinitely** — the *kept set*:

1. **Every run of the PASS family.** Verdict starts with `PASS` (`PASS`, `PASS_SOFT`,
   `PASS_LOWFREQ`, `PASS_PORTFOLIO`), including superseded attempts. After a rebuild creates a new
   EA identity, the earlier PASS is exactly the comparison evidence.
2. **Every standing rejection.** The latest run per `(ea_id, symbol, gate)` whose clean-view
   taxonomy is `strategy` and whose verdict is not a PASS. This is the run that makes the archive
   cell red today; while it stands, it must be auditable at trade level.

**Age out** — everything else: superseded attempts of an already-rejected cell, and every run whose
taxonomy is `infra` or `invalid` (a burnt run carries no judgement and is never evidence for
anything). Minimum age before removal: **30 days**, so requeue, adjudication and the stranded-INFRA
sweep all complete inside the window.

**Compress** the kept set after **30 days** (gzip; HTML compresses roughly 10:1). Compressed
artifacts stay linkable from the archive detail page.

**Artifact set per kept run:** `report.htm`, `summary.json` / `aggregate.json`, `tester.ini` and
the `.set` file. Journals (`*.log`) remain outside this policy and keep their 12 h purge.

## 3 · Measured volume

| | Runs | Share |
|---|---:|---:|
| Total runs | 111.396 | 100 % |
| PASS family (all attempts) | 26.633 | 23,9 % |
| Standing rejections | 11.019 | 9,9 % |
| **Kept set** | **37.652** | **33,8 %** |
| Aged out | 73.744 | 66,2 % |

Of the 17.468 runs that still have an artifact on disk today, **12.190 fall in the kept set** and
5.278 age out. Measured artifact size: ~468 KB per file, ~2,2 files per run.

At the current accrual of ~2,5 GB/week for all reports, the kept set is **~0,85 GB/week ≈ 44
GB/year raw, ≈ 4–5 GB/year after compression**.

> **Correction to the figure quoted to OWNER before ratification.** The recommendation was
> presented as "~18,7 % of runs, under 3 GB/year compressed". That share was computed on *cells*
> (latest state per `(EA, symbol, gate)`), not on *runs*. On runs the kept set is **33,8 %**,
> because rule 1 keeps every PASS attempt and not only the standing one. The decision is unchanged
> — the cost stays small — but the record carries the correct number.

**The tightening option, if volume ever binds:** restrict rule 1 to the *standing* PASS per cell.
That reduces the kept set to ~18,5 % of runs. It is deliberately **not** adopted now, because
compression makes the difference immaterial and superseded PASS evidence is what a rebuild
comparison needs.

## 4 · Fail-closed requirements for the implementing job

1. **Never delete without a live classification.** If the database is unreachable, or a run cannot
   be classified against the rule, the artifact is **kept** and the job reports it.
2. **Quarantine before deletion** (mirroring `_purge_quarantine_*` practice), with a retention of
   at least one run cycle, and a `--dry-run` that prints the full delta.
3. **Never traverse** `C:\QM\mt5\T_Live`, the live-book evidence, `decisions/`, or anything under
   `D:\QM\reports\state`.
4. **Report what it removed**, per class and in bytes, into a log next to the other purge logs.
5. **Recompute the standing rejection at every run** — a cell that flips from FAIL to PASS, or
   whose rejection is superseded by a newer attempt, changes which artifact is protected.
6. A run still `pending`, `active` or `claimed` is never touched.

## 5 · Interaction with other decisions

- **SH-2 (artifact identity per run,** `docs/ops/FARM_DB_SCHEMA_HARDENING_2026-08-23.md`**)** —
  once `ex5_sha256` is mandatory, the kept set becomes identity-bound and a stale PASS can be
  recognised as such instead of being protected forever by its verdict alone.
- **Strategy Archive detail page** (`QM-TODO-20260823-505`) — the page must keep saying
  `report purged` where an artifact is gone. This policy stops the loss going forward; it does not
  resurrect the 2026-05/06 trees, which are unrecoverable.
- The `*.log` purges stay exactly as they are. This policy adds no disk pressure control and must
  never be used as one.

## 6 · Non-goals

No verdict is rewritten, no gate criterion changes, no candidate pool is redefined, nothing under
the live account is touched. Deleting artifacts of the aged-out class does not delete the run: the
row in `work_items` and its extracted numbers in `ea_metrics` remain permanently.

## 7 · Rollback / supersession

Reverting to "keep everything" is a one-line change to the classifier and costs disk, not
evidence. Tightening to standing-PASS-only (§3) requires a new ADR, because it removes evidence
this decision deliberately protects. This decision supersedes nothing; it fills a gap that had no
prior rule.

**Implementation:** commissioned as router task `b24d7875` (`QM-TODO-20260823-506`).
