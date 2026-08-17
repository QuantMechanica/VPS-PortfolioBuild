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
2. **Do not strip the `priority_track` flag — fixing (1) already covers it.** My first
   formulation said the flag "must not survive on a poison-eligible triple". That was wrong, and
   the reason matters: `tools/strategy_farm/set_priority_track.py` describes itself as a
   *"Dry-run-first exact-ID controller for OWNER priority-track backfills"*, and its only
   reference to `poison_pill_quarantine` is line 312, where the table appears in a snapshot list
   beside `work_items` and `work_item_holds` — **not** a filter. So those three flags were most
   likely set by an OWNER-authorised backfill, and having an agent clear them would quietly undo
   an OWNER decision.

   It is also unnecessary. Ordering only decides *which claimable row goes first*; a quarantined
   triple is **not claimable at all** (`farmctl.py:1171`). Once the writer works, a poison triple
   cannot be served regardless of how it sorts. If ordering still turns out to matter after
   quarantine functions, that is a finding to report — and the flag decision stays OWNER's.
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

## Implementation closeout (Codex, 2026-08-17 13:00 CEST)

The writer now writes, and the live result establishes the original root cause directly:
`refresh_pending` was only called by `farmctl.dispatch_work_items` after both
`free_terminals` and `calendar_gate_open` were true. The resident terminal-worker claim path
deliberately does not refresh the table. A manual invocation of the same writer, after the
two protected timeout observations were marked, changed active quarantine rows from **0 to
184** in 2.5 seconds. This rules out a persistence/commit defect; the production call-site
guard was the reason the table remained empty.

Before the live write, a point-in-time SQLite backup was made at
`D:\QM\strategy_farm\state\backups\farm_state_before_poison_pill_writer_20260817T105932Z.sqlite`
(SHA-256 `f05899061a28400daa3c6851dc0c89a8b7e6026f6f3a2353a6cdd5d3dca97314`). The apply receipt
is `D:\QM\strategy_farm\artifacts\ops\poison_pill_apply_20260817.json`.

### Direct before/after state

| Measure | Before | After |
|---|---:|---:|
| active `poison_pill_quarantine` rows | 0 | **184** |
| pending rows sealed by poison disposition | 0 | **183** |
| protected timeout observations still pending | 2 | **2** |
| protected timeout observations quarantined | 0 | **0** |
| held QM5_20235 OnInit triple quarantined | 0 | **1** |

The 183 `summary_missing_retries_exhausted` successors are now `status=failed,
verdict=INVALID`. `INVALID` is the honest non-merit disposition: five or more identical
no-summary infrastructure failures prove that the row cannot produce admissible evidence;
they do **not** prove strategy merit `PASS` or `FAIL`. No requeue wave was created.

The two old-budget timeout rows (`e2622f78`, `4db00c93`) retain
`priority_track=true` and carry a one-observation marker plus
`poison_pill_priority_override=true`. The canonical claim query reports effective
`_priority_track_rank=1` for both (live positions 170 and 171), so they no longer jump ahead
of healthy work. They remain unquarantined and pending for one run under the 14,400-second
two-member basket floor. Protection expires automatically when a worker stamps a
`started_at_iso` later than the marker time; if that observation returns to pending without
a merit verdict, the next refresh quarantines it. The OWNER flag itself is not deleted.

The held QM5_20235 row (`382fa0dc`) is actively quarantined and absent from the canonical
claim selector, in addition to its existing explicit hold.

Finally, `requeue_stranded_infra.py` now filters active poison triples during wave planning
and repeats the check under the apply transaction. A recovery plan created before quarantine
cannot reintroduce a known-dead triple at apply time.

Focused verification:

- `test_poison_pill_quarantine.py` + `test_ultracode_wsa_claim.py`: **35 passed**;
- `test_requeue_stranded_infra.py`: **24 passed** after adding the quarantine-wave case;
- `py_compile` and `git diff --check`: pass.
