# Q10_NEWS run_smoke exit-1 — root cause, fix, and re-run plan (2026-08-24)

Router task `cb50e7c8-8d0f-490b-9a18-3231987c93c7` ("P0 Weg-zu-25-Damm: Q10_NEWS
run_smoke exit 1 ohne Summary — 81 Zellfehler, 0 authentifizierte Standard-Matrizen
in 48h"). Commissioned by the 2026-08-24 afternoon orchestrator session
([[project_qm_ceo_session_review_drain_throughput_2026-08-24]]) after observing
13 terminal `Q10_NEWS` (8-cell "standard" contract-v3) rows land in
`REVIEW_REQUIRED` with `authenticated_cell_count=0, failed_cell_count=8`, while
three parallel 29-cell "expansion" rows on the same contract v3 machinery kept
producing receipts.

## 1. Root cause (reproduced from on-disk evidence)

Every cell dispatch (`tools/strategy_farm/q09_news_runner.py:2396-2551`,
`_production_dispatch_cell`) shells out to `framework/scripts/run_smoke.ps1` once
per window (selection/holdout/full). `run_smoke.ps1` first calls the terminal
reservation/custom-history admission gate
(`tools/strategy_farm/custom_history_smoke_admission.py:104` →
`farmctl.set_terminal_reservation`) **before** it ever launches the tester.

`set_terminal_reservation` (was `tools/strategy_farm/farmctl.py:800-827`) wrote a
per-PID temp file and did a bare `tmp.replace(path)` onto the single shared
`D:\QM\strategy_farm\state\terminal_reservations.json`. Under concurrent writers
(multiple `run_smoke.ps1` invocations racing to reserve/release terminals at the
same moment — exactly what a busy factory produces), Windows'
`MoveFileExW`/`os.replace` transiently raises `PermissionError: [WinError 5]
Access is denied` when another process/AV scan briefly holds the destination
open. `run_smoke.ps1:704` turns that into a hard `throw`, so run_smoke exits
code 1 with **no tester ever launched and no summary/report written**.

Reproduced exactly in a failure_attempts snapshot for work item
`73b21148-65be-4aad-a2dd-fb7c2f22e9bc`, cell `policy_on__m3__c1__s17`
(`D:/QM/reports/work_items/73b21148-.../q09_contract_v3/cells/policy_on__m3__c1__s17/failure_attempts/attempt_0001/runs/selection/run_smoke.log`):

```
run_smoke.stage=resolved_terminal terminal=T10
Exception: C:\QM\repo\framework\scripts\run_smoke.ps1:704
 704 | throw "Custom-history gate/reservation refused terminal '$Terminal' …
   Custom-history gate/reservation refused terminal 'T10': Traceback (most recent call last):
   File "…\custom_history_smoke_admission.py", line 198 … raise SystemExit(main())
   File "…\custom_history_smoke_admission.py", line 177, in main  payload = reserve_smoke_terminal(…)
   File "…\custom_history_smoke_admission.py", line 104, in reserve_smoke_terminal  reservation = farmctl.set_terminal_reservation(…)
   File "…\farmctl.py", line 826, in set_terminal_reservation  tmp.replace(path)
   File "…\pathlib.py", line 1188, in replace  os.replace(self, target)
   PermissionError: [WinError 5] Access is denied:
     'D:\QM\strategy_farm\state\terminal_reservations.json.26072.tmp'
     -> 'D:\QM\strategy_farm\state\terminal_reservations.json'
```

`_production_dispatch_cell` (`q09_news_runner.py:2465-2476`) sees
`returncode == 1`, calls `_latest_summary` (`:2112-2119`) which finds no fresh
`summary.json`, and raises the generic
`TransientCellError("Q09 {window} run_smoke exited with code 1 without a fresh
run_smoke summary or cell receipt")`. That generic string is all that survives
into `cell_failure.json` and the `Q10_NEWS` aggregate — **the WinError 5 detail
is not swallowed at the process level** (stdout+stderr are captured and written
to the per-window `run_smoke.log`, which the failure_attempts snapshot
preserves), but it never propagates past the `TransientCellError` message, so
every affected cell looks identical at the DB/dashboard level with no hint of
the real cause. That is why 12 of the 13 rows were opaque until the raw
`run_smoke.log` snapshots were read directly.

`collect_run_plan_status` (`:1602-1695`) then partitions all 8 cells as
`failed`, none as authenticated, and emits
`REVIEW_REQUIRED / cell_execution_failed` with
`authenticated_cell_count=0, failed_cell_count=8` — exactly the observed
symptom.

## 2. Standard (8-cell) vs. expansion (29-cell) — same code, a timing artifact

`_cell_specs(..., expanded)` (`q09_news_runner.py:188-195`) is the **only** code
difference between an 8-cell standard row and a 29-cell expansion row; dispatch,
admission-gate, and reservation-file handling are identical.

Expansion rows hit the identical `WinError 5` race but survive it because they
run many cells serially over a long occupancy window and `collect_run_plan_status`
only re-runs missing cells across attempts (`:1602-1645`) — a handful of transient
losses do not zero out the whole row:

| work item | cells | cell_failure mix (on-disk sidecars) | outcome |
|---|---|---|---|
| `463fa52a` (expansion) | 29 | 17 RunnerError (mostly terminal-exit-wait timeout) + 2 Transient | 12 receipts, still active |
| `e58b8c4c` (expansion) | 29 | 5 Transient | 28/29 receipts, verdict written |
| `9416f0ce` (expansion) | 29 | 2 Transient | 21 receipts, still active |
| 13 standard rows | 8 each | **113 Transient + 8 RunnerError(bundle-id, 1 row) + 1 RunnerError(INCOMPLETE)** | **0 receipts on any of the 13** |

The 8-cell rows never got a single cell through all 3 windows before exhausting
`WORK_ITEM_ATTEMPT_CEILING = 3` (`:80`, retry lane `:2799-2866`); two of the 13
even carry `payload.prior_failure = "worker_restart_released_stale_claim"`
(`1e3b7aa9`, `c5260944`), consistent with worker churn under the same load. This
correlates with the afternoon throughput forensics
([[project_qm_ceo_session_review_drain_throughput_2026-08-24]]): long-run Q10
expansions holding terminals 6–12h + CPU contention (22 codex-code-mode-host on
16 vCPUs) — the busier the factory, the more concurrent reservation writers, the
more `WinError 5` hits. **Verdict: contention artifact, not a structural
standard-vs-expansion code defect.**

## 3. Fix applied

`tools/strategy_farm/farmctl.py` — added `_replace_reservation_file(tmp, path)`
(retry with exponential-jitter backoff, 8 attempts, ~0.05s base) and routed both
`set_terminal_reservation` and `release_terminal_reservation` through it instead
of a bare `tmp.replace(path)`. Only `OSError` with `winerror in (5, 32)`
(access-denied / sharing-violation — the transient Windows classes) is retried;
any other `OSError` still propagates immediately, so a genuinely broken
reservation write still fails loudly instead of being masked. This mirrors the
existing SQLite busy-retry pattern in the same module
(`_with_sqlite_write_retry`) and the prior "short retry+jitter beats long"
finding from the XCU coverage-trip incident
([[project_qm_xcu_coverage_trip_2026-08-16]]).

This does **not** touch any gate threshold, verdict, or Q-phase criterion — it
only hardens an infra-level file write that was aborting the admission gate
before any tester run.

### Test

`tools/strategy_farm/tests/test_farmctl_terminal_reservation_retry.py` (4 tests,
all pass):
1. `_replace_reservation_file` retries past 2 transient WinError 5s then
   succeeds, writing the correct content.
2. Exhausts the retry budget and re-raises when the fault never clears.
3. A non-transient `OSError` (e.g. WinError 2, file not found) propagates
   immediately without retrying.
4. `set_terminal_reservation` end-to-end survives one transient failure and
   the reservation is correctly persisted.

Also re-ran `tests/test_custom_history_smoke_admission.py` +
`tests/test_farmctl_cascade.py` (34 passed, 6 subtests) to confirm no
regression in the admission-gate/reservation call path.

## 4. The isolated calendar-bundle-id mismatch (row `73b21148`, EA QM5_9936) — separate, EA-level defect, not fixed here

8 of the 13 rows' cell failures for `73b21148` are a **different** error:
`RunnerError "MT5 report effective input qm_news_calendar_bundle_id mismatch"`.
`qm_news_calendar_bundle_id` (and its two siblings
`qm_news_calendar_expected_sha256`, `qm_news_calendar_common_relative_path`) are
written into every cell's `.set` at plan time
(`q09_news_runner.py:323`, verified present in the failing cell's `inputs.set`)
and read back from the MT5 tester report's Inputs table by
`_validate_report_effective_inputs` (`:1981-2016`). For QM5_9936's report
(`…/control_off__m0__c0__s17/…/report.htm`), the Inputs table has 44 effective
inputs (every numeric/enum input present) but **none of the three
`qm_news_calendar_*` string inputs** — MT5 silently drops `.set` keys the EA
never declared, so the echo-back check sees `None != <bundle_id>` and rejects.

Cross-check: the expansion rows' reports (different EAs, same
`bundle_id=q09cal-20150101-20260809-0bb19b5bb9790b76`) DO contain all three
inputs. `news_calendar.status=OK, mismatches=[]` in the same QM5_9936 summary
confirms calendar *provisioning* was fine — this is specifically QM5_9936's
compiled binary (`ex5` built 2026-08-17, `mq5` last write 2026-07-27) missing
the three provenance-echo inputs that other EAs in the current template carry.

**This is not fixed by this ticket.** Per constraints (no gate-threshold
changes, no verdict overrides), the correct remediation is an EA-level review:
confirm whether QM5_9936 was built from a pre-provenance-input template
revision and needs a rebuild, or whether its declared-inputs list was
truncated. Recommend a `review_ea`/build ticket for QM5_9936 specifically; do
**not** re-run row `73b21148` as-is — it will reproduce the identical mismatch
until the EA's declared inputs are fixed.

## 5. Re-run plan for the 13 REVIEW_REQUIRED rows

All 13 rows keep their `REVIEW_REQUIRED` terminal row as permanent evidence
(append-only; canonical path `farmctl.py enqueue-backtest --append-only-rerun-of
<row> --from-work-item-id <Q09 PASS predecessor> --ea <EA> --phase Q10_NEWS
--rerun-reason "..." --expected-current-ex5-sha256 <sha256>`). This falls under
the Stehende Vollmacht GRÜN class ("re-enqueue rows without a [genuine strategy]
verdict — timeouts, INFRA_FAIL, orphaned claims"): these 13 verdicts are an
infra reservation-race artifact, not a strategy judgment: old rows stay as
evidence, no verdict is overwritten or deleted.

| # | work_item_id | EA / symbol | class | action |
|---|---|---|---|---|
| 2 | `73b21148` | QM5_9936 USDJPY.DWX | EA-defect (bundle-id echo missing) | **do not re-run** — needs EA review/rebuild ticket first |
| 10 | `f5aa4af4` | QM5_11881 GBPUSD.DWX | Transient (reservation race) | **canary re-run enqueued** → `dddcd4a5-5fc3-4568-9527-73286819a1a2` |
| 12 | `56f52d6c` | QM5_11754 USDCAD.DWX | Transient (reservation race) | **canary re-run enqueued** → `6e8dcc3a-ed3f-4314-82b0-3bfd7238969f` |
| 1 | `13f41983` | QM5_1328 EURJPY.DWX | Transient | pending — batch after canary confirms clean |
| 3 | `1e3b7aa9` | QM5_20010 XAUUSD.DWX | Transient (+ prior worker-restart claim loss) | pending |
| 4 | `c5260944` | QM5_21507 XAUUSD.DWX | Transient (+ prior worker-restart claim loss) | pending |
| 5 | `ccef6e62` | QM5_21502 XAUUSD.DWX | Transient | pending |
| 6 | `f07c2e1f` | QM5_11294 XAUUSD.DWX | Transient | pending |
| 7 | `08b4a32d` | QM5_21506 XAUUSD.DWX | Transient | pending |
| 8 | `bf2dab64` | QM5_20086 NDX.DWX | Transient | pending — no live Q09 PASS predecessor row found yet; needs re-check before enqueue |
| 9 | `02c82887` | QM5_10916 GDAXI.DWX | Transient | pending |
| 11 | `daf3212d` | QM5_20086 EURUSD.DWX | Transient | pending — same predecessor caveat as #8 |
| 13 | `c8f1f977` | QM5_21505 XAGUSD.DWX | Transient | pending |

Two canaries were enqueued live in this session (headroom checked via
`farmctl.py mt5-slots`: only 2/10 terminals occupied at the time, one by a
long-run expansion `463fa52a` on T5, one by an unrelated `QM5_10939` Q02 run on
T3) to validate the fix before committing to the remaining batch, per the
"Re-Runs nur append-only und batch-weise mit Headroom" constraint. **Next
step:** once the two canaries land (PASS, REVIEW_REQUIRED-for-a-real-reason, or
another clean receipt path — anything except the same opaque
`TransientCellError` blanking all 8 cells again), re-enqueue the remaining 9
Transient-class rows in 2-3 more small batches, re-checking `mt5-slots`
occupancy before each batch. Row `73b21148` is excluded pending a separate
QM5_9936 EA review/rebuild ticket; rows `bf2dab64`/`daf3212d` (both QM5_20086)
need their Q09 PASS predecessor row identity re-confirmed before enqueue since
none was found on the first lookup pass.

## Evidence / source references

- `tools/strategy_farm/q09_news_runner.py:2396-2551` (`_production_dispatch_cell`), `:2112-2119` (`_latest_summary`), `:1981-2016` (effective-input validation), `:1602-1695` (`collect_run_plan_status` verdict emission), `:80`/`:2799-2866` (retry ceiling)
- `tools/strategy_farm/farmctl.py:671-700` (`_replace_reservation_file` + retry constants), `:800-843` (`set_terminal_reservation`/`release_terminal_reservation`)
- `tools/strategy_farm/custom_history_smoke_admission.py:44-198` (`reserve_smoke_terminal`)
- `framework/scripts/run_smoke.ps1:704` (admission-gate throw)
- `D:/QM/reports/work_items/73b21148-65be-4aad-a2dd-fb7c2f22e9bc/q09_contract_v3/cells/policy_on__m3__c1__s17/failure_attempts/attempt_0001/` (WinError 5 reproduction)
- `D:/QM/reports/work_items/{463fa52a-33fa-4d23-b318-dda3d73b12e1,e58b8c4c-3894-4aa7-8c9f-fd2d34ac3ebe,9416f0ce-ede3-457e-bf9a-5ed9f892e177}/q09_contract_v3/` (expansion contrast)
- `tools/strategy_farm/tests/test_farmctl_terminal_reservation_retry.py` (regression test, 4/4 pass)
- Related memory: [[project_qm_ceo_session_review_drain_throughput_2026-08-24]], [[project_qm_xcu_coverage_trip_2026-08-16]]
