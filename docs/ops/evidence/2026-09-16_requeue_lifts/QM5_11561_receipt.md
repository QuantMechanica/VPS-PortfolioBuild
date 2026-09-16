# Receipt — OWNER-DEC-REQUEUE-LIFT-20260916 / D2A — QM5_11561 Q02 requeue lift

- Owner decision id: `OWNER-DEC-REQUEUE-LIFT-20260916` (D2A, APPROVED no conditions)
- Operator: `kimi-interim` (Kimi interim delegation, QuantMechanica)
- EA: `QM5_11561` (slug `QM5_11561_singh-good-morning-asia-d1-usdjpy`, USDJPY.DWX D1, single-symbol)
- Date (UTC): 2026-09-16

## 1. Governed exclusion lift (hash-bound)

File: `D:\QM\strategy_farm\state\requeue_excluded_eas.txt`

| | sha256 | bytes |
|---|---|---|
| before lift | `c08d677edacd3a4db7c5cb6cab868cc05ebe05a0648edf5d7d55dadaf8baf84a` | 2179 |
| after lift | `3f092f0a5029f483da2d25086245ecb53ebe1be79c28245b0451d93b6c45f3f3` | 2169 |

- Removed exactly one line: `QM5_11561` (byte-exact removal of `QM5_11561\n`; occurrence
  count asserted == 1 before write; all other bytes untouched; file still contains the
  mixed LF/CRLF endings it had before).
- No other EA line was touched. `QM5_11731` line intentionally left in place (see D2B receipt).
- Backup of prior bytes: `requeue_excluded_eas.txt.before_D2A_lift` (this directory),
  sha256 `c08d677edacd3a4db7c5cb6cab868cc05ebe05a0648edf5d7d55dadaf8baf84a` — identical to
  the before-hash above.
- Machine-readable: `d2a_lift_hashes.json` (this directory).

## 2. Canonical Q02 enqueue

Command (run from `C:\QM\repo`):

```
python -X utf8 tools/strategy_farm/farmctl.py enqueue-backtest \
  --review-task-id 6fde3d7b-bf3c-4c14-bf38-5d7b2d8de92a --phase Q02
```

Result (full JSON: `d2a_enqueue_result.json`):

- `enqueued: true`
- parent task: `3262b0b1-86f4-4edb-aed8-30bb2ba77584` (kind `backtest_p2`)
- work item created: **`132aca67-b907-4d34-a232-cf972de4fb32`** — USDJPY.DWX, setfile
  `framework\EAs\QM5_11561_singh-good-morning-asia-d1-usdjpy\sets\QM5_11561_singh-good-morning-asia-d1-usdjpy_USDJPY.DWX_D1_backtest.set`
- history window 2017–2022 (first year 2017, last year 2026); custom-history archive
  admission ACTIVE for USDJPY.DWX (108 rows); `priority_track: true` (first-Q02 cohort);
- `work_items_skipped: []`; Q01 smoke admission satisfied (latest build_ea `d1c384ae-…`
  smoke_result `passed`, recorded in the payload's admission gate at enqueue time).

## 3. Claim verification (no manual claim performed)

- Work item created 06:28:32Z; worker **T8** claimed it at **06:28:35Z** (3 s) —
  `terminal_worker_T8.log` line `claimed_item_id: 132aca67-…`, `claimed: true`.
- DB row: `status=active`, `claimed_by=T8`, `claimed_by_worker_pid=10960`;
  tester child process created 06:28:53Z (`next_child_process_created`, child pid **21040**).
- Custom-history copy-on-claim audit sha256 `87b10ee5ebb7eaa3b813c28fc638fffaa50d19fc8e7c5058f8ba28d2eac0be89`
  (pre == post copy).
- Second poll (~06:31Z): still `active`, attempt_count 0 — run in progress under the
  7200 s timeout. Report dir `D:\QM\reports\pipeline\QM5_11561*\Q02\` not yet written
  (expected: tester writes on completion).

## 4. No historical verdict rewritten

EA had **zero** prior work items of any kind (verified by DB read before enqueue). The
operation created only new rows (one `backtest_p2` task + one pending→active Q02 work
item). Nothing was requeued, superseded, or invalidated.

## Status at report time

Q02 backtest actively running on terminal T8 (worker PID 10960). Enqueue + claim legs
of D2A are complete; pipeline economics (PASS/FAIL) are for Q02 to decide.
