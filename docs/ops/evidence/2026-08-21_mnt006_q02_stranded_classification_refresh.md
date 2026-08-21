# MNT-006: refreshed classification packet for the 275 stranded Q02 pairs

Date: 2026-08-21. Author: Claude (orchestrator, headless cycle). Branch: agents/board-advisor.

## Scope of this pass

MNT-006 asks to classify the 275 `q02_stranded_exhausted_pairs` by cause class and give
each a disposition, with sized canaries per class rather than a bulk release. The ticket
is explicitly sequenced behind **MNT-038** ("canary-before-fanout stop rules"). MNT-038
(task `8d0726d7`, agent codex, priority 86) is **still IN_PROGRESS** at time of writing
(dispatched 09:28 UTC today) — not landed. Per MNT-006's own sequencing and the standing
authorization (bulk infra requeue is OWNER-gated, sized canaries only), **no requeue was
executed in this pass.** The scoped, defensible deliverable is: refresh the classification
using the existing tool and confirm every one of the 275 carries a cause class.

## Classification already exists as a tool — reused, not reinvented

`tools/strategy_farm/classify_q02_stranded_pairs_report.py` implements the exact same
cohort predicate as `health.chk_q02_stranded_exhausted_pairs` (byte-identical `COHORT_SQL`),
is read-only/mode=ro, and already produces a per-pair classification plus a governed,
sequential, per-cause canary proposal. Re-ran it fresh against today's DB snapshot:

```
python tools/strategy_farm/classify_q02_stranded_pairs_report.py \
  --output-dir docs/ops/evidence --stem 2026-08-21_q02_stranded_pairs_classification
```

Output: `docs/ops/evidence/2026-08-21_q02_stranded_pairs_classification.{json,csv}`
(sha256 recorded inside the JSON header).

## Result: all 275 pairs carry a classification

| classification | pairs |
|---|---:|
| INVALID_EVIDENCE_DEFECT | 244 |
| UNCLEAR | 31 |
| VALID_ZERO_TRADES | 0 |

Cause breakdown (INVALID_EVIDENCE_DEFECT, 244 pairs):

| primary_cause | pairs |
|---|---:|
| ONINIT_FAILED | 102 |
| ACTIVE_TIMEOUT | 49 |
| SUMMARY_MISSING_NO_ROW_BOUND_AGGREGATE (folds into UNCLEAR, 31) | — |
| NO_HISTORY_TRANSIENT | 25 |
| BARS_ZERO | 25 |
| LOG_BOMB | 15 |
| SETFILE_MISSING | 15 |
| TIMEOUT_METATESTER_HUNG | 8 |
| SETFILE_HEADER_INCOMPLETE | 3 |
| REPORT_MISSING | 2 |

`no_candidate_categories` (from the tool's own output) names the pairs that are
deliberately withheld from any canary: `SETFILE_MISSING` (15, repair setfile first),
`SETFILE_HEADER_INCOMPLETE` (3, repair headers first), `UNCLEAR` (31, needs forensic log
recovery first, no blind requeue), `CALENDAR_HARD`/`SETFILE_DUPLICATE`/
`ROW_BOUND_PASS_DISPOSITION_MISMATCH` (0 each, none present this run).

## Diff vs the 2026-07-31 baseline

Baseline (`2026-07-31_q02_stranded_pairs_classification.md`): 279 pairs — VALID_ZERO_TRADES
2, INVALID_EVIDENCE_DEFECT 244, UNCLEAR 33. Today: 275 pairs — VALID_ZERO_TRADES 0,
INVALID_EVIDENCE_DEFECT 244, UNCLEAR 31. Net: cohort shrank by 4 (some pairs presumably
picked up a non-infra terminal disposition or successor since), the INVALID count is
unchanged, and the 2 former VALID_ZERO_TRADES pairs are no longer in the stranded cohort
at all (they must have exited via a non-infra route already — consistent with the health
check's "no non-infra terminal disposition" gate excluding them once dispositioned).

## Canary proposal: staged, NOT executed

The tool emits a `governed_canary_proposal` with `status:
PROPOSAL_ONLY_NOT_AUTHORIZED_NOT_EXECUTED` — 10 candidate rows across the 5 largest
actionable causes (ONINIT_FAILED, ACTIVE_TIMEOUT, NO_HISTORY_TRANSIENT, BARS_ZERO,
LOG_BOMB — 88.5% of the 244 defect pairs), 2 rows per cause, strictly sequential
(`GOVERNED_SINGLE_ROW_REQUEUE_AFTER_REVIEW`, row 2 unqueued until row 1 has a reviewed
terminal disposition), each with named global preconditions (news calendar freshness,
RISK_FIXED/RISK_PERCENT setfile mode, hash-identity checks) and abort rules. This
satisfies MNT-006's "sized canaries per class, never a bulk release" as a *proposal*.

**Execution is explicitly blocked** on two gates, neither cleared in this pass:
1. MNT-038's canary-before-fanout stop rules landing (prevents a deterministic defect
   from re-burning a whole symbol cohort if requeued).
2. OWNER authorization for the bounded sequential canary (a named global precondition
   in the proposal itself).

No work_items were enqueued, no verdicts were touched, no requeue happened.

## Acceptance criterion check

"Every one of the 275 carries a cause class and a disposition" — yes, all 275 rows are
classified with a `primary_cause`/`classification`, and each class has a stated
disposition (canary-eligible-once-authorized, repair-evidence-first, or
forensic-recovery-first). "The health count drops for reasons that are individually
defensible, not by relaxing the check" — the count has not yet dropped in this pass
(correctly: canary execution is gated behind MNT-038 + OWNER, per the ticket's own
sequencing), but the disposition-per-pair half of the acceptance criterion is met.

## Verification

```
python tools/strategy_farm/classify_q02_stranded_pairs_report.py --output-dir docs/ops/evidence --stem 2026-08-21_q02_stranded_pairs_classification
python tools/strategy_farm/farmctl.py health   # q02_stranded_exhausted_pairs still FAIL 275 (unchanged, as expected -- no execution this pass)
```
