# The per-pair stopping rule already exists, sealed 184 pairs today, and I said it didn't

## The correction

Last round I wrote, about QM5_20178/XAUUSD Q02:

> "it is still running: the fifth attempt is at 86 of its 120 minutes as I write, and a sixth will
> follow, **because nothing recognises 'this pair has timed out four times'**"

and I carried "per-pair stopping rule" as an open item into the delivery plan (Gesamtauftrag 1.4),
recommending it as the remedy that "should not wait".

**It already exists.** It is `poison_pill_quarantine`, and it sealed **184 (ea, symbol, phase)
pairs today at 10:59:52 UTC** while I was writing that nothing would.

## What it actually is

| Property | Value |
|---|---|
| table | `poison_pill_quarantine` — `ea_id, symbol, phase, active, verdict_reason, consecutive_failures, successes_ever, evidence_path, quarantined_at, released_at, release_note` |
| threshold | **exactly 5** — active seals show `consecutive_failures` min **5**, max 12, and **0 of 184** had any prior success |
| disposition reason | `five_identical_infra_failures_no_merit_verdict` |
| refresh | `poison_pill_quarantine.refresh_pending(conn)` inside **`dispatch_work_items`** (`farmctl.py:9866-9867`) — every dispatch cycle with free terminals and an open calendar gate, i.e. **continuous, not batch** |
| enforcement | `pending_claim_order_sql()` excludes quarantined pairs (`farmctl.py:1174`) — it stops dispatch, it does not merely label |
| release | a **named operator**: `python tools/strategy_farm/poison_pill_quarantine.py release --ea-id … --symbol … --phase …` |
| audit trail | per-row `recovery_pre_image_sha256`, `recovery_batch`, `recovery_class`, `recovery_tagged_at_utc` |

So this is the *good* version of the pattern I have been complaining about all week: a fail-closed
label **with** a named operator, a release path, a pre-image hash, and enforcement in the claim
order. 183 of the 184 active seals carry `summary_missing_retries_exhausted` — the same
absent-evidence family I have been chasing.

## Why I got it wrong

I inferred the absence of a mechanism from the **observation of repeats**: four failed rows plus a
fifth running looked like nothing was counting. But the threshold is five, and the pair had not
reached it. The repeats I saw were the mechanism's *runway*, not its absence.

The check I skipped was cheap and I have used it before: **look for the table before concluding
there is no mechanism.** I read `pending_claim_order_sql` earlier this week and recorded that it
"excludes active `work_item_holds` and `poison_pill_quarantine`" — I had the answer in my own notes
and still argued from the symptom.

## The pre-registered test, this time genuinely pre-registered

`artifacts/prereg_poison_pill_seal_20260817.json`, written at **17:33:09Z** with the deciding row
verified `status=active, verdict=None` and quarantine rows **0**:

> When work item `1cf5109f` terminates as `INFRA_FAIL`, the next dispatch cycle writes a
> quarantine row for (QM5_20178, XAUUSD.DWX, Q02) with `consecutive_failures=5`,
> `successes_ever=0`, and no sixth Q02 row for that pair is ever claimed.

Falsifiers are named in the file, including the one that would show my correction wrong in the
other direction (row terminates, no seal appears → the refresh is not continuous).

This is recorded pointedly because **the same artifact type failed its own standard earlier today**:
`artifacts/prereg_registry_coverage_20260817.json` was written at 17:15:32 against outcomes that had
landed at 17:07:00 and 17:13:09. That file stays in the tree with its timing admission rather than
being quietly deleted.

## What the cost was, measured properly

Row lifetimes for the pair, created on the recurring `:52` cadence:

| work item | created → updated | lifetime | attempts |
|---|---|---:|---:|
| `da89eae6` | 08-16 11:52 → 20:40 | **527 min** | 2 |
| `73285c18` | 08-16 20:52 → 22:24 | 92 min | 0 |
| `781778c1` | 08-16 22:52 → 08-17 06:39 | **467 min** | 2 |
| `ef08a876` | 08-17 06:52 → 14:24 | **451 min** | 2 |
| `1cf5109f` | 08-17 14:52 → active | 147 min+ | 1 |

**1,684 minutes ≈ 28.1 hours on a single (EA, symbol, phase) pair** — well above the ~24 slot-hours
I estimated last round, and note that row lifetime is *not* run duration: a row can hold 8 hours
across internal retries, which is why the 7200 s per-run ceiling never bounded it.

## What remains genuinely open

The seal stops the bleeding. It does **not** explain the cause, and a sealed pair is a **withheld
(EA, symbol)**, not a resolved one — 184 of them, all with `successes_ever = 0`. Two questions
survive:

1. **Why** this EA needs ~19× the median XAUUSD Q02 runtime while passing on five other symbols.
   Measured last round: XAUUSD median 6.4 min, p90 17.2 min, **0 of 471 successful runs exceeded
   7200 s**. So the ceiling is not mis-set; this pair is the outlier.
2. Whether 5 is the right threshold. At ~7 h per failed row for this pair, five failures is
   ~28 h of exclusive slot time before the seal engages. The threshold is correct in *kind*;
   whether it should be cost-weighted rather than count-weighted is a separate, answerable question
   — a repetition limit expressed in attempts spends far more on a slow pair than a fast one.

## Consequence for the delivery plan

Gesamtauftrag **1.4's first half is closed by inventory, not by build** — the same outcome as
Phase 0's Z3 and for the same reason. What is left of 1.4 is the cause question above, plus the
threshold-shape question, and neither blocks anything downstream.

## Evidence

- `poison_pill_quarantine` — 184 active rows, all `quarantined_at 2026-08-17T10:59:52+00:00`
- `tools/strategy_farm/poison_pill_quarantine.py` — table DDL and the `release` operator
- `farmctl.py:9866-9867` (refresh inside `dispatch_work_items`), `:1174` (claim-order exclusion),
  `:1417` (DDL), `:1081` (`poison_pill_priority_override`)
- one full disposed payload: `poison_pill_disposition.reason =
  five_identical_infra_failures_no_merit_verdict`, `final_failure = summary_missing_retries_exhausted`,
  `verdict_reason = poison_pill:summary_missing_retries_exhausted`, `verdict_taxonomy = invalid`
- 181 June-created Q02 rows closed today, 111 distinct EAs, 13 symbols, 180 of 181 never attempted
- corrects `2026-08-17_the_real_class_is_an_xauusd_q02_timeout_third_revision.md` (its "option 1 is
  the whole remedy" recommendation — the remedy was already implemented)
