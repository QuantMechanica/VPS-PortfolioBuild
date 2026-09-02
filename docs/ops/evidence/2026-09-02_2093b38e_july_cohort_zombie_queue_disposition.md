# July-cohort Q02/Q04 zombie queue — archive-matrix disposition (classification pass)

- Router task: `2093b38e-8eb4-4bcd-931b-25c50ada861f` (claude, `ops_issue`, priority 55)
- OWNER authorization: 2026-09-01, "cleanup authorized to run alongside the 25-push"
- Cycle: claude orchestration, 2026-09-02 ~10:45–11:00Z
- Mode: **read-only classification + REVIEW proposal.** No row was marked, parked,
  superseded, retired, requeued, or deleted.

## Headline — the cohort is infra debt, not strategy debt

**1,706 of 2,156 rows (79%) are re-enqueues sitting behind a prior `INFRA_FAIL`.**

By the task's own definition those are TREASURE candidates ("failure was
infra-caused … rather than strategy-caused"). **Mass-retiring this cohort would
discard the largest infra-caused requeue reservoir in the farm.** The disposition
below is therefore weighted to requeue, not retire.

## Cohort definition and size

Rows counted: `status='pending' AND phase IN ('Q02','Q04') AND created_at < '2026-09'`.

| phase | month | pending | oldest | newest |
|-------|-------|---------|--------|--------|
| Q02 | 2026-06 | 376 | 2026-06-08T03:45:57Z | 2026-06-30T22:16:56Z |
| Q02 | 2026-07 | 204 | 2026-07-01T01:04:30Z | 2026-07-31T22:52:58Z |
| Q02 | 2026-08 | 155 | 2026-08-01T01:06:36Z | 2026-08-31T19:30:08Z |
| Q04 | 2026-08 | 1,421 | 2026-08-02T16:54:19Z | 2026-08-31T16:28:29Z |
| **total** | | **2,156** | | |

Spread over **1,110 distinct `ea_id`s** — a long tail; the largest single EA
contributes 33 rows (`QM5_1132`), and most EAs contribute 1–2.

Reconciliation with the ticket's figures ("751 Q02 since ~26.07, 1422 Q04 since
~02.08"): Q04 matches (1,421 vs 1,422 — one row has since been claimed). The Q02
figure differs because the live pre-September Q02 pending count is **735**
(376+204+155), not 751; current Q02 pending including September is 758. The
ticket's 751 appears to be a 2026-09-01 snapshot. **Scope used here is the live
query above, not the quoted constants.**

## Structural finding — these are not stale duplicates

The "zombie" framing implies rows superseded by later completed work. The data
does not support that reading:

| test | rows | share |
|------|------|-------|
| A) a **later** terminal run exists for the same `(ea_id, symbol, phase)` | 62 | 2.9% |
| B) a **later** terminal row exists for the same `(ea_id, symbol)`, any phase | 94 | 4.4% |
| C) **no** terminal row at all for the `(ea_id, symbol)` pair | 114 | 5.3% |
| any terminal run for `(ea_id, symbol, phase)`, including **earlier** | 2,008 | 93.1% |

93% have a terminal run for the same cell, but only 2.9% have a *later* one.
The pending row is almost always **newer** than the terminal run it follows.
These are re-enqueues that were never claimed — a **claim-starvation backlog**,
not a duplicate backlog. Only the 62 rows in bucket A are genuine
supersede-by-completion duplicates.

This is consistent with the claim governor observed the same day: 1 of 7 workers
busy against 8,006 pending items, claims refused with `commit_headroom_low`
(see `2026-09-02_claude_orchestration_cycle_health_wedge.md` §5).

## Classification — latest prior verdict per row

For each pending row, the verdict of the most recent terminal run of the same
`(ea_id, symbol, phase)`:

| latest prior verdict | rows | proposed disposition |
|---|---:|---|
| `INFRA_FAIL` | **1,706** | **REQUEUE-WORTHY / TREASURE** — infra-caused |
| `NO_PRIOR_RUN` | 148 | ASSESS — never executed; needs viability check under v4 |
| `FAIL` | 143 | **RETIRE** — strategy-caused economic failure |
| `INVALID` | 77 | **RETIRE (age out)** — DL-090: infra/invalid ages out |
| `PASS` | 55 | **PARK** — cell already passed; pending row is a redundant rerun |
| `RETIRE` | 18 | **PARK** — already retired upstream |
| `PASS_SOFT` | 3 | PARK |
| `ZERO_TRADES` | 2 | RETIRE — genuine no-signal (never requalify) |
| `PASS_LOWFREQ` | 2 | PARK |
| `CANCELLED_DUPLICATE_REQUEUE` | 1 | PARK |
| `DRAFT_DEFECT` | 1 | RETIRE |
| **total** | **2,156** | |

