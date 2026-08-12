# Codex brief — canary: are the 1,256 stranded Q02 pairs recoverable?

Date: 2026-07-27
Priority: high. OWNER approved the canary directly.

## The finding this tests

Full evidence: `docs/ops/evidence/2026-07-27_stranded_eas_q02.md` (commit on
`agents/board-advisor`). In short:

**1,256 (EA, symbol) pairs across 442 distinct EAs hold only `INFRA_FAIL` at Q02, have
no real verdict, and have nothing queued.** All 442 have a real source directory, so
these are not registry ghosts. 137 of the EAs progressed at some other phase; the
remaining **~305 have no completed work item anywhere** — they entered the factory and
silently fell out.

Cohorts by last Q02 activity: **795 pairs in June 2026, 461 in July 2026.**

Sleeve supply is the binding constraint on the FTMO programme (15 gate-clean sleeves,
best FUND_SCORE 0.41 against a target of 1.0). If these are recoverable, this is the
largest untapped candidate pool in the operation.

**Recoverability is NOT established and must not be assumed.** The June mass-failure
cause looks fixed — the rate fell from ~1,453/day in June to ~42/day in July, a 35x
reduction — but these rows were never retried after that fix. The 2026-07-26 root-cause
work also found genuinely deterministic per-EA defects (`QM5_11896` failed 119 of 119
attempts). Both outcomes are plausible and the canary is how we find out.

## What to run

**Exactly 10 pairs. Not 11, not 100.** This is a probe, not a recovery.

Selection — do this deliberately, and record why each was chosen:

- **6 from the July cohort, 4 from the June cohort.** The July half matters more: the
  June cause appears fixed, so a July failure suggests a *second, still-active*
  mechanism. That is the more valuable information.
- Spread across **distinct EAs** (no two pairs from the same EA) and across **distinct
  symbols**, so a single bad symbol or a single bad EA cannot dominate the result.
- Avoid `QM5_11896` and any EA already known to be a deterministic failure — we are
  testing the unknown population, not re-confirming a known negative.
- Include at least one high-infra-count pair (e.g. `QM5_9940/SP500` at 37 rows,
  `QM5_10485/USDJPY` at 26) — if those recover, the pattern is broadly transient.

Then requeue those 10 through the **normal governed path** and let the factory run them.
Do not hand-run them on a reserved terminal; the point is to test the ordinary pipeline.

## What to report

For each of the 10: the outcome, and if it failed again, the **mechanism** — from the
row-bound aggregate and the payload `verdict_reason`, not from inference. Then answer:

1. **What fraction recovered?** This is the headline.
2. **Do June and July behave differently?** If July fails while June recovers, name the
   second mechanism. That is the most important possible finding here.
3. **Is there a common cause among the failures**, or are they individually distinct?
4. **What would recovering the remaining 1,246 cost** in tester time, given the queue is
   currently draining (net negative on 8 of the last 10 days) and holds ~2,073 pending?

## The durable fix, which matters more than the canary

Whatever the canary shows, **nothing currently watches for this class**. A pair that
exhausts its retries leaves no queued successor and no alert; it simply stops existing as
far as the pipeline is concerned. That is why 442 EAs went missing without anyone
noticing.

Add detection: a pair with no real verdict, no queued successor, and exhausted retries
should raise a health-check invariant. `farmctl health` already runs pipeline invariants
and is the natural home — extend it rather than building something new. Report the count
it surfaces on first run.

This detection is required **regardless of the canary result** and should ship even if
every one of the 10 fails.

## Constraints

- **Requeue exactly 10 pairs.** Do NOT mass-requeue. Recovering the other 1,246 is a
  capacity decision that belongs to OWNER, not to this task.
- Do NOT run `Factory_OFF.ps1` or `Factory_ON.ps1`.
- **T5 is under repair and T9 is reserved** for a joint backtest — do not touch either.
  Never `C:/QM/mt5/T_Live`.
- Do NOT re-import `.DWX` history.
- A fix that reduces MT5 saturation is a regression.
- Commit with explicit pathspecs in labelled commits, not via the pump.
- Evidence over claims: every outcome needs a work-item id and an aggregate path.

## Deliverable

`docs/ops/evidence/2026-07-27_stranded_canary_result.md`: the 10 chosen pairs with the
reason each was chosen, the outcome and mechanism per pair, the four answers above, and
the health-check invariant with the count it surfaces.
