# CEO stranding census + pump control-plane stall (2026-09-02, ~10:20Z)

Question from OWNER (2026-09-02, 10:0xZ): "Fehlen uns erfolgreiche Strategien? Sind welche
irgendwo versandet? Muss etwas erweitert werden? Gab es Shortcuts oder Vereinfachungen?"

Method: latest `work_items` row per (EA, symbol) over all gate phases (121,449 rows), classified
by status/verdict; pump cycle logs `D:/QM/strategy_farm/logs/pump_task_*.log` (261 completed
cycles since 2026-09-01 00:00Z); `py-spy dump` of the stuck cycle pid 1460.

## 1. Supply (is the reservoir the constraint?) — no

| Reservoir | Count |
|---|---|
| Strategy cards approved / review / draft / rejected | 3,383 / 305 / 20 / 899 |
| EA directories with a compiled `.ex5` | 3,609 |
| … of which never in any gate row (built, never gated) | 540 |
| Distinct (EA, symbol) pairs ever backtested | 13,398 (3,001 EAs) |

## 2. Where pairs are, by latest row (funnel + stranding)

| Gate | FAIL terminal | INFRA/INVALID, never rerun | PASS, no successor row | open (pending/active/held) |
|---|---|---|---|---|
| Q02 | 4,400 (+1,048 ZERO_TRADES, 59 RETIRED_LOW_FREQ) | 1,646 (871 INVALID, 775 INFRA_FAIL) | 591 | 699 |
| Q03 | 46 | 29 | 413 | 99 |
| Q04 | 3,497 | 62 | 4 | 1,394 |
| Q05 | 222 | 34 | 5 | 0 |
| Q06 | 16 | 13 | 0 | 0 |
| Q07 | 36 | 10 | 1 | 18 |
| Q08 | 51 | 12 | 0 | 0 |
| Q09 | 6 | 5 | 58 | 17 |
| Q10 (news) | – | – | 2 | 20 pending + 3 REVIEW_REQUIRED |
| Q11 | – | – | 2 | 0 |
| Q12 / OPT_CENSUS | – | – | 4 MEASURED | 12 pending + 3 active |

Frontier at or beyond Q09: ~100 pairs. Above Q02 the INFRA class is 159 pairs; their failure
reasons are transient classes (invalid_summary BARS_ZERO/EMPTY/INCOMPLETE_RUNS cold-cache,
shared_bases_history_lock_transient_cap_exhausted, summary_missing_retries_exhausted,
launch_fault, ACTIVE_TIMEOUT) — see `scratchpad/infra_norerun_q03plus.json` (session copy).

## 3. Root cause of the stranding: the pump control plane

1. **Gate cascade dead.** The promotion stage (Q02 review→Q03, Q03…Q09 PASS→successor, Q02→Q04
   probe) ran in **12 of 261** completed pump cycles since 01.09 and created promotions in 4 of
   them (2, 17, 2, 2). Every other cycle exhausted its 270 s budget in `dispatch_tick` (208 s vs
   30 s budget) and `queue_maintenance_and_intake` (97 s vs 60 s) and returned before the
   promotion stage. PASS rows therefore waited hours to days for a successor row: 413 Q03 PASS
   (25 of them < 7 d old), 58 Q09 PASS (55 < 7 d), 591 Q02 PASS.
2. **DL-089 census services starved** the same way (matrix service, fork driver, fork service
   absent from the 09:48Z cycle) → no sibling Q02 seeds, no refills, no successors for Q12 pairs.
3. **Card backfill in the hot path.** `_backfill_owner_source_lineage` (a 2026-07-23 one-off)
   re-read all ~3,400 card files every 5-minute cycle, unbudgeted. The 09:58Z cycle spent >16 min
   in it (py-spy: `read_text` ← `parse_card_frontmatter`, 6 s CPU, 1 thread) and the next three
   scheduled cycles were skipped or overlapped via the wrapper's stale-lock takeover.
4. Q10 autoseal in the last completed cycle: 2 candidates, 0 sealed (`Q08 dependency has no Q07
   lineage`, `bound Q07 seed-stability evidence is missing`) — the Q10 v4 critical path.

## 4. Fixes applied today (all GREEN: order/budget/caching, no criterion touched)

| Commit | Change |
|---|---|
| `f558a07408` | DL-089 census services run right after the cheap refill, before intake/build/review; cycle budget 270→360 s |
| `9abb2290be` | promotion/cascade region (548 lines, unchanged code) moved ahead of intake/build/review; `dispatch_tick` sub-step timings (autoseal / terminal scan / db scan / per-row) |
| `ff08f13eb8` | card lineage backfill: (mtime,size) cache under `state/`, 15 s stage deadline, budgeted stage; stuck cycle pid 1460 stopped |
| session | 101 of 159 INFRA_FAIL rows above Q02 re-enqueued append-only (`--append-only-rerun-of` + exact predecessor); 22 refused correctly (binary rebuilt → new identity), 4 missing Q03 evidence, 32 Q04 early-probes need the Q02 predecessor (second pass) |

## 5. Shortcuts / simplifications found (audit §3 + today)

- Q08 sub-gate 8.2 (deflated Sharpe) is a trivial deferred pass in 85 % of rows; MT5 Sharpe is
  11–22× the return-based Sharpe → Codex task (report-only column first; threshold sealed).
- Q09_NEWS seeds inert (40 cells = 8 configs) → A+B contract v3 approved, pilot as reference.
- Census counted only contiguous chains and mis-scored CONFIG_LOCKED / NO_*_CHANGE / FAIL_SOFT
  (fixed `8baa00fde9`, `3aac32dcc8` + OWNER receipt #2).
- Q12 finalizer ignored READY_FOR_Q15 (fixed `219217c28c`); 7 `_opt` siblings missing (built).
- A July one-off backfill left in the 5-minute hot path (fixed `ff08f13eb8`).
- Walk-forward PF is selection-conditioned; 2026-Q1 OOS never used → runner task 70dd5b7a.

## 6. What still has to be extended

Q10 news gate v4 unblock (autoseal bind failures), Q08 DSR real deflation, pump wrapper hard
timeout + incremental scans for the remaining whole-world stages (`sweep_enqueue_built_eas`,
`_auto_queue_r_eval_for_unknown_drafts`), Dukascopy backfill (running), FTMO daily-loss budgeter.
