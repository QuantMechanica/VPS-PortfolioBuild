# Prospective confirmation: fix the notation, the EA passes (2026-08-17)

## The test nobody had to design

The setfile exponent-notation root cause was established retrospectively at 09:5x — four
failures, four clean siblings, no counterexample. Between 10:04 and 10:13 the affected
setfiles were regenerated with decimal expansion. What happened next is the prospective test:

| EA | Before | Setfile fixed | After | Verdict |
|---|---|---|---|---|
| QM5_41042 | INFRA_FAIL 09:55 (3/3 attempts, BARS_ZERO) | 10:04:13 | claimed 10:08 | **PASS 10:12:52** |
| QM5_41038 | INFRA_FAIL 09:35 (3/3 attempts, BARS_ZERO) | 10:13:12 | claimed 10:05 | **PASS 10:16:37** |

**Two EAs that failed deterministically on every attempt now pass, with no change to strategy
logic, symbol, window or budget — only the serialisation of one tolerance value.** That closes
the causal chain: exponent notation in the setfile → MT5 mis-parses → the EA's own guard
rejects its configuration → `INIT_PARAMETERS_INCORRECT` → zero-bar report → `BARS_ZERO` →
`INFRA_FAIL`.

## The two that still failed are pre-fix runs, not new failures

| EA | Failed at | Claimed at | Setfile fixed at | Fresh row |
|---|---|---|---|---|
| QM5_41032 | 10:14:50 | 10:07:14 | (guard fixed in tree) | `845f4c93` at 10:21:12 |
| QM5_41041 | 10:16:35 | 10:08:02 | 10:13:12 | `8242085a` at 10:21:12 |

Both were claimed **before** their fix landed, so they staged the defective artifacts and were
always going to fail. Fresh rows were minted at 10:21 and will run against corrected artifacts.
Neither is evidence against the fix.

## The generalisation landed, not just the patch

`QM5_41032`'s stale identity guard — `if(qm_ea_id != 41029 || …)` cloned from QM5_41029 — is
gone. Both sites (`:442`, `:599`) now read:

```mql5
if(!QM_InputRequireLong("qm_ea_id", qm_ea_id, 41032) || …)
```

and `framework/include/QM/QM_Common.mqh:41` gained the helper family:

```mql5
bool QM_InputRequireLong(const string predicate, const long observed, const long required)
  {
   if(observed == required) return true;
   PrintFormat("QM_INPUT_REJECT predicate=%s observed=%I64d required=%I64d",
               predicate, observed, required);
   return false;
  }
bool QM_InputRequireDouble(const string predicate, const double observed,
                           const double required, const double tolerance)
```

That is the framework-level fix requested rather than a per-EA patch, and the `Double` variant
with an explicit tolerance parameter targets exactly the comparison class that caused this
incident. A rejected input now names itself in the tester log instead of failing silently —
which is what turned a one-character defect into a multi-hour investigation.

**Still uncommitted** (working tree: `QM_Common.mqh`, `QM5_41032` source and binary), task
`1a44e6a0` `IN_PROGRESS`. Review when it lands.

## A separate prospective confirmation, on the strategy side

`af79d508` — the pre-registered guarded canary for `QM5_20177`/USDJPY, created 02:07 — landed at
10:13:08 with **`ZERO_TRADES`**.

That confirms a *strategy* diagnosis empirically. On 2026-08-17 03:22 I reclassified six
QM5_20177 rows to `DRAFT_DEFECT` after reading a structural contradiction in its card
(early-target-at-fill: the target is reachable at the fill price, so the position closes before
it can develop). The canary predates that reclassification and was left to run deliberately.
Producing no trades at all is precisely what that contradiction predicts.

**This row must not enter the ZERO_TRADES requalification set.** It is not "class A genuine
no-signal" — a genuine no-signal EA is mechanically sound and simply found no setup. This one is
a draft defect whose card cannot produce a trade. Requalifying it would manufacture an identical
zero-trade row forever. When the 1,043 `ZERO_TRADES` pairs are classified, this is a distinct
class:

> **ZERO_TRADES downstream of a known card/draft defect** → seal, never requalify. Distinguish
> it from genuine no-signal by whether a *mechanical* reason for zero trades has already been
> established in the card review.

## Evidence

- `artifacts/exponent_notation_setfile_scan_20260817.json`,
  `artifacts/poison_pill_eligible_census_20260817.json`
- `framework/include/QM/QM_Common.mqh:41` (helper family),
  `framework/EAs/QM5_41032_wti-flow-div/QM5_41032_wti-flow-div.mq5:442,599`
- Related: `2026-08-17_setfile_exponent_notation_kills_runs_deterministically.md`,
  `2026-08-17_bars_zero_is_oninit_rejection_misclassified_as_infra.md`
