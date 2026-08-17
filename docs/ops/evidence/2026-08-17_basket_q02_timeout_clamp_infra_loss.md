# A 4-hour clamp destroys roughly 40% of all basket Q02 evidence (2026-08-17)

## Headline

The logical-basket Q02 class costs **2 to 4 hours per run**. Its timeout budget is
clamped at **exactly 4 hours**. The cost distribution straddles the clamp, so which
basket produces evidence and which dies as `INFRA_FAIL` is decided by the clamp, not by
the strategy.

Measured over every basket Q02 row that ever reached a terminal state:

| Verdict | n |
|---|---|
| PASS | 190 |
| **INFRA_FAIL** | **134** |
| FAIL | 51 |
| RETIRE | 12 |
| ZERO_TRADES | 9 |
| DRAFT_DEFECT | 6 |
| INVALID | 2 |

`INFRA_FAIL` is **33% of all basket Q02 outcomes** and **41% of the PASS+INFRA_FAIL
pool** — the pool where the only difference is whether the run finished.

## The mechanism, exactly

`farmctl.py::_p2_full_timeout_seconds` builds the budget from three sources:

```
P2_FULL_TIMEOUT_MIN_SECONDS = 7200    # 2h flat floor          (farmctl.py:4445)
P2_FULL_TIMEOUT_MAX_SECONDS = 14400   # 4h clamp on the estimate (farmctl.py:4446)
```

1. **Flat floor: 2h.**
2. **Member-count floor:** `min(25200, 1800 + members * 600)`. For a **2-member** basket
   this is `1800 + 1200 = 3000s = 50 min` — *less than the flat floor*, so
   `max(7200, 3000)` leaves it at 2h. **The member formula contributes nothing for
   2-member baskets.** It was written for the 28-symbol T-WIN case.
3. **Prescreen-scaled estimate:** the only term that tracks observed runtime — and it is
   returned as `min(P2_FULL_TIMEOUT_MAX_SECONDS, estimated)`, i.e. **clamped at 4h**.
4. **`timeout_min` payload override:** may extend to 25200s (7h), `farmctl.py:4763`. This
   is the only escape, and it is **opt-in** — nothing stamps it automatically.

So every 2-member basket gets **either 2h** (no prescreen data) **or at most 4h** (with
it), unless a human stamps `timeout_min`.

## The measurement that matches the constants

Run duration derived from the evidence summary (`run_tag` = run start in local wall time,
`timestamp_utc` = summary write time):

**Deaths land on the constants, to the second.**

| EA | timeout runs | median | max |
|---|---|---|---|
| QM5_20233 | 11 | 4.00h | 9.00h |
| QM5_20236 | 11 | **4.00h** | **4.01h** |
| QM5_20206 | 10 | 4.00h | 4.00h |
| QM5_20234 | 10 | 4.00h | 4.00h |
| QM5_20192 | 9 | 4.00h | 4.00h |
| QM5_20260 | 9 | 4.00h | 4.00h |
| QM5_20235 | 12 | 2.01h | 2.15h |
| QM5_12615 | 5 | 2.02h | 2.02h |

Eleven runs of QM5_20236 at 4.00h with 0.01h of spread is not a strategy outcome. 4.00h
is `P2_FULL_TIMEOUT_MAX_SECONDS`; 2.01h is `P2_FULL_TIMEOUT_MIN_SECONDS`. The two death
clusters *are* the two constants.

**Completions spread continuously, and they sit just under the clamp.**

| Verdict | n | median | max | over 1h |
|---|---|---|---|---|
| PASS | 40 | 2.61h | **3.91h** | 40/40 |
| FAIL | 40 | 2.13h | 2.65h | 40/40 |
| ZERO_TRADES | 9 | 2.05h | 2.12h | 9/9 |

The slowest PASS on record finished at **3.91h** — nine minutes inside the 4h clamp. That
is the whole story: the class's real cost runs right up to the clamp, and everything
above it is recorded as an infrastructure failure.

*Method note: the durations carry a uniform +2h term from reading `run_tag` as local
time. The evidence that the term is right is that the deaths then land exactly on 7200s
and 14400s — two independent constants, hit to within 0.01h across 60+ runs.*

## Failure signature confirms a clean timeout, not a broken EA

Across 96 measurable timeout deaths:

| n | signature |
|---|---|
| **69** | `result=FAIL attempts=1/3 marks=none` |
| 12 | `result=FAIL attempts=1/3 marks=oninit_failure,model4_log_marker` |
| 8 | `result=FAIL attempts=3/3 marks=model4_log_marker` |
| 5 | `result=FAIL attempts=3/3 marks=none` |

