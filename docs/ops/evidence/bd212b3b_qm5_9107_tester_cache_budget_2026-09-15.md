# QM5_9107 tester-cache disk bomb: diagnosis and guard

Task: `bd212b3b-7c21-4538-baaa-1cdbfc6b3777`

## Result

`QM5_9107 / XAUUSD.DWX / Q02` is not an ordinary single-symbol D1 test.  Its
source contains a hidden 37-symbol cross-sectional momentum universe.  At each
monthly rebalance it asks MT5 for two MN1 momentum horizons for every peer.
Under the Q02 Model 4 real-tick run this causes MT5 to synchronize and build
tester data for the peer universe inside the terminal-local `Tester/bases` and
`Tester/Agent-*` trees.  The old multisymbol registry did not recognize the
`Strategy_UniverseSymbol()` switch idiom, so the worker admitted the run as
`ordinary` with an 8 GB reservation.

A Default-OFF per-run cache-growth guard is now implemented.  It can be opted
in by setting `QM_TESTER_CACHE_BUDGET_GB` to a finite positive number in the
worker environment.  No variable is set by this change, so current behavior is
unchanged until an operator enables it.

RESULT: PASS — root cause bound to the two incident rows and source hash; an
opt-in per-run tester-cache budget now seals a breach as
`INFRA_FAIL / TESTER_CACHE_BUDGET_EXCEEDED` before the 40 GB disk stop, and a
second distinct breach activates an exact EA/symbol hold across Q phases.

## Incident reconstruction

| Evidence | First run | Rerun |
|---|---:|---:|
| Work item | `34b76994-575c-4286-8ea8-3261281263c0` | `92a2eab2-5487-4140-9694-54f35950a629` |
| Terminal / claim | T1 / `2026-09-12T17:02:38Z` | T8 / `2026-09-12T20:04:08Z` |
| Q02 window / model | 2018-07-02 through 2022-12-31 / Model 4 real ticks | same |
| Tester-cache observation | 54 GB: Agent-3002 31 GB + bases/ticks 22.6 GB | 97 GB reported peak; Agent-3001 28 GB + bases 24 GB at an intermediate sample |
| Farm effect | D: 91.5 GB at 17:00:45; 39.48 GB before busy-scratch recovery at 17:18:59; purge left only 6 governed workers | D: reached 22 GB and the purge tore down idle workers |
| Run outcome | `ACTIVE_TIMEOUT`, `NO_FORWARD_PROGRESS`, killed at 17:28:13Z after 25.3 minutes | completed at 21:00:46Z after 3 attempts; `FAIL / MIN_TRADES_NOT_MET` |
| Worker memory | 23.965 GB when an earlier attempt was emergency-reaped | 39.180 GB subtree WS, 39.030 GB metatester WS, 40.960 GB private, 3352.172 s |
| Admission class | `ordinary`, 8 GB | `ordinary`, 8 GB |

The rerun summary reports `attempted_runs=3`: the first two attempts hit the
report-capture-incomplete retry class and the third produced the final report.
This can duplicate agent-local artifacts within the same terminal and explains
why the observed T8 total could exceed one `bases + Agent` snapshot.  Cross-
terminal reuse was impossible: the first attempt wrote under T1 and the rerun
wrote under the isolated T8 root.

The purge log independently binds the timing.  At 17:00 it cleared T1's old
cache and reported D: 91.5 GB after relaunch.  By 17:18:59 it saw only 39.48 GB
before reclaiming 5.44 GB of busy scratch; T1 was protected as active, so its
tester cache could not be purged.  The measured 54/97 GB decomposition is the
operator observation preserved in `OPEN_ITEMS_STATUS.md` at the 2026-09-12
22:35Z and 00:40Z entries.

## Source-level cause

Source SHA-256:
`1cf9d1894c0d109f6908620621fd1668b730d14e60e8a294bb7fcdc575a51200`.

- `Strategy_UniverseCount()` returns 37 (lines 91-94), and the switch at lines
  96-136 names the complete `.DWX` universe.
- `Strategy_MonthlyMomentum()` calls `Bars(symbol, PERIOD_MN1)` plus two
  `iClose(symbol, PERIOD_MN1, ...)` reads (lines 150-165).
- `Strategy_RankPasses()` loops over all 37 peers and evaluates both 11-1 and
  10-0 momentum (lines 180-236).  One rank evaluation therefore issues up to
  222 peer-history calls before MT5's internal reuse; a failed long rank can
  also invoke the short rank.
- The expensive rank is month-gated rather than per-tick (entry lines 306-317),
  so this is not journal spam or an HFT loop.  The disk cost comes from first
  synchronization/cache construction for 37 symbols in a real-tick test.
- The 203-entry runtime registry at
  `D:/QM/strategy_farm/state/multisymbol_eas.txt` contains no `QM5_9107`.  It
  historically recognized markers such as `g_symbols[]`, `QM_Basket`, and
  `_SYMBOL_COUNT`, but not this function/switch form.  The same omission affected
  three measured XAU outliers (`QM5_1540`, `QM5_1536`, `QM5_10316`).  The worker
  now treats those four source-audited IDs as heavy multisymbol admissions even
  when the external registry is stale.

