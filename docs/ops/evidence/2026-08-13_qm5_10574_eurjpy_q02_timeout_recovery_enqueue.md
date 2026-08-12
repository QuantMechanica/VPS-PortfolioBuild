# QM5_10574 EURJPY Q02 timeout recovery enqueue — 2026-08-13

## Outcome

One append-only Q02 successor was enqueued for the diverse FX cross
`QM5_10574_mql5-bsi` / `EURJPY.DWX` after repairing the factory defect that
prematurely reaped its progressing full-history run.

- New work item: `508692f2-969c-425d-90b4-5377a244bdf7`
- State at verification: `pending`, unclaimed
- Source work item preserved: `8e098c6a-6b45-45a4-81ae-31696250d645`
  remains `failed / INFRA_FAIL`
- Farm claim: `8410e7c1-522f-45ef-8d01-9bb3fbf3a455`, assigned to `codex`
- Pre-mutation SQLite backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10574_eurjpy_timeout_claim_20260812T234223Z.sqlite`

No dispatch tick or manual MT5 run was started.

## Why this unit

The executable approved-card backlog did not offer incremental instrument
diversity: its available card was restricted by existing magic allocations to
the same index/metal/energy cluster, while the rates cards lacked approved DWX
history inputs. This recovery instead advances an absent FX-cross sleeve.

The filesystem-authoritative approved card is
`D:\QM\strategy_farm\artifacts\cards_approved\QM5_10574_mql5-bsi.md`:

- `g0_status: APPROVED`; R1-R4 all PASS.
- Reputable source: Nikolay Kositsin, "Exp_BSI", MQL5 CodeBase, published
  2016-02-17 and updated 2016-11-22,
  `https://www.mql5.com/en/code/14813`.
- Structural closed-bar BSI histogram colour-change rule; no ML, grid, or
  martingale.
- H8 expected cadence: 12-35 trades/year/symbol.
- EURJPY is explicitly in the approved target basket and magic slot 2 is
  already allocated as `105740002`.

## Diagnosis

The source Q02 row proved live forward progress and was not a strategy failure:

| Field | Source evidence |
|---|---|
| Verdict | `INFRA_FAIL / ACTIVE_TIMEOUT` |
| Reap reason | `OUTER_ABSOLUTE_CEILING` |
| Active age | 47.31 minutes |
| Bound progress | 46% at `2026-08-10T09:59:27Z` |
| Progress stall | 1.18 minutes |
| Generic outer ceiling | 45 minutes |
| Persisted `timeout_seconds` | missing |
| Reaper-derived `inner_budget_min` | 0 |

This exact EX5 later passed Q02 on GBPUSD in work item
`9bb77698-5ce6-4c8e-a74d-b1fcd669e5d1`. EURJPY H8 history was also independently
validated by the PASS canary recorded in
`docs/ops/evidence/c050d3e0_dwx_history_canary_results_2026-07-07.csv`.

The Q02 full-run launcher already computes a 7,200-second inner budget. The
terminal worker omitted that value when it sealed the spawned work-item payload,
so the progress-aware reaper could not apply its existing inner-budget plus
10-minute headroom rule. Persisting the actual spawn budget raises this run's
outer safety ceiling to 130 minutes while preserving the 20-minute no-forward-
progress kill path.

## Repair

- `tools/strategy_farm/terminal_worker.py` now persists a positive
  `spawn.timeout_seconds` before monitoring begins.
- `tools/strategy_farm/farmctl.py` now accepts the immutable, hash-bound
  `payload.log_path` as rerun evidence specifically for `ACTIVE_TIMEOUT`
  `INFRA_FAIL` rows that cannot have a completed summary.
- The append-only source row remains unchanged; the successor binds its source
  payload and runner-log SHA-256.

Verification:

```text
python -m pytest -q tools/strategy_farm/tests/test_candidate_repair_enqueue.py tools/strategy_farm/tests/test_progress_aware_reaper.py tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py::TerminalWorkerAtomicClaimTests::test_launch_fault_defers_without_incrementing_attempt_count
43 passed in 14.13s

python -m pytest -q tools/strategy_farm/tests/test_p2_prescreen_policy.py tools/strategy_farm/tests/test_terminal_worker_adoption.py
11 passed, 10 subtests passed in 4.23s
```

## Enqueue bindings

| Artifact | SHA-256 |
|---|---|
| EX5 | `a647912002f847a86ffca3cc027da118adec89a6a551a6632d52a63332622fab` |
| MQ5 | `a9e8941de12ade9ed135eaaed19fc37a5f297317e23c309e2276e861c788e75e` |
| EURJPY H8 setfile | `3468c05faf50e23d3822a794e80de79b5f9dcb9809388e55701666b6cdbe6110` |
| Source runner log | `eb845d34609283d9ff3c47c17f420ead883f03325fcf07c354b39ea469a35165` |
| Source payload | `0a17f30c42267d79cb0d8978f42a0ff6563a7f1b99e7128f11165ae3c240bae9` |

The successor is bound to `EURJPY.DWX`, H8, expert
`QM\QM5_10574_mql5-bsi`, window `2018.07.02` through `2022.12.31`, and the
RISK_FIXED contract `RISK_FIXED=1000`, `RISK_PERCENT=0`. Exactly one open Q02
row existed for this EA/symbol after enqueue.

## Safety

At the final capacity check there were zero running strategy-factory MT5
terminals, zero terminal reservations, and no resident terminal workers; total
CPU was 14.36%. The unrelated FTMO terminal was outside the factory set. No
backtest CPU ceiling was reached. No `T_Live`, AutoTrading, portfolio-gate, or
live-manifest state was touched.
