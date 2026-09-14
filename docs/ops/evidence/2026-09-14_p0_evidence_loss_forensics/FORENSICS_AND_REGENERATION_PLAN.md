# P0 evidence loss — forensics + regeneration plan

Ticket `79d1c0fa-e7b2-4178-8535-f8a97db9d94d`. Read-only throughout: no baseline
rewrite, nothing enqueued, no terminal64.exe started, `artifacts/evidence_cohort_baseline.json`
(currently mid-append by the `QM_EvidenceCohortWatch_Daily_0420` scheduled task,
uncommitted, purely additive per `git diff --stat`) was read but not touched or committed.

## Builds on

`docs/ops/evidence/2026-09-13_health_cohort_loss_and_ftmo_errors.md` (commit
`485584198e`) already fixed the dominant false-positive class (857 `.gz`-aged rows the
watcher checked by literal path) and identified 172 genuinely-missing report directories,
95 of them PASS-family. This ticket forensically breaks down that 172 and delivers a
regeneration plan.

## 1. The 172 split into three cleanly separated, non-overlapping groups

Read directly from the watcher baseline's latest observation
(`checked_at_utc: 2026-09-14T02:20:07Z, evidence_file_missing: 172`) and verified against
disk (`stat` on every report-root/evidence-leaf path) and against
`D:\QM\reports\_retention_quarantine\*`:

| Group | Count | PASS-family | Explanation |
|---|---:|---:|---|
| A. Retention quarantine, recoverable | 16 | 0 | Correctly age-out-quarantined by `report_retention.py` (DL-090 §2); still present under `_retention_quarantine\<snapshot>\<rel_path>`, snapshot dates 2026-08-31 through 2026-09-11 line up 1:1 with `report_retention.log`'s `QUARANTINED` entries |
| B. Pre-existing small trickle | 27 | 0 | FAIL/FAIL_SOFT/ZERO_TRADES only, scattered 2026-08-23/24/25/28, not in quarantine, not in the group-C cluster — an earlier, separate phenomenon |
| **C. The 2026-08-31 bulk event** | **129** | **95 (100% of all PASS losses)** | 34 FAIL/FAIL_HARD + all 95 PASS, leaf-dir/`raw/run_NN` mtimes clustered **2026-08-31T15:19:06–15:21:22Z** (one ~2m16s window) |

**All 95 PASS-family losses trace to exactly one dated incident**, not an ongoing
process — this materially narrows what the fail-closed guard (below) needs to cover.

Verdict breakdown of the full 172 (from the baseline JSON directly): PASS 95, FAIL 61,
FAIL_HARD 6, ZERO_TRADES 8, FAIL_SOFT 2.

## 2. The 2026-08-31 event — precisely dated, mechanism not conclusively identified

**Verified directly** (read-only `stat`, both on the disk and via `report_retention.log`):
content (summary.json at the leaf; report.htm + tester.ini inside each `raw/run_NN`) was
deleted **in place** — directory shells survive, ruling out `shutil.rmtree`/directory
removal. Local timezone confirmed W. Europe Standard Time, +2h DST active that date, so
15:19–15:21 UTC = 17:19–17:21 local.

A confound was checked and excluded: ~20 of 30 sampled *intact* PASS rows also show a
directory-entry mtime touch at the same time, but their file content is untouched —
consistent with a co-occurring, harmless `*.log`-only sweep walking most of the tree at
that time. This is not part of the incident; it only fixes the *when*, not the *what*, so
it was not used as evidence beyond dating.

**Candidates ruled out by direct code inspection** (each read in full, not taken on
prior-doc trust alone):

| Script | Why ruled out |
|---|---|
| `report_retention.py` (`--apply`, daily DL-090 job) | `classify()` recomputes fresh from the live DB every run; rule 1 (`if v.startswith("PASS"): keep.add(wid)`) is unconditional, no age gate, no code path can quarantine/unlink a PASS-classified file (confirmed: `report_retention.py:108-109`). Its 08-31 apply run is logged 02:23–02:24 UTC — 13 hours before the incident window. |
| `report_retention_purge.py` | `quarantine()` only ever processes `age_out_infra_invalid`/`age_out_superseded_strategy` classes, never `keep_pass_family`. Its `rmtree` only fires on paths already under `QUARANTINE_ROOT`. Its own log has 3 lines, all `DRYRUN`, dated 2026-08-23 — never run in `--execute` mode since. |
| `tester_cache_purge.ps1` | Confirmed by direct read: every `Remove-Item` target is gated by a `target_outside_tester_root` guard (`tester_cache_purge.ps1:555-557`) built from `$Mt5Root\T<n>\Tester\...` — structurally incapable of reaching `D:\QM\reports`. |
| `reports_log_purge.ps1`, `prune_workitem_logs.py` | Both strictly `.log`-filtered; cannot touch `.json`/`.htm`/`.ini`. |
| `continuous_retention_runner.py` (45-min scheduled task, started 2026-08-30, one day before the incident — checked precisely because of the timing proximity) | Its only `work_items`-tree interaction is `set_ntfs_compression()`, an in-place NTFS compression `DeviceIoControl` call — content/filename survive untouched. Its delete paths target `D:\QM\strategy_farm\logs`/`state\backups` only. |
| `rollback_batch.py` | Re-confirmed: its `shutil.rmtree` operates on `framework/EAs/QM5_*`, never report roots. |

