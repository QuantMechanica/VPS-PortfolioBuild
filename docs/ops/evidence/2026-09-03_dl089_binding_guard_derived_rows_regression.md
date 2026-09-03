# DL-089 binding guard froze programs at PATTERN_SELECTION_READY — regression fix

Date: 2026-09-03 00:15Z · Author: Claude (CEO loop, OWNER standing order 2026-09-02)
Authority: Stehende Vollmacht GRÜN — infra repair that does not touch verdict logic;
test first, rollback documented, blast radius named. No gate criterion, threshold,
verdict, status or trade stream was edited.

## Finding

The 24 pending `Q12` rows on the board are not worker runs. They are DL-089 pattern
programs held under `Q12_DL089_MATRIX_WORKER_ROLLOUT_PENDING` (release_on_restart)
and are finalised by the matrix service from sealed census evidence
(`_finalize_from_terminal_ledger`, release note "DL-089 matrix completed from sealed
cell evidence"). Progress therefore equals census-cell progress per program.

Census state at 23:50Z (cells per program, 1,085 annual each): 13 programs carry
cells, 11 have none yet (incl. QM5_21501/USDJPY and QM5_13013/NDX, admitted today).
`DL089_QM5_13054_XTIUSD_DWX_2019_2025` had resolved its full annual matrix
(445 MEASURED + 640 SKIPPED_EXCLUDED = 1,085), measured its four WF-combo rows
(11:23Z–12:12Z) and reached driver state `PATTERN_SELECTION_READY` — yet every pump
cycle since `pump_task_20260902T125801Z.log` deferred it with

```
PROGRAM_Q12_REBIND_REFUSED: program=DL089_QM5_13054_XTIUSD_DWX_2019_2025
requested=a5b90e08-… cell_q12=['a5b90e08-…'] parent_task=['', 'a5b90e08-…']
```

Root cause: the ownership guard added 2026-09-02 (`8d57f98150`, task 0058a401, for the
QM5_10706 double-Q12 incident) compares **every** `OPT_CENSUS` row carrying the
program id against the 1,085 declared annual cells. The census driver legitimately
appends rows after the annual matrix resolves:

| row class | cell_key | parent_task_id | payload Q12 binding | live example |
|---|---|---|---|---|
| WF-combo | `…:wfN:combo:YEAR` | NULL | absent | 13054 (4 rows), 11421 (4) |
| numeric / final-fullwindow | `…:numeric:…`, `…:final_fullwindow:…` | NULL | present | 11421 (70 + 2) |
| driver INFRA_FAIL rerun | declared key, new UUID, `append_only_rerun_of` | NULL | present | 1537 `08767105` ← `d110b111` |

Each class fails `parent_bindings == {q12_id}` and/or the exact 1,085-UUID identity
check. QM5_11421/EURUSD finalised at 07:30Z only because its derived rows predate the
guard. Every later program would have frozen at exactly the moment it becomes
selectable — a critical-path defect for the 25-pair target.

## Fix (`e08b4eeaba`)

`_program_binding_guard` now partitions the program's rows into declared annual rows
(UUID in the declaration), driver reruns (declared cell_key + `append_only_rerun_of`)
and derived rows (cell_key outside the declaration). Ownership is proven by the
declared rows alone (exact UUID/key set, `parent_task_id`, payload Q12 + declaration
hash). Rerun/derived rows never transfer ownership, but any binding they carry must
still name the same Q12 owner and declaration; a declared cell_key with a new UUID and
no rerun lineage remains `PROGRAM_CELL_IDENTITY_MISMATCH`. The guard result now
reports `declared_cell_count`, `rerun_row_count`, `derived_row_count`.

Verification:

- `tools/strategy_farm/tests/test_dl089_matrix_service.py`: two new tests
  (`test_binding_guard_admits_driver_derived_rows_and_reruns`,
  `test_binding_guard_still_refuses_foreign_or_unexplained_rows`); the existing
  refusal test for the 10706 shadow row is unchanged → 14 passed.
  `test_matrix_service_materializes_declared_cells_with_bounded_window` fails
  identically on HEAD before the fix (environment-coupled: `effective_limits(10)` gives
  G_eff = K·L = 4 on this host, test expects 6) — pre-existing, not touched.
- Live read-only dry-run of the guard after the fix: 13054 → OK
  (1,089 rows = 1,085 declared + 4 derived, `requires_restamp=False`); 1537 → OK
  (1,086 = 1,085 + 1 rerun).
- Rollback: `git revert e08b4eeaba` (pure code; no DB or artifact change).
- Blast radius: matrix-service guard only; the pump picks the working tree up on its
  next cycle.

## Same round: Q10 lineage wave 2, QM5_11910/NZDUSD

- Exact Q08 rerun `6757567a` (binary 40fc2b90…) → **FAIL_SOFT** with the same
  EDGE_SOFT profile as its 2026-07-24 predecessor (8.4 seasonal, 8.6 chopping block,
  8.7 PBO 51%, 8.10 low-vol regime; cost cushion 9.9 PASS; 63 trades). FAIL_SOFT is an
  admitted replacement source in `_spawn_q09_replacements_for_regenerated_q08_once`.
- The old news row `dd7b14a0` was parked under `NEWS_RUNNER_SPAWN_SILENT_ABORT`. Its
  review requirement was closed by `2026-09-02_q10_news_spawn_abort_forensic.md`
  (cause: missing bound Q08 aggregate, deterministic launch fault). Because
  `work_item_holds` keys one hold per work item, the row could not be armed with
  `Q09_AWAITING_SEALED_PLAN` (`conflicting_active_hold`, and after a release
  `conflicting_inactive_hold`). Added `governed_work_item_hold.py
  --supersede-hold-code <PRIOR>` (`e2dc0bd14a`): audited in-place re-arm inside the
  same `BEGIN IMMEDIATE`, row never claimable in between, full prior hold document in a
  `governed_hold_superseded` event; any other existing code still aborts. Tests 6/6.
- Applied 23:56:38Z (backup `farm_state_before_governed_hold_20260902T235627Z.sqlite`,
  sha 92c367eb…). Pump cycle 23:58 spawned replacement `a6dbacf5`
  (`q09_autoseal_regenerated_q08`) at 00:00:55Z, `dd7b14a0` → SUPERSEDED, sealed plan
  bound, claimed by T7 at 00:06Z. Q10 CONFIG_LOCKED pairs unchanged at 23 until it
  completes.
- Remaining silent-abort rows (11129/SP500 `745671a4`, 10700/XAUUSD `77bd97c2`,
  12710/XTI, 11422/USDCAD, 11288/USDJPY) follow the same recipe once their exact
  Q07/Q08 reruns land; 11129/10700 Q07 reruns sit at claim positions ~1,285 behind
  the priority-tracked census cells of 41161/41097 (Amendment B, Sunday package).

## Queue facts recorded for the Sunday package

- Top-down order at 23:55Z: 10,945 pending unheld rows; positions 1–1,280 are census
  cells (41161: 743, 41097: 504, sibling seeds) — all `priority_track`. Lineage
  reruns with `priority_track` rank after them (Q07 rerun of 11910 waited 6.7 h).
- Pump cycle 23:58 ran 365 s (budget 360): reviews_and_research 109 s,
  queue_maintenance_and_intake 95 s, build_dispatch 70 s, dl089_matrix_service 49 s,
  news_expansions 23 s. No stage skipped.

## Addendum 01:00Z — second blocker (service self-deadlock) and verified outcome

The first pump cycle with the guard fix (`pump_task_20260903T001801Z.log`) admitted
QM5_13054 and wrote `q12_selection_receipt.json` (verdict NO_FILTER_CHANGE, 00:28:57Z),
but the stage ran 673 s and ended `DL089_MATRIX_SERVICE_FAILED:database is locked`;
every later stage was skipped (`cycle_budget_exhausted`), worker claims starved
(fleet 24 → 14 cells/10 min) and the transaction rolled back (row still pending).
Cause: `_finalize_from_terminal_ledger` took the RESERVED lock on the service's outer
connection (compare-and-set + hold release) without committing; `census.boost` /
`selector.advance` of the NEXT governed program open their own connections with
`BEGIN IMMEDIATE`, waited until their busy timeout, and the write-retry wrapper re-ran
the whole pass (py-spy on the 00:33Z cycle: `boost (opt_census.py:732)`, idle). That
cycle was killed (rollback is the same outcome; lock released, claims resumed within
seconds). Fix `c230995ae8`: commit right after the completion + hold release (atomic
unit unchanged); regression test with a second connection. Historical note: the
11421/EURUSD finalisation at 07:30Z only succeeded because no further program followed
it in that pass (that cycle still took 1,399 s).

Verified: cycle `pump_task_20260903T003801Z.log` 330 s, matrix stage 46 s, `finalized`
block present; DB: Q12 `a5b90e08` done/NO_FILTER_CHANGE 00:39Z, rollout hold released
("DL-089 matrix completed from sealed cell evidence"); Q13 `83c1e21f` NO_PARAMETER_CHANGE
00:49Z via optimization_fork_service; Q14 expected in the following cycle.

`book_build_guard --status --venue both` (01:00Z): `qualified_pairs = 2`
(QM5_10706/GBPUSD, QM5_11422/USDCAD — contiguous through Q14). rebaseline_census map of
the 24 held Q12 pairs: 13054/XTI contiguous to Q13 (→ 3rd pair after Q14); 13 pairs
contiguous to Q11 and missing only the Q12 program: 1537 (78 cells left), 21507 (606),
11881 (954), 20266 (873), 10513 (976), 20048 (1,085), 21505 (1,049) with cells;
12855/9641/12849 with approved siblings (41305/41306/41307, Q02 PASS) waiting for a
program slot (K=8); 21501/USDJPY, 13013/NDX, 10403/XAUUSD, 11660/NDX without any
`_opt` sibling → Codex task `57bc396f` (P85, sibling wave 2). 11421/EURUSD is
contiguous only to Q09 (legacy Q10 STALE) until its news continuation on T2 locks.
Two of the eight program slots (10706, 11422) measure second-pass programs for pairs
that already count — a slot-order decision for the Sunday package, not changed tonight.