The dominant case has **no OnInit failure, no log bomb, no error marker at all** — and
stops at **attempt 1 of 3**. The runner is configured for three attempts but the first
attempt consumes the entire budget, so the retry policy is unreachable. A basket never
gets its second attempt.

## What this costs

At least **190 terminal-hours** of measured runtime produced no evidence (96 runs × ≥2h;
~340h on the measured durations). The cost is worse than the raw hours because **basket
execution is serialized farm-wide — only one basket runs at a time** (documented at
`farmctl.py:4786`). A 4-hour dead basket run therefore blocks *all* basket progress for
4 hours, not one terminal out of ten. There are **24 basket rows pending right now**, and
at least eleven of them belong to EAs that have already died this way 2–12 times:

```
QM5_20233 (12 prior)  QM5_20236 (12)  QM5_20206 (12)  QM5_20235 (12)
QM5_20234 (10)        QM5_20260  (9)  QM5_20202  (4)  QM5_20294  (2)
QM5_20291  (1)        QM5_12578  (2)  QM5_41030  (2)
```

Each is queued to die again at the same wall, one after another, in the exclusive lane.

## The one case the budget cannot fix: QM5_41030

`QM5_41030_xauxag-flowdiv` carries `timeout_min: 450` in its payload, so it receives the
**maximum budget the code can grant — 25200s (7h)**. It has now consumed that budget
twice and died both times:

- `5089d0c1` — 2026-08-16 22:24:59, INFRA_FAIL
- `d25b62c2` — 2026-08-17 07:03:49, INFRA_FAIL. Summary: run started `20260817_000333`,
  written `07:03:38Z` → **7h00m05s**, `result=FAIL`, `attempted_runs=1/3`, no error marks.
  Evidence: `D:\QM\reports\work_items\d25b62c2-c22a-4f7a-8697-0ab2a733ceab\QM5_41030\20260817_000333\summary.json`
- `c2636b77` — requeued 07:52:58 with the **same** `timeout_min: 450`. Held (below).

Its sibling `QM5_41031_xauxag-goldlead` is the control: same 2-member XAU/XAG D1 basket,
same 25200s budget, **PASS in 3.15h** on 2026-08-16 23:38, and now advanced to Q04. The
code difference is the entry-evaluation window — `QM5_41030` reads a **six-bar** flow
window per evaluation (`CopyRates` at `:646`, `:649`), `QM5_41031` a **two-close** return
window (`:615`, `:618`). Roughly 3× the foreign-symbol read work, and the observed cost
ratio is ≥2.2×.

QM5_41030 is therefore not a budget victim — it is structurally too expensive, and the
cost compounds downstream: at >7h for one Q02 run, its Q07 five-seed stage would need
35h+ of the exclusive basket lane.

## Actions taken

1. **`c2636b77` held** with `hold_code=BASKET_BUDGET_CAP_EXCEEDED`. A third attempt under
   an unchanged budget is deterministic waste, and it would monopolize the exclusive
   basket lane for 7h.
2. Codex task filed covering the class fix, the circuit breaker, and QM5_41030's cost.

## What must change (for the task)

- **The clamp is the defect.** `P2_FULL_TIMEOUT_MAX_SECONDS = 14400` truncates the only
  term that tracks measured runtime. For multi-member baskets the estimate must be
  allowed to reach the 25200s ceiling that `_payload_timeout_floor_seconds` already
  permits.
- **The member formula is dead code below 9 members** (`1800 + n*600 < 7200` for `n < 9`).
  Either scale it by member *weight* (real-tick volume) as its own comment demands, or
  drop the pretence that it budgets 2-member baskets.
- **A repeat-timeout circuit breaker.** An EA whose Q02 has died at the budget wall N
  times must be parked with a verdict, not requeued into a serialized lane. Twelve
  identical deaths is not a retry policy.
- **Do not fix this by stamping `timeout_min` by hand.** The field also governs the worker
  watchdog, so a wrong value has fleet-wide reach; and an opt-in override that must be
  applied per row is what produced this backlog.

## Related

- `docs/ops/evidence/2026-08-17_mixed_worker_fleet_watchdog_partial_deployment.md` — the
  *outer* 90-minute watchdog defect. Distinct: those deaths cluster at ~1.5h from worker
  process start and are now fixed on 9 of 10 workers. The deaths here are at 2.00h/4.00h
  from run start and are a budget clamp, not a watchdog.
- `farmctl.py:4778-4816` — `_p2_full_timeout_seconds`, including the 2026-07-02 and
  2026-08-16 comments that already name QM5_20206 / 20236 / 20294 as burning every attempt.
