# Terminal-worker RAM admission by reservation class

Task: `ddee6f24-6e57-423b-858d-bfb323beada2`  
Authority: CEO mandate 2026-09-02 (infrastructure only; no verdict logic)  
Code commit: `23a950ea7e`

## Outcome

`terminal_worker` now applies the requested physical-memory invariant to every
claim candidate:

`free_ram_now - class_reservation_gb(candidate) >= RAM_MIN_FREE_GB`

The 14 GB trip floor and 20 GB recovery threshold remain the final fleet-wide
defence. A latched worker may inspect the queue read-only in the 18-20 GB
recovery band and pass only an admissible single-symbol `OPT_CENSUS` cell to
the normal claim checks. The latch is not cleared by that exception. At less
than 18 GB free, even a 4 GB cell remains paused.

The physical-RAM reservation table is deliberately conservative:

| class | reservation | basis |
|---|---:|---|
| `opt_census_cell` | 4 GB | observed 2-4 GB annual-cell working-set band; upper bound reserved |
| `ordinary` | 8 GB | existing ordinary commit class |
| `two_leg_fx` | 8 GB | existing multisymbol class |
| `multi_leg_fx` | 32 GB | existing multisymbol class |
| `single_index_tick` | 44 GB | existing index-tick class |
| `heavy_basket` / unknown multisymbol | 44 GB | existing fail-closed multisymbol class |

Multisymbol `OPT_CENSUS` rows retain their multisymbol classification; the
4 GB exception cannot downgrade a basket.

## Deterministic test seam and receipts

`QM_TEST_FREE_RAM_GB` supplies a finite non-negative free-RAM value for tests.
Invalid values fall back to the real probe. Claim results now contain
`ram_class_skipped`, whose entries record item, class, reservation, observed
free RAM, post-reservation free RAM, and the 14 GB threshold.

Verification on this host:

- complete terminal-worker regression: `213 passed, 4 subtests passed`
- `py_compile`: PASS
- `git diff --check`: PASS
- class boundary fixture: at 18 GB, a 4 GB census cell is admitted and an
  8 GB ordinary row is skipped
- hysteresis fixture: census bypass is closed at 17.9 GB and open at 18.0 GB

## Live-capacity observation and rollout disposition

At the post-test observation, the 63.12 GB host had 8.69 GB free and seven
active tester processes. Their working sets were 9.996, 11.083, 11.430,
3.505, 2.049, 1.681, and 0.026 GB. The farm had seven active work items,
including one `OPT_CENSUS` cell and three large Q07/Q08/Q10 jobs.

The pre-change throughput observation supplied with the task was 13 census
cells per 10 minutes outside a RAM pause and 3 per 10 minutes during a pause.
An after-reload 10-minute cell measurement is **not available in this cycle**:
8.69 GB is below the unchanged 14 GB emergency floor, and interrupting any of
the seven active T1-T10 runs to reload workers is prohibited. No process was
stopped and no terminal was started. The live rollout/throughput acceptance
therefore remains deferred; only the code and test acceptance is complete.

## Rollback

Revert `23a950ea7e`, then reload workers one idle terminal at a time. Never
stop an active backtest, never reload the whole fleet together, and never
enable AutoTrading or `T_Live`.

