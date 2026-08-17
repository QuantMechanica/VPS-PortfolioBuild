# Point 1.11 — the "withdraw or hold" question has an empty population, and the sweep cannot consult a review at all

v6 1.11 asks, of the review gate before pipeline entry: *"was passiert mit Zeilen, die zwischen
Build und Review-FAIL bereits eingereiht wurden — zurückziehen oder halten?"*

**Measured answer: that set is empty.** Every live row under an open review was enqueued **after**
the review opened, not before. A gate at enqueue time catches 100% of the current population, and
1.11 needs no retraction policy to ship.

## The measurement

Over all open `review_ea` tasks and the pipeline rows of their EAs:

| | rows |
|---|---:|
| live rows (pending/active) under an open `review_ea` | **23** |
| …enqueued **after** the review opened | **23** |
| …enqueued **before** it opened — the withdraw-or-hold set | **0** |

Nine EAs, all in the QM5_33xxx/34xxx cohort. Every one of the 23 rows was created in a single sweep
at **19:52:58**, while the reviews had been open since 18:42:44–19:51:44. The newest case is the
sharpest: `4309d167` opened for QM5_34007 at **19:51:44**, and two Q02 rows for that EA were
enqueued **74 seconds later**.

Widening the scope from `review_ea` to every open task in REVIEW state (including `build_ea`) gives
**51 live rows under 20 open tasks**, one of them running at the time of measurement
(QM5_33002, active on T2). The 23 is the figure that belongs to 1.11; the 51 is the blast radius.

## Why: the sweep has no way to consult a review

`tools/strategy_farm/sweep_enqueue_built_eas.py` contains **no occurrence** of `agent_tasks`,
`review_verdict`, or `REVIEW`. The only match for "review" in the whole file is a log string at
`:681` ("manual performance/budget review required"). It selects from `work_items` and the built-EA
inventory alone.

So this is not a case of a gate being consulted and returning the wrong answer, and not a race
between two writers. **The review state is simply not an input to the enqueue decision.** That
makes 1.11 an additive change — a join and a predicate — rather than a repair of existing logic.

## Control: QM5_21506, and a correction to how I described it

`ffcc2666` (QM5_21506 / XAUUSD / Q02) enqueued **18:52:58**, completed **PASS 19:17:46** on the
pre-repair binary `0AD3B11F…`. The task history for that EA:

| task | type | state | opened | row enqueued |
|---|---|---|---|---|
| `febe5550`, `2ca6b5b7`, `6be9b5cf`, `78f0cdff`, `93a6aed4` | build_ea | **BLOCKED** | 17:03:24 | 1h50m later |
| `f45c976d` | review_ea | APPROVED | 17:54:33 | 58m later |
| `9ecec938` | ops_issue | APPROVED | 18:57:55 | (repair ticket, after the row) |

**Correction to my earlier reporting:** I described these rows as enqueued "after BLOCKED reviews".
Precisely, the BLOCKED tasks are `build_ea` tasks, and the EA's `review_ea` task was *APPROVED* at
17:54:33 — before the hedge defect was known. The substance is unchanged and arguably worse: five
BLOCKED tasks existed for that EA for nearly two hours and the sweep enqueued anyway, because it
reads no task state of any type. But "a BLOCKED review_ea was ignored" would have been the wrong
sentence, and E3's wording ("jeder Review-FAIL") should be read as covering any task-level FAIL or
BLOCK, not the `review_ea` type alone.

## What this fixes about 1.11's scope

- **No retraction policy needed.** The open sub-question — withdraw already-queued rows, or let
  them run — has no instances. If the gate is placed at enqueue, nothing has to be un-enqueued.
- **The gate must key on task state, not task type.** The one real case was blocked at `build_ea`,
  not `review_ea`. A predicate that only inspects `review_ea` would have let `ffcc2666` through.
- **The 23 rows are the immediate test set.** They are pending now; a gate landing before the next
  sweep would hold them, and each of the nine reviews closing APPROVED would release them.

## My own error in this measurement

The first pass reported **1 of 19** review tasks having live work. That was wrong by inversion — the
true figure is 19 of 20. Payloads carry the EA as a bare integer (`33002`) while `work_items` keys
`QM5_33002`, so every lookup returned zero and I nearly filed "the backlog is not burning". The
second pass then compared row timestamps against a mix of `build_ea` tasks (routed together in one
17:03:25 batch) and `review_ea` tasks, which is the wrong event; `agent_tasks.created_at` is
genuine, my selection was not. The figures above are from the third pass, restricted to `review_ea`.

Same failure shape as this morning's registry check: a zero produced by a key-format mismatch,
believed for one round.

## Evidence

- `tools/strategy_farm/sweep_enqueue_built_eas.py` — no `agent_tasks` / `REVIEW` reference; `:210`,
  `:228`, `:249`, `:537-552` are the selection queries
- `agent_tasks` — 9 open `review_ea`, created 18:42:44–19:51:44
- `work_items` — 23 pending rows, all created 19:52:58
- control `ffcc2666-5365-47fd-8670-ba79971381c9`; task history above
- corrects the framing in `docs/ops/evidence/9ecec938_qm5_21506_21507_21513_atomic_reverse_repair_2026-08-17.md`
  and my own earlier round report ("BLOCKED review" → "BLOCKED build_ea task")