**Suggestive but non-discriminating correlation, reported as such, not as a cause**:
`D:\QM\reports\state\tester_cache_purge.log` shows, inside the incident window, a
`TELEMETRY_ERROR reason=implausible_free_space_gain` — the script accounted for ~2.13 GB
of deletions (all inside `Tester\`) but D: free space rose ~14 GB in the same seconds, an
unexplained ~12 GB gap flagged by the tool's own telemetry validator. However this exact
telemetry error recurs **252 times between 2026-08-21 and 2026-09-14** — multiple times on
most days, including many loss-free days — so it does not discriminate this incident from
routine noise. Reported for a possible orchestrator-level follow-up, not as a finding.

**Windows Event Log: checked, unusable for this window.** Object-Access auditing is
nominally enabled but `D:\QM\reports` has no SACL configured (zero 4660/4663 events ever
recorded), and the Security log is circular with retention not reaching back past
2026-09-14 — it had already wrapped past 08-31 by the time this was checked.

**Conclusion: deletion mechanism NOT conclusively identified**, consistent with (and
reinforcing) the two prior RCA docs
(`2026-08-17_P0_evidence_loss_is_dated_not_ongoing.md`,
`2026-09-05_m05_evidence_loss_adjudication.md`) which independently reached the same
"not found" conclusion after excluding the same candidate set. Every scheduled,
documented process that both touches `work_items` and deletes was individually
eliminated by direct code inspection, not by trusting the prior docs' conclusions. A
residual tail of unscheduled/undocumented scripts under `tools/strategy_farm/` was not
exhaustively read and is the next place to look if the orchestrator wants to keep
searching before accepting "not found" as this ticket's terminal state on the mechanism
question — this ticket delivers the regeneration plan regardless of whether the mechanism
is ever found, per DL-090 (PASS evidence loss doesn't change the verdict; only the
report artifact needs replacing).

## 3. DL-090 PASS-exemption gap analysis

**No gap found**, confirmed by full code read of both retention scripts (not just the
grep above): `report_retention.py`'s classification is recomputed from the live DB on
every run (no caching across runs), so there is no race window between a verdict being
written and a stale purge decision acting on it — each run is atomic
classify→scan→act. An unresolvable `wid` fails closed to **kept**, never removed.
`report_retention_purge.py`'s move/delete code structurally never reaches
`keep_pass_family` rows. Direct behavioral corroboration: the 16 quarantine-recoverable
rows found in group A are **100% non-PASS** (13 FAIL, 3 ZERO_TRADES) — retention's
selectivity is observable in the same dataset, not just asserted from its source code.

## 4. Regeneration plan — sole-PASS cells

**Count discrepancy, reported not silently resolved**: the ticket states 81 sole-PASS
cells; a read-only re-derivation against `farm_state.sqlite` (grouping by
`(ea_id, symbol, phase)`, counting sibling `verdict LIKE 'PASS%'` rows) gives **72**,
stable across two different phase-grouping definitions tried. The `2026-09-13` doc's "81"
was computed by an uncommitted scratchpad script this investigation didn't have access
to. **Recommend re-deriving from a committed script before trusting either number** — 72
is reported here with full row-level detail so it is independently checkable; the
remaining 23 of the 95 PASS losses have a surviving sibling PASS row for the same cell
and are lower regeneration priority.

Phase mix of the 72: Q03=50, Q05=13, Q06=7, Q07=2. Full 72-row list (work_item_id,
ea_id, symbol, phase, date) is in `sole_pass_cells.csv` (this directory) — not enqueued.

**Command pattern per row** (flags confirmed present in `farmctl.py`'s `enqueue-backtest`
argparse block):
```
python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-backtest \
  --append-only-rerun-of <work_item_id> \
  --phase <phase> \
  --rerun-reason "P0 evidence regeneration, router task 79d1c0fa, 2026-08-31 loss incident"
```
No `--priority`/`--ram-class` flags exist on this subcommand — priority is a separate
`priority_track` payload boost (omitting it gives default/low, no queue-jump); RAM-class
handling is fully automatic at claim time inside `terminal_worker.py`. So "priority low,
RAM-class aware" describes this command's natural behavior as written, not additional
flags to pass.

**Tester-hour estimate**, phase-weighted from `D:/QM/strategy_farm/state/health.json`'s
`claim_to_complete_latency` check (24h sample, `p50=3.0min p90=11.1min p99=94.1min`,
blended across phases — a proxy for tester-hours including queue wait, not pure execution
time):
- 50 Q03 rows × p50 (3.0 min, fast screens) = 150 min
- 22 Q05–Q07 rows × p90 (11.1 min, heavier walk-forward/OOS gates run closer to the tail) = 244.2 min
- **Point estimate ≈ 394 min ≈ 6.6 tester-hours** (sensitivity range: all-p50 = 3.6h,
  all-p90 = 13.3h; p99 worst case 112.9h is unlikely — p99 reflects rare stalls, not
  typical Q05–Q07 duration)

**Not enqueued.** The orchestrator releases in waves per the ticket's own instruction.

## 5. Watcher baseline-refresh procedure

`evidence_cohort_watch.py --init` only ever **adds** entries not already present
(`if c["work_item_id"] in entries: continue`) — it structurally cannot rewrite an
existing entry, so there is no silent-rewrite risk from that direction today. Procedure
for after regeneration/quarantine-recovery:

1. Do not run `--init` to "clear" the 172 — it cannot remove entries by design, so
   nothing needs clearing; the historical loss record stays visible in `losses[]`.
2. Each regenerated row (via `--append-only-rerun-of`) is a **new** `work_item_id` with
   its own fresh `evidence_path`; a later `--init` picks it up as a new baseline entry,
   leaving the original lost entry's record untouched — correct and desired, preserves
   the forensic trail instead of erasing it.
3. For the 16 quarantine-recoverable rows, a human-approved restore (move the file back
   from `_retention_quarantine\<snapshot>\<rel_path>` to its original path) lets the
   *existing* baseline entry self-heal on the next scheduled check — no `--init` needed.
4. Never hand-edit `entries{}`/`losses[]` in the JSON directly — any legitimate baseline
   growth must go through `--init`/`cmd_check`'s own append-only code paths.
5. Housekeeping recommendation (not performed here): commit the currently-uncommitted,
   purely-additive baseline growth as its own dedicated commit before further scheduled
   runs pile more uncommitted history on top of it.

## 6. Fail-closed guard proposal

`D:\QM\reports` has no SACL configured today (zero delete-audit events ever, confirmed).
Concrete, actionable guard: set an audit ACE (success+failure, Delete/DeleteChild/WriteData,
Everyone) on `D:\QM\reports\work_items`, sized (or forwarded) to survive at least 7 days,
so a future incident is unambiguously attributable within the retention window — this is
the one check that would have worked here but wasn't provisioned. Complementary: shrink
the detection-to-incident window (currently up to 24h, the watcher's daily cadence) with a
lighter, more frequent (e.g. 15-min) canary sweep over a small always-PASS sentinel set.

## RESULT line for `docs/ops/OPEN_ITEMS_STATUS.md` (draft)

> **P0 evidence loss forensics (79d1c0fa)**: all 95 PASS-family losses (72 sole-PASS-of-cell
> by re-derivation — ticket cites 81, unreconciled, see evidence doc) trace to ONE dated
> incident, 2026-08-31T15:19:06–15:21:22Z, not an ongoing process. 16/172 recoverable from
> `_retention_quarantine`, 61/172 non-PASS trickle predates the incident. Retention
> (both scripts) and `tester_cache_purge.ps1` exonerated by full code read + log
> cross-check (no code path can touch PASS; script structurally can't reach
> `D:\QM\reports`); one suggestive but non-discriminating ~12GB telemetry anomaly noted,
> not conclusive (recurs 252x in 3.5 weeks including loss-free days). Deletion mechanism
> NOT conclusively identified after eliminating every scheduled/documented candidate —
> consistent with two prior RCAs on this same question. Windows Event Log unusable for
> this window (no SACL configured, log already wrapped past 08-31) — recommend adding
> one. Regeneration plan drafted for 72 confirmed sole-PASS cells (~6.6 tester-hours,
> range 3.6–13.3h) — NOT enqueued, pending orchestrator wave release. Evidence:
> `docs/ops/evidence/2026-09-14_p0_evidence_loss_forensics/`.