The row's custom-history copy receipt lists only `XAUUSD.DWX`, while its archive
admission lists all 37 symbols.  That mismatch is consistent with host history
being prepared up front and the EA making peer requests lazily inside MT5.

## Ordinary-XAU comparison and related pairs

The tester-memory ledger contains 50 Q02 `XAUUSD.DWX` D1 observations that were
labelled `ordinary`: median peak subtree WS 7.887 GB, p90 13.212 GB, maximum
39.180 GB.  Removing the four source-confirmed hidden-universe EAs leaves 46
observations with median 7.885 GB and p95 7.921 GB.  QM5_9107's 39.180 GB is
4.95 times that p95.  This comparison is memory telemetry, not a substitute for
the incident's direct disk measurements.

Pairs at or above 20 GB peak subtree WS in the Q02 ledger and with confirmed
peer-symbol mechanics are classified as the same cache-risk class:

| Exact EA/symbol pair | Peak WS (GB) | Classification |
|---|---:|---|
| `QM5_9107 / XAUUSD.DWX` | 39.180 (also 23.965 reaped) | cache-confirmed; hidden 37-symbol universe |
| `QM5_1540 / XAUUSD.DWX` | 34.680 | hidden cross-sectional universe plus VIX proxy |
| `QM5_11240 / GBPUSD.DWX` | 24.655-34.025 | registered `basket10+` |
| `QM5_1536 / XAUUSD.DWX` | 26.423-32.665 | hidden 10-symbol universe |
| `QM5_41155 / GBPJPY.DWX` | 31.499 | `basket3_9` breadth universe |
| `QM5_10316 / XAUUSD.DWX` | 28.939 | hidden 7-symbol universe |
| `QM5_12512 / EURUSD.DWX` | 26.065 | cache-confirmed 37-pair basket; separate 23 GB cache incident at 22:07Z |
| `QM5_41472 / EURGBP.DWX` | 22.658 | `basket3_9` |
| `QM5_41471 / AUDUSD.DWX` | 21.212 | `basket3_9` |

Only QM5_9107 and QM5_12512 have direct disk-size observations in the reviewed
ops evidence.  The other rows are high-confidence cache-risk candidates based
on source/payload peer access plus memory telemetry; they are not pre-emptively
held.  The new cache ledger makes future disk classification direct.

## Guard and hold contract

- Activation: `QM_TESTER_CACHE_BUDGET_GB=<positive GiB>` in the worker process.
  Absent, blank, invalid, zero, negative, NaN, or infinity leaves the guard off.
- Scope: the worker snapshots exactly one terminal's `Tester/bases` and all
  immediate `Tester/Agent-*` trees after the launch semaphore and before child
  spawn.  `Tester/cache` and `Tester/logs` are excluded because the existing
  report and log-bomb guards own those artifacts.
- Trip: sample every five seconds and abort when net run growth reaches the
  effective allowance, or D: free space reaches 48 GB.  Effective allowance is
  `min(configured budget, free-at-start - 48 GB)`.  The 48 GB floor is the 40 GB
  farm stop plus an 8 GB sampling/containment reserve.
- Disposition: stop the bound runner tree and terminal slot; write
  `tester_cache_budget_exceeded.json` under the work-item report root; append
  `D:/QM/reports/state/tester_cache_budget_ledger.jsonl`; atomically transition
  the row to `failed / INFRA_FAIL / infra` with exact reason
  `TESTER_CACHE_BUDGET_EXCEEDED`.  Measurement errors fail open and are counted.
- Exact hold: after two distinct guarded failures for the same EA and symbol,
  `poison_pill_quarantine` receives an active wildcard-phase (`*`) row.  Normal
  claims, targeted Factory-OFF claims, and stranded-infra requeue all enforce
  it across Q phases.
- Release rule: only after the peer-history/cache cause is fixed or a controlled
  budget is approved, an operator explicitly runs:

  `python C:/QM/repo/tools/strategy_farm/poison_pill_quarantine.py release --ea-id <EA> --symbol <SYMBOL> --phase '*' --note "<fix/evidence>"`

  Release starts a fresh two-hit window; pre-release hits do not reactivate it.

No worker environment was changed, no test was launched, no terminal was
started, and no running backtest was stopped while implementing this ticket.

## Verification

- `python -m py_compile` on the five changed Python modules: PASS.
- Focused cache/quarantine/claim/requeue suite: 48 passed.
- Existing log-bomb/external-release regression selection: 1 passed, 101
  deselected.
- `git diff --check` for the explicit task paths: PASS (only repository CRLF
  conversion notices).

Evidence bindings at inspection:

- `tester_memory_ledger.jsonl` SHA-256
  `1eb352db60ca7bb14ffe1f38414822105f1cc6bc5bc04e65ef7082134704121f`
- `tester_cache_purge.log` SHA-256
  `d3377bc0038b4876c5a03d26346be60cfe855241fb20927d1688d80d0358f7a5`
- `multisymbol_eas.txt` SHA-256
  `e95c6863001585008272135ef5cc40586b366d44d13ef4b900798355996ab813`
- completed rerun `summary.json` SHA-256
  `61682fb7050b41bc1b2d754ef01a733d9b354ad761311407864907a44790c106`
