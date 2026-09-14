# Per-symbol index-tick RAM reservation table — lever 1 of the 2026-09-14 control review

OWNER 2026-09-14 (chat): "Los gehts, alles freigegeben und gemäß Vorschlag entschieden! Außer RAM Zukauf."
Orchestrator execution under the Stehende Vollmacht GRÜN zone (infra repair that touches no verdict
logic; rollback documented; blast radius named). Commits: `08b494d9b7` (table + tests + reload chunk 80),
`3283767561` (release tool + measurement watcher).

## 1 · Finding (read-only, 2026-09-14 12:2x–13:0xZ)

| Fact | Value | Source |
|---|---|---|
| Flat class `single_index_tick` | 44 GB for every index base | `terminal_worker.py` (origin: one SP500 Q02 observation 2026-08-15, 45.7 GB private / 46.8 GB WS) |
| RAM a 44 GB row needs free | 44 + 14 (class floor) = 58 GB | admission math; `drain_window.json` tracker `last_not_winnable_epoch` |
| Max free RAM seen in 24 h | 54.1 GB (63 GB host) | `free_ram_gb` in `terminal_worker_T*.log` claim events |
| Rows parked on the class | 779 (484 EAs): NDX 243, GDAXI 123, SP500 63, WS30 49, UK100 16, plus multisymbol/heavy rows | `work_item_holds` code `RAM_RESERVATION_44GB_NOT_WINNABLE_20260914` |
| Index Q04 rows completed, 120 d before 2026-09-02 | 5,323 | `work_items` |
| Index Q03+ rows completed 2026-09-03 … 09-14 | 0 | `work_items` |
| Full-window index rows in the tester memory ledger before the change | 0 (only annual census cells: NDX n=1,657 max 7.32 GB / p95 2.6 GB; WS30 n=13 max 2.2 GB) | `D:/QM/reports/state/tester_memory_ledger.jsonl` |
| Claimable rows in the canonical claim snapshot at 12:2xZ | 272 = 259 promoted real cells (blocked, ticket 4d915807) + 8 rows at 44 GB + 5 ordinary | `farmctl.pending_claim_order_sql()` |

Conclusion: the flat 44 GB reservation made every full-window index row structurally unwinnable on this
host; the index lane (about half of all Q04 throughput) had been dead for 12 days.

## 2 · Change

`INDEX_TICK_RESERVATION_GB_BY_BASE`: SP500 44 GB (measured), NDX / GDAXI / WS30 / UK100 provisional
24 GB. Resolver semantics unchanged: `max(flat, measured, phase floor)`; the measured path (per-EA key
n>=1, class key n>=3) and the phase floor can only raise; the RAM emergency reaper (free < 2 GB, WS > 2x
reservation) stays the backstop. Facts label `index_symbol_table` on the reservation source.
Rollback: env `QM_INDEX_TICK_RESERVATION_TABLE=0` (flat 44 GB everywhere), then idle-reload the workers
(`session_tools/reload_chunk80.py` pattern). Tests: `tests/test_index_tick_reservation_table.py` (8) plus
76 existing RAM tests pass.

Reload: chunk 80 (staggered, 150 s, idle-only) from 13:29Z.

## 3 · Supervised measurement, then waves

First row released alone (`release_44gb_holds_0914.py --id 48474f94`, 13:31:49Z) and traced by
`measure_index_run_0914.py` (`measurement_48474f94.jsonl`). Ledger rows (authoritative peaks,
`peak_subtree_working_set_gb`):

| ts (UTC) | EA | symbol | phase | TF | peak GB | run s | outcome |
|---|---|---|---|---|---|---|---|
| 13:37:28 | QM5_10122 | NDX.DWX | Q04 | D1 | 2.056 | 431 | finished |
| 13:39:17 | QM5_10363 | NDX.DWX | Q04 | D1 | 2.065 | 355 | finished (measurement row; verdict FAIL, genuine pf_net) |
| 13:43:18 | QM5_10122 | WS30.DWX | Q04 | D1 | 1.142 | 313 | finished |
| 13:45:00 | QM5_12366 | WS30.DWX | Q04 | D1 | 1.137 | 294 | finished |
| 13:51:05 | QM5_1359 | WS30.DWX | Q04 | D1 | 1.037 | 190 | finished |

Wave 1 (13:5xZ, `release_journal.jsonl`): NDX Q04 20, WS30 Q04 10, UK100 Q04 5, GDAXI Q04 2 (the two
GDAXI rows are the GDAXI measurement). At 13:51Z four index Q04 rows ran in parallel (NDX, GDAXI, WS30,
UK100) beside one Q07. Further waves follow the ledger: the table value is lowered only with n>=3 measured
full-window peaks per base across timeframes, never below 2x the largest measured peak, and is raised
automatically by the measured path for any EA above 10 GB.

Not released here: SP500 rows (measured 44 GB, unwinnable until the RAM decision the OWNER excluded) and the
multisymbol `heavy_or_unknown_multisymbol` rows (fail-safe class).

## 4 · Tickets

`6cdc6811` (RAM class calibration) and `4d915807` (promoted real cells) moved to REVIEW with these
commits; Codex was above its weekly budget line (73 % used vs 69.6 % line) so the orchestrator lane
executed them.
