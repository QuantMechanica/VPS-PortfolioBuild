# QM5_20161 Q02 identity-bound PASS recovery

**Date:** 2026-07-31

**Branch:** `agents/board-advisor`

**Outcome:** `Q02_PASS_RECOVERED_AND_Q04_ENQUEUED`

**Agent task:** `497232d2-c60a-4d7a-830f-9346f7b14961`

## Diversity-first selection

No clean, unclaimed priority-1 diversity build was available. The two most
relevant unbuilt cards were already durably blocked at R3: `QM5_1457` needs
unavailable Treasury/IEF/BIL/DBC inputs and `QM5_1459` needs unavailable
lumber and IEF inputs. Other open build rows were rework/duplicate rows for
EAs already built or already in the pipeline. The standard approved-card build
gate was therefore not bypassed.

The next mission priority was used. `QM5_20161_xauxag-ols-rv` is a built D1
two-leg XAU/XAG rolling-OLS residual-reversion basket. Its approved card is
structural, expects approximately 5–15 completed packages per year, prohibits
ML/grid/martingale mechanics, and records R1–R4 PASS. Its governed source
packet cites Schweikert (2018), *Journal of Banking & Finance* 88, and Yaya,
Vo and Olayinka (2021), *Resources Policy* 72. This is relative-value pair
exposure, distinct from another outright index/metal/energy directional build;
later gates still have to prove robustness and portfolio value.

Before mutation, a guarded SQLite transaction confirmed no pending/active
work item and no competing open agent task for this EA, then recorded the
claim with canonical `assigned_agent=codex` and branch-scoped
`claimed_by=codex:agents/board-advisor`.

## Diagnosis

Q02 work item `99ce65cf-8c8e-43bf-85c1-231ad2c3fb15` was terminal
`failed / INFRA_FAIL`. Its payload reported seven transient retries and
`shared_bases_history_lock_transient_cap_exhausted`. The retained report tree,
however, contains a complete `run_smoke/v2` summary from T4:

| Field | Evidence |
|---|---|
| Window | `2018.07.02` through `2022.12.31` |
| Host / period | `XAUUSD.DWX / D1` |
| Model-4 real-tick marker | `true` |
| Trades | 99 (Q02 minimum 25) |
| Profit factor | 0.84 |
| Net profit | -1846.79 |
| Drawdown | 3753.58 (3.72%) |
| Summary SHA256 | `e39908d6b17d16e22ef0274ab90fca2c56b94c32460a806da97db5a3b8598a2c` |

The negative P&L is not hidden: Q02 is the execution/density floor, so its
verdict derives `PASS`; Q04 is the first walk-forward wall that decides whether
the edge survives.

The v2 identity in that summary exactly matches the current governed files and
the work-item expectations:

| Artifact | SHA256 |
|---|---|
| MQ5 | `e4801e82ee2a41b1e7133c6121c1e4b79cd6693af2ac60dbc9e04a19df8b04dd` |
| EX5 | `8f617f803089d6d6edc5f8351f09ab55c74fc734899a90f41b3c862f5ec86aea` |
| RISK_FIXED setfile | `7cb021256db752821c99d6d5df4813cc4b7f49fece0ee57589ac3f360ebcdcd0` |

The defect was lifecycle ordering. Normal summary discovery rejects artifacts
older than the current claim. If a worker restarts after a complete summary is
written but before the result is committed, the next history-lock retry sees
no *fresh* summary, consumes the transient retry budget, and can overwrite the
effective outcome with `INFRA_FAIL` even though an exact PASS remains in the
item-isolated report tree.

## Repair

`terminal_worker.py` now performs a fail-closed fallback after fresh discovery
misses for P2/P3/Q02/Q03:

- inspect the DB-bound `evidence_path` and the item-isolated report root;
- require `evidence_binding_required` and an exact `run_smoke/v2` match for
  window, symbol, period, expert, MQ5, EX5, and setfile;
- reject cold-cache summaries;
- latch only a verdict that still derives `PASS` at the governed trade floor;
- treat an explicitly bound or newer exact non-PASS as authoritative rather
  than hunting for an older PASS.

The regression recreates a later claim over an old exact PASS, proves ordinary
freshness rejects it, proves wrong EX5 identity and insufficient trades fail
closed, injects a simultaneous history-lock signature, and verifies the row
finishes `done / PASS` rather than being transiently requeued.

Validation:

```text
py -3 -m pytest tools/strategy_farm/tests/test_terminal_worker_history_lock_storm.py \
  tools/strategy_farm/tests/test_q02_evidence_binding.py -q
22 passed

py -3 -m pytest tools/strategy_farm/tests/test_terminal_worker_staged_ex5.py \
  tools/strategy_farm/tests/test_terminal_worker_q_phase_stall.py \
  tools/strategy_farm/tests/test_terminal_worker_history_lock_storm.py \
  tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py \
  tools/strategy_farm/tests/test_terminal_worker_adoption.py \
  tools/strategy_farm/tests/test_q02_evidence_binding.py -q
86 passed, 4 subtests passed

py -3 -m py_compile tools/strategy_farm/terminal_worker.py \
  tools/strategy_farm/tests/test_terminal_worker_history_lock_storm.py
PASS
```

## Farm-state recovery and Q04 handoff

Before changing canonical state, SQLite's online backup API created the
following snapshot and `PRAGMA quick_check` returned `ok`:

```text
D:\QM\strategy_farm\state\backups\farm_state_before_qm5_20161_pass_recovery_20260731T133436Z.sqlite
```

The repaired classifier then restored the existing Q02 row in place:

```text
work item:     99ce65cf-8c8e-43bf-85c1-231ad2c3fb15
before:        failed / INFRA_FAIL
after:         done / PASS
evidence:      D:\QM\reports\work_items\99ce65cf-8c8e-43bf-85c1-231ad2c3fb15\QM5_20161\20260726_030730\summary.json
```

The transition is recorded in `work_item_transition_ledger` under the
idempotency key beginning `codex-bound-pass:99ce65cf-...`. The standard
cascade enqueue command then created the Q04 default-probe row:

```text
command:       py -3 tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_20161 --phase Q04
Q04 item:      9a966b83-70c1-49ea-baa5-068ed455905d
logical pair:  QM5_20161_XAUUSD_XAGUSD_OLS_D1
status:        pending
source:        Q02 item 99ce65cf-8c8e-43bf-85c1-231ad2c3fb15
```

The unchanged backtest setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`,
and `PORTFOLIO_WEIGHT=1`.

## Capacity and safety boundary

No smoke, dispatch tick, terminal launch, or backtest was started by this
repair. At handoff, the read-only MT5 slot census showed three factory
terminals running (`T4`, `T8`, and `T9`), below the seven-process ceiling; the
Q04 row was left pending for normal paced dispatch.

`T_Live` was observed only as an excluded process in the read-only census. It
was not controlled. AutoTrading, live setfiles, the T_Live manifest, portfolio
gate, portfolio admission, and Q08 contribution artifacts were not touched.
