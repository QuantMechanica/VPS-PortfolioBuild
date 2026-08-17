# `summary_missing:unclassified` is a launch failure, not a purged journal — my retention argument had a wrong leg

## The correction

I raised log retention from 2h to 12h on two justifications:

1. **Forensic** — journals for runs that write them survive long enough to be read. **Correct, and
   verified working.**
2. **Stopping rule** — *"a failure classified later than ~2h has no journal, so it becomes
   `UNCLASSIFIED`, which is not a recognised deterministic class, so the sweep re-enqueues it and the
   pair loops."* **This leg is wrong.**

The journal was never purged for this class. It was never written.

## The evidence, with a control

**Control — are journals written mid-run, or only at completion?** Mid-run. Of the five currently
active claims, the two Q07 runs already hold journals (`QM5_12935` 2 logs / 51 files, `QM5_1116`
4 logs / 39 files). So an absent journal on a live run is not simply "not finished yet".

**The four failed rows of QM5_20178/XAUUSD**, the pair I identified as looping:

| Row | verdict | `*.log` | `summary.json` | `report.htm` | `tester.ini` |
|---|---|---:|---:|---:|---:|
| `da89eae6` | INFRA_FAIL | **0** | **0** | **0** | 3 |
| `73285c18` | INFRA_FAIL | **0** | **0** | **0** | 1 |
| `781778c1` | INFRA_FAIL | **0** | **0** | **0** | 3 |
| `ef08a876` | INFRA_FAIL | **0** | **0** | **0** | 3 |

And the fifth attempt, active for 78 minutes as I write: report root present, **5 files, 0 logs**.

So the tester was *configured* — `tester.ini` written, three times per row, i.e. three internal
attempts — and then produced **nothing at all**. No journal to purge, no summary to read, no report.

## What the class actually is

> A run that produces only `tester.ini` and then nothing is a **launch failure**. The classifier
> reports `summary_missing` because there is no summary, and `unclassified` because there is no
> journal either — but the journal's absence is the *same symptom*, not a retention artefact.

Roughly 4 rows × 3 internal attempts ≈ 12 launch attempts on this pair, none of which produced a
single measurement. That is consistent with the 49 dispatches I measured across the class.

## The better fix, which is cheaper than the one I argued for

The absence I was trying to cure with retention is itself a **sufficient signature**:

> `tester.ini` present, and no summary, no report and no journal, after the run has had its full
> timeout — that is deterministically detectable **without any log at all.**

So the per-pair stopping rule does not need retention as a precondition. It needs the launch-failure
signature, which is already fully present in the file tree. That is strictly cheaper and it does not
depend on how long journals live.

It also reframes the remedy: this is not a classification problem to be solved by keeping more
evidence, it is a **launch problem**. Twelve launch attempts producing nothing means something stops
the tester before it writes its first line, and that cause is unexamined. `ACTIVE_TIMEOUT` appears in
this pair's history too (`73285c18`), which fits a tester that starts and hangs rather than one that
refuses.

## Does the retention raise still stand?

Yes, on one leg instead of two, and I am not reverting it:

- It is **verified working** — `PURGED 0 .log older than 12h` and `BUDGET_OK tree 0.04GB <= 8GB`,
  with four controls including a firing positive control on the size trim.
- It costs **~0.27 GB** at the measured 0.022 GB/h across all three roots.
- It genuinely helps the classes that *do* write journals — the Q07 multiseed rows above hold 2–4 logs
  each, and under the 2h rule those were being deleted while their pair was still being decided.
- The size budget is independently worth having, because retention alone cannot bound a size
  regression.

What I withdraw is the claim that it unblocks a stopping rule for `unclassified`. It does not, and
saying so was reasoning from a plausible mechanism instead of checking the file tree.

## The pattern, now four for four today

Every wrong number of mine today came from testing something adjacent to the real predicate:

| | I tested | The predicate actually was |
|---|---|---|
| `ea_metrics` | `rows[-3:]` by `extracted_at` | query by `work_item_id` |
| 214 catch-up actions | verdict date vs a contract date | which *phase* the contract touched |
| 5 re-derivations | the Q09_PORTFOLIO arm | **both** arms, incl. `CONFIG_LOCKED` news |
| this | "journal is missing → it was purged" | **the file tree**: it was never written |

The first three were caught by reading the code. This one needed looking at the directory. Same
lesson in a different place: the artefact is authoritative over the story about the artefact.

## Evidence

- five active claims with per-row `*.log` counts as the mid-run control
- QM5_20178/XAUUSD: four terminal rows and one active, file inventory per row
- `2026-08-17_log_retention_is_crisis_era_tuning_that_outlived_the_crisis.md` — the raise itself,
  which stands
- `artifacts/unclassified_retry_loop_20260817.json` — the 49-dispatch measurement, unchanged; only
  its stated *cause* is corrected here
