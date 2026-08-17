# The poison-pill quarantine identifies 186 dead triples and parks none (2026-08-17)

## What the mechanism says

`tools/strategy_farm/poison_pill_quarantine.py` exists to park deterministic infrastructure
poison pills: an `(EA, symbol, phase)` triple with **five or more consecutive identical
`INFRA_FAIL` verdicts and no merit verdict (`PASS`/`FAIL`) ever**. Its writer,
`refresh_pending`, is called from `farmctl.dispatch_work_items` (`farmctl.py:9860-9861`) on
**every dispatch tick** that has free terminals and an open calendar gate — so it runs
constantly. The claim selector honours the table (`farmctl.py:1171`).

Run today at threshold 5, stable across three consecutive invocations:

| | |
|---|---:|
| eligible triples | **186** |
| distinct EAs | **116** |
| failed runs inside those streaks | **1,266** |
| triples with any merit verdict ever | **0** |
| **rows in `poison_pill_quarantine`** | **0** |

All 186 are Q02. Streak distribution: 2 at 5, **109 at 6**, 56 at 7, 3 at 9, 3 at 10, 3 at 11,
**10 at 12**.

Reasons are almost uniform — which is what makes them poison rather than noise:

| n | verdict_reason |
|---:|---|
| **183** | `summary_missing_retries_exhausted` |
| 2 | `run_smoke_fail:TIMEOUT;INCOMPLETE_RUNS` |
| 1 | `run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS` |

So the detector works and the writer is wired, yet nothing is ever parked. Census:
`artifacts/poison_pill_eligible_census_20260817.json`.

## Severity, bounded honestly

The headline number is alarming and the practical harm is much smaller, because of where those
rows sit in the queue:

| Class of the pending row | n |
|---|---:|
| `recovery_class` — sorts last, idle-capped (Operating Rule 22) | **183** |
| `priority_track` — sorts **first**, ahead of everything | **3** |

**183 of 186 are already in the deprioritised idle-only pool.** They are not burning slots in
normal operation; they only run when nothing else is eligible, which currently never happens.
For those the cost is bookkeeping: they inflate the pending count, they pollute the
stranded-infra census, and they will eventually consume idle capacity — but they are not an
active bleed. That matters, and overstating it would be as wrong as ignoring it.

**The three `priority_track` rows are the real defect.** They are known-dead *and* they jump
ahead of healthy work *and* all three are XAU/XAG baskets, so each one enters the farm-wide
**serialized** basket lane where a single run blocks every other basket for hours. This is the
mechanism behind the basket-lane clog recorded in
`2026-08-17_basket_q02_timeout_clamp_infra_loss.md`.

| Row | EA | Streak | Reason | Disposition |
|---|---|---:|---|---|
| `e2622f78` | QM5_20260 | 6 | `TIMEOUT;INCOMPLETE_RUNS` | **left alone** — plausibly rescued by today's budget raise |
| `4db00c93` | QM5_20236 | 6 | `TIMEOUT;INCOMPLETE_RUNS` | **left alone** — same |
| `382fa0dc` | QM5_20235 | 6 | `ONINIT_FAILED;INCOMPLETE_RUNS` | **held** — no pending fix reaches it |

The two `TIMEOUT` rows accumulated their streaks under the **old** 7,200 s budget. Today's
raise (`d574b6a83`, 2-member basket floor 7,200 s → 14,400 s) is precisely the fix for that
failure mode, so quarantining them would park the work the budget change was meant to rescue.
They get exactly one run under the new budget; their `priority_track` is helpful here because
it makes the answer arrive quickly.

`QM5_20235` is not rescued by anything in flight and was therefore held under
`POISON_PILL_ONINIT_AWAITING_DIAGNOSIS`, claimability verified 0 against the real claim
predicate:

- `reason_classes ['ONINIT_FAILED','INCOMPLETE_RUNS']` with `oninit_failure_detected = true`,
  so it is **correctly classified** — unlike the QM5_410xx cases found earlier today, where the
  detector missed the OnInit wording entirely;
- `attempted_runs 1/3` — it fails before the retry budget is relevant;
- its setfile carries **no exponent notation**, so today's serialiser root cause does not apply
  (checked for all three: none carry it);
- 6 consecutive identical failures, `successes_ever 0`. A seventh identical run blocks every
  other basket for hours and produces nothing.

## The open question, stated rather than guessed

**Why does the table stay empty when its writer runs on every tick?** `refresh_pending` calls
the same `scan` I ran and upserts every eligible result, so the criteria are identical and the
code path is reached. Candidate explanations — none verified, and I am not going to assert one:

- the dispatch path in production is not `dispatch_work_items`;
- the `free_terminals and calendar_gate_open` guard rarely holds at the moment the tick runs;
- the connection used there does not persist the write.

This needs a direct test — instrument or manually invoke the writer and observe the table —
which is implementation work, dispatched rather than inferred.

*Method note and correction of my own error: my first attempt to read the scan output reported
**0 eligible**. That was my bug — I looked for JSON keys `quarantined`/`eligible`/`rows` and
fell back to an empty list, while the real key is `items`. The `count` field said 186 the whole
time. Three re-runs confirmed 186. I had briefly also hypothesised that eligibility is lost when
a pending row gets claimed; that is refuted — both sample triples still hold pending rows.*

## What must change

1. **Make the writer actually write**, or state why it must not. A safety mechanism that
   identifies 186 poison pills and parks none is worse than absent, because its presence
   implies the problem is handled.
2. **`priority_track` must not survive on a poison-eligible triple.** A known-dead row sorting
   ahead of healthy work is the one variant of this defect that costs real throughput, and it is
   cheap to check: three rows today.
3. **`summary_missing_retries_exhausted` deserves its own disposition.** 183 triples share it —
   this is the documented Q02 graveyard above the hourly sweep's retry cap. Those rows will
   never be re-run by the sweep and never be judged; they are neither recoverable nor terminal.
   They should be sealed with a verdict rather than left pending forever.
4. Feed this into the deep-phase recovery plan: the 1,562 "recoverable" pairs must be filtered
   against the poison criterion before any wave scales, or waves will re-run known-dead work.

## Evidence

- `artifacts/poison_pill_eligible_census_20260817.json`
- `tools/strategy_farm/poison_pill_quarantine.py` (criterion at `:69-101`, writer at `:114-133`)
- `tools/strategy_farm/farmctl.py:9860-9861` (writer call site), `:1171` (claim predicate)
- `D:\QM\reports\work_items\218be3c9-…\QM5_20235\20260814_163348\summary.json`
- Related: `2026-08-17_basket_q02_timeout_clamp_infra_loss.md`,
  `2026-08-17_stranded_infra_recovery_wave1.md`
