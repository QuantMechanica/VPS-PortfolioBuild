# OWNER decision 2026-09-03 — pre-0803 recompile wave, DL-089 slot order, Amendment B

Recorded by Claude (CEO loop) at 02:12Z. Chat receipt (OWNER, 2026-09-03 ~02:08Z, German):

> „Da alles (Recompile-Welle Pre-0803 (+3 Paare möglich), Slot-Reihenfolge (2 von 8
> Zensus-Slots messen Zweitpässe bereits zählender Paare), Amendment B (Lineage-Reruns
> hinter ~1.300 priorisierten Zellen)), vor allem die Recompiles, können wir heute bereits
> angehen und dementsprechend priorisieren!"

Decision id: `OWNER-DEC-PRE0803-RECOMPILE-SLOTORDER-AMENDB-20260903`. All three items were
Sunday-package Vorlagen in `docs/ops/OPEN_ITEMS_STATUS.md` (addenda 01:00Z–01:55Z); the OWNER
pulled them forward and ranked the recompiles first. Nothing here touches T_Live, AutoTrading,
gate thresholds, verdicts or the live book.

## 1. Recompile wave PRE-0803 (priority 1)

Class: `.ex5` binaries compiled before commit `f0102fbcf` (2026-08-03, `QM_NewsFilter.mqh`
provenance inputs `qm_news_calendar_bundle_id` / `_expected_sha256` /
`_common_relative_path`) fail every Q10_NEWS cell with
`MT5 report effective input qm_news_calendar_bundle_id mismatch`
(proven live 2026-09-03 00:33Z on QM5_11910 replacement `a6dbacf5`; class documented in
`2026-08-24_qm5_9936_news_provenance_include_revision.md`).

Approved scope (the "+3 Paare" of the Vorlage): **QM5_11910/NZDUSD, QM5_10700/XAUUSD,
QM5_12710/XTIUSD** (all `.ex5` 2026-07-24, chains contiguous through Q09, only Q10 missing).

Same class, found by the 02:10Z scan of the 64 pairs without a CONFIG_LOCKED Q10 (ex5 mtime
< 2026-08-03): QM5_10815/GDAXI (07-26, contiguous Q09), QM5_12580/AUDUSD (07-14, contiguous
Q08), QM5_13036/GDAXI (08-02, class INVALID), QM5_9510/XAUUSD (07-07, class INVALID),
QM5_12357/GDAXI (07-11, chain broken at Q03). 10815 and 12580 are proposed as batch 2
(same recipe, no extra decision needed beyond this note); 13036/9510/12357 stay out until
their INVALID/MISSING chain state is reviewed.

Mechanics (23.08. identity rule): a rebuilt EX5 is a **new identity from Q02**; the old rows
stay as evidence (append-only). Path: `compile_work_items.force_rebuild_allowlist` gains a
third OWNER-bound allowlist (`PRE0803_NEWS_PROVENANCE_FORCE_REBUILD`, owner reference
`OWNER_DECISION_2026-09-03_PRE0803_NEWS_PROVENANCE_RECOMPILE`, waivable reasons unchanged:
`EX5_ALREADY_PRESENT`, `WORK_ITEMS_EXIST`, `BOUND_SETFILE_HASH_EXISTS`) →
`farmctl enqueue-compile <label>` → `release_compile_wave.py --apply` → resident-worker
compile → COMPILE_OK → fresh Q02 for the new identity (`enqueue-backtest --ea … --phase Q02`
with the new `--expected-current-ex5-sha256`, no `--target-symbol`) → cascade Q03…Q10.
The 9936 precedent (`300c007a`, 2026-08-24) failed exactly at `CANDIDATE_RECHECK_REFUSED`
because no allowlist covered it — that is what the allowlist fixes.

Cost: one full Q02–Q10 chain per pair (~1–2 factory days each at current pace, interleaved
with the census); benefit up to +3 pairs (batch 1) / +5 (with batch 2).

## 2. DL-089 program slot order (priority 2)

K = 8 program slots. Two are occupied by second-pass programs of pairs that already count
(QM5_10706/GBPUSD `1a92b33e`, QM5_11422/USDCAD `f9e1f7fc`), while Q11-contiguous pairs
whose only missing gate is Q12 wait (`PROGRAM_SLOT_WAIT:K=8`: 20048, 21505, 12855, 9641,
12849; 21507/11881/20266/10513/10145 are in slots). Decision: order the governed program
queue by "adds a pair to the counter first" — Q11-contiguous pairs before second passes.
Mechanics: `dl089_matrix_service._queue_order` sorts by `payload.queue_order_at` (fallback
`created_at`); a governed tool sets `queue_order_at` on exact Q12 row ids (backup,
`BEGIN IMMEDIATE`, events row, dry-run/apply) — queue-order only, no status/verdict change;
cells already measured for 10706/11422 stay and resume when a slot frees.

## 3. Amendment B — lineage reruns before priority-tracked census cells (priority 3)

Under OWNER-DEC-TOPDOWN-PRIORITY-20260828 the claim order is universe_expansion →
recovery → priority_track → gate rank (census = 0) → …; a priority-tracked exact Q07/Q08
rerun therefore ranks behind ~1,300 priority-tracked census cells (41161/41097) and waited
6–7 h (QM5_11910 Q07 rerun) while it is the critical path to a Q10 lock. Decision: add a
rank key immediately after `_recovery_rank`: exact append-only lineage reruns
(`payload.append_only_rerun = 1`, `priority_track = true`, phase Q03–Q09) rank ahead of
all other priority-tracked rows. Sibling Q02 prerequisite seeds (Option A, rank −1 inside
the gate key) are unaffected. Blast radius: claim order only; verified by
`tools/strategy_farm/tests/test_opt_census_dispatch.py`.

## Execution log

- 02:12Z decision recorded; implementation of 1–3 commissioned to Opus agents in isolated
  worktrees with adversarial verification (workflow `pre0803-slot-amendb`), CEO merges.
- Follow-ups are appended below as they complete.