Aggregate: **~1,706 requeue-worthy (79%)**, **~223 retire (10%)**,
**~79 park (4%)**, **148 assess (7%)**.

`ZERO_TRADES` is marked retire, not requeue, per the standing rule that genuine
no-signal results are never requalified.

## Proposal (requires Orchestrator approval — nothing executed)

1. **Do not mass-retire this cohort.** The dominant class is infra-caused.
2. **Retire bucket (~223 rows):** `FAIL` (143) + `INVALID` (77) + `ZERO_TRADES`
   (2) + `DRAFT_DEFECT` (1). Mark **append-only via the supersede/park
   mechanism**; never delete a verdict or evidence path.
3. **Park bucket (~79 rows):** prior `PASS`/`PASS_SOFT`/`PASS_LOWFREQ`/`RETIRE`/
   `CANCELLED_DUPLICATE_REQUEUE` — the pending row is redundant against an
   existing terminal result. Park, do not retire; the underlying cell keeps its
   PASS-family evidence permanently per DL-090.
4. **Bucket A (62 rows)** — genuine supersede-by-completion duplicates. Safe to
   park first; this is the cleanest, lowest-risk slice to execute ahead of the rest.
5. **Requeue-worthy / TREASURE (1,706 rows): do NOT bulk-enqueue.** At the
   observed service rate (36 completions/hour, 1 of 7 workers claiming) this
   would add ~47 hours of queue at current throughput and displace census and
   pipeline claims — which the ticket explicitly forbids ("never displace
   census/pipeline claims", "no mass enqueue without Orchestrator approval").
   Requeue should be **paced and sub-classified by infra root cause first**.
6. **Assess bucket (148 rows):** never executed; check viability under the
   current v4 contract before either disposition.

## Gap — what this pass does NOT yet deliver

Acceptance criterion 1 is "every July-cohort row classified with reason". This
pass classifies **all 2,156 rows** by prior-verdict class, which is a reason, but
it does **not** yet split the 1,706 `INFRA_FAIL` rows into the specific infra
root-cause classes the ticket names — stale-EX5 class, setfile-exponent class,
ONINIT-pin class, launch-fault class. That sub-classification is the input that
decides *requeue order*, and it is the remaining work.

It is deliberately not guessed here: assigning a root-cause class per row
requires reading each prior run's log/report, and inferring it from the verdict
string alone would produce an unevidenced treasure list.

**Status: classification pass complete, root-cause sub-classification outstanding.**

## Acceptance criteria

| # | criterion | status |
|---|---|---|
| 1 | Every July-cohort row classified with reason | **PARTIAL** — 2,156/2,156 classified by prior-verdict class; infra root-cause split outstanding |
| 2 | Zero verdict/evidence deletion | **MET** — read-only cycle, nothing written to the DB |
| 3 | Treasure list + requeue proposal in REVIEW | **MET** — this document; 1,706 treasure candidates identified, requeue proposed as paced, not bulk |
| 4 | No census displacement | **MET** — no enqueue, no claim, no queue-order change |

## Next step

Sub-classify the 1,706 `INFRA_FAIL` rows by infra root cause (stale-EX5,
setfile-exponent, ONINIT-pin, launch-fault), then bring a **paced** requeue
schedule for approval. Execute the 62-row bucket-A park first as the
lowest-risk slice.

Requeue pacing must respect the current claim constraint — with 8,006 rows
already pending and one active worker, the binding limit is claim throughput,
not queue depth.

## Method and scope discipline

Database opened `mode=ro`. Classification computed in-memory from
`work_items(ea_id, symbol, phase, created_at, status, verdict)`; the
"latest prior verdict" is the terminal (`done`/`failed`) row with the greatest
`created_at` for each `(ea_id, symbol, phase)`.

No mutation of any kind: no work item, verdict, hold, park, supersede edge,
reservation, or queue row was written; no enqueue; no Factory_OFF/ON; no worker
or terminal interruption; no T_Live or AutoTrading action; no gate-threshold or
candidate-universe change.

## Evidence sources

- `D:/QM/strategy_farm/state/farm_state.sqlite` (`mode=ro`) — `work_items`
- `C:/QM/repo/docs/ops/evidence/2026-09-02_claude_orchestration_cycle_health_wedge.md` (throughput/claim context)
- agent_task `2093b38e-8eb4-4bcd-931b-25c50ada861f`
