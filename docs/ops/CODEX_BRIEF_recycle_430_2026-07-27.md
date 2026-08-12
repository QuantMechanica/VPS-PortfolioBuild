# Codex brief — work off the 431 RECYCLE tasks, in batches

Date: 2026-07-27
Priority: high. OWNER: "Geh die 430 recycle auch an!"

## What is actually sitting there

`RECYCLE` had no router exit until today, so 431 tasks accumulated in it since
2026-05-28. The exit now exists (`RECYCLE→TODO`, bounded by `recycle_count`, `→BLOCKED`
at cap 3) but was deliberately NOT bulk-applied: 411 are `build_ea` and dumping them
into a 2,057-deep queue would flood the build lane.

Composition:

| task_type | count |
|---|---:|
| build_ea | 411 |
| ops_issue | 13 |
| triage_failure | 3 |
| others (research/review/q02_infra_repair/pipeline_run) | 4 |

By recycle reason:

| count | reason |
|---:|---|
| 297 | `batch adjudication 2026-07-19` — mostly *"Only .mq5 present, no .ex5, no SPEC.md, no magic_numbers.csv row → build not completed"* |
| 77 | `auto-recycle: Gemini v2 rework wave (OWNER 2026-06-03) — rebuild without news-staleness bypass` |
| 13 | `auto-recycle: news-calendar bypass qm_news_stale_max_hours=8…` |
| 10 | `build_ea PASS verdict is false — build is incomplete` |
| 5 | `auto-recycle: build artifact missing (phantom)` |
| ~29 | individually-reasoned singletons |

**The decisive measurement**: of the 411 `build_ea` rows, **311 carry an `ea_id`; all 311
have a source directory under `framework/EAs/`; only 12 have any completed work item.**

So roughly 299 EAs have real source on disk and have never been through the pipeline.
The recycle reasons are **mechanical, not strategic** — a missing `.ex5`, a missing
`SPEC.md`, an unregistered magic row, a news-staleness bypass that must be rebuilt out.
This is unfinished construction, not dead ideas.

Sleeve supply is the binding constraint on everything (15 gate-clean sleeves, best
FUND_SCORE 0.41 against a target of 1.0). Together with the 442 EAs stranded at Q02
(`docs/ops/evidence/2026-07-27_stranded_eas_q02.md`) this is the largest untapped
candidate pool in the operation.

## How to work them off

**Triage first, then complete in batches. Never bulk.**

1. **Triage all 431** into: `COMPLETABLE` (source exists, only mechanical steps missing),
   `NEEDS-SOURCE` (card or provenance incomplete), `RETIRE` (superseded, duplicate, or
   the idea is dead), `NOT-A-BUILD` (the 20 non-`build_ea` rows — dispose individually).
   Commit the triage table before completing anything.

   Calibration from the recent precedent: 25 fabricated-card tasks triaged to
   **19 retire / 4 unblock / 2 need-source**. Expect a large RETIRE share here too, and
   do not force a task into COMPLETABLE to raise the count.

2. **Complete the COMPLETABLE ones in batches of at most 20**, working the governed path
   in strict order: **directories first, then CSV, then regenerate, then verify, then
   compile**, and **serially** — the magic resolver has a known race and duplicate build
   dispatch has previously caused magic collisions. When checking whether an id exists,
   grep anchored on `^<bare_id>,`; an unanchored grep matches substrings and has caused
   false negatives.

3. **The 77 Gemini v2 and 13 news-bypass rows must be rebuilt WITHOUT the
   news-staleness bypass.** `qm_news_stale_max_hours` must not exceed 336. Do not raise
   it to make a build pass; a stale-seed failure is repaired by refreshing the calendar
   copies, not by widening the ceiling.

4. Use `agent_router.py reconcile-exits --apply --state RECYCLE --limit <n>` to release
   only what you are about to work on. Never run it unlimited.

5. **RETIRE decisively.** A task whose card cannot be completed from its recorded source
   goes to `BLOCKED` with the reason. An EA built from an incomplete card is an invented
   strategy, which is worse than no EA.

## What NOT to do

- Do NOT bulk-apply `reconcile-exits --state RECYCLE`. 430 builds into a 2,057-deep Q02
  is exactly the flood this brief exists to prevent.
- Do NOT queue Q02 backtests for what you complete. Completing the build is the
  deliverable; running them is a capacity decision for OWNER, and the queue is already
  deep.
- Do NOT edit an approved strategy card in place to satisfy a validator.
- Do NOT weaken any guardrail — news staleness, `RISK_FIXED` in backtest sets, or the
  build-guardrail check — to make a build pass.

## Constraints

- Do NOT run `Factory_OFF.ps1` or `Factory_ON.ps1`.
- T5 is disabled and under investigation; T9 is reserved. Never `C:/QM/mt5/T_Live`.
- Builds serial, never parallel.
- Commit with explicit pathspecs in labelled commits, not via the pump.
- Evidence over claims: every disposition needs a path or a query.

## Deliverable

`docs/ops/evidence/2026-07-27_recycle_backlog_worked.md`: the full triage table for all
431 with a disposition and reason each, what was completed in which batch, the magic
rows registered, what was retired and why, and how many remain — plus your estimate of
the tester cost if OWNER later chooses to run the completed ones.
