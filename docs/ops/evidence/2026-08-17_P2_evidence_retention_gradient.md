# P2 — 34,228 verdicts have no retrievable evidence, and the pattern is an age gradient

## The question and the answer

P2 asked whether 20 portfolio verdicts lack evidence because it was never written or because it
was removed. **Removed** — and not just the file: for all 20 the entire
`D:\QM\reports\work_items\<uuid>\` tree is gone. Every `evidence_path` is set; every parent
directory is absent.

All 20 date from 2026-06-27 to 2026-07-06. That prompted the obvious follow-up: is this
happening to fresh evidence too?

## Measured fleet-wide, and it is an age gradient

Every `done` row since 2026-06-01 with a verdict and a set `evidence_path`, checked for file
existence — 50,629 rows:

| Month | Evidence present | Missing | Missing rate |
|---|---:|---:|---:|
| 2026-06 | 5 | **30,916** | **100.0 %** |
| 2026-07 | 12,523 | 3,312 | 20.9 % |
| **2026-08** | **3,873** | **0** | **0.0 %** |
| total | 16,401 | **34,228** | 67.6 % |

**Current evidence is safe.** Nothing from August is missing, so this is not an active process
eating fresh artifacts — which is the reassuring half and the reason this is not an emergency.

**The historical record is not safe.** June is essentially entirely gone (30,916 of 30,921) and
July is a fifth gone. Something removes work-item report roots after roughly four to six weeks.

## Why this matters more than the 20 rows

The company's hard rule is *evidence over claims*: a strategy or pipeline assertion needs a CSV,
report or log path. For any verdict older than about six weeks **that path currently resolves to
nothing.** 34,228 rows carry a verdict whose evidence cannot be produced.

This also explains, one layer up, a limit I hit earlier today: 99 of 103 `BARS_ZERO` rows were
unclassifiable because their tester logs were purged. The logs were the visible part — the whole
report root goes with them.

Practical consequences, in order of severity:

1. **Any retrospective census over pre-July evidence is bounded by availability, not by
   method.** Today's `corr_eff` U bucket (20 of 66 portfolio rejections) is exactly this. So is
   any future INFRA_FAIL reclassification that wants to read `tester_log_decisive_lines` from
   June rows — that field did not exist then and the logs are gone regardless.
2. **Verdicts cannot be re-derived, only re-run.** A pre-July verdict that comes into question
   has no cheap path to validation.
3. **The `evidence_content_sha256` in newer aggregates is worth more than it looks** — it is the
   only thing that will let a future reader distinguish a surviving artifact from a substituted
   one.

## What I did not establish

**The mechanism.** No PowerShell script in `tools/strategy_farm/` or `scripts/` deletes whole
`work_items/<uuid>` trees: `reports_log_purge.ps1` removes only `*.log` beneath them, and
`tester_cache_purge.ps1` is scoped to `T<n>\Tester`. So the removal is either a Python path, a
historical one-off, or something outside the repo. **I am not going to guess.** The age gradient
is measured; the cause is not, and naming a culprit without evidence would be exactly the failure
mode this document is about.

Two candidates worth checking, in this order: `_archive_work_item_report_root_for_requeue` (the
`.requeued_*` convention — but that *moves* a root, so the renamed path should still exist and
can be searched for), and any retention setting on `D:\QM\reports` outside the two known purges.

## What must happen

1. **Find the mechanism before deciding anything.** If it is a live retention rule, the question
   is what to exempt; if it was a one-off, the question is only whether to prevent a repeat.
2. **Exempt verdict evidence from whatever it turns out to be.** A raw tester log is regenerable
   in principle; an `aggregate.json` that a verdict cites is the verdict's only backing. These
   are not the same class of artifact and should not share a retention policy.
3. **Do not treat this as a reason to distrust August verdicts.** The gradient says the opposite:
   current evidence is complete.
4. **State the availability boundary in every retrospective census.** "68% of rows have no
   retrievable evidence" is a fact about the archive, not about the verdicts, and reports that
   silently omit it overstate their own coverage.

## Evidence

- 50,629 `done` rows since 2026-06-01 with a set `evidence_path`, checked for file existence
- the 20 portfolio cases: `evidence_path` set, file absent, parent directory absent
- `reports_log_purge.ps1` (only `*.log`), `tester_cache_purge.ps1` (only `T<n>\Tester`)
- related: `2026-08-17_bars_zero_is_oninit_rejection_misclassified_as_infra.md` (the 99
  unclassifiable rows), `2026-08-17_P1_book_test_recompute_and_my_reversal.md` (the U bucket)
