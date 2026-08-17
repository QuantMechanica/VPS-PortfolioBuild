# BUILD-0 — Verdict currency: nothing is recorded, provenance archaeology fails, and 36 of 36 delivery pairs need work

## Step 2 first, because it settles the shape of everything else

**No verdict in this farm records any world-state.** Measured over 722 recent rows (since 08-15)
and all 40 Q10 PASS rows, against every payload key that could carry it:

| Category | Recent rows | Q10 PASS pool |
|---|---|---|
| EA binary identity | `expected_{ex5,mq5,setfile}_sha256` 41 %, `dispatch_ex5_verified_at` 72 % | **nothing** |
| **framework state** | **nothing** | **nothing** |
| **harness state** | **nothing** | **nothing** |
| **cost-model state** | **nothing** | **nothing** |
| gate-rule state | `effective_min_trades` 74 % | `effective_min_trades` 45 % |
| data state | history audit SHAs 72 %, `host_symbol` 93 % | `host_symbol` 25 % |
| evidence integrity | nothing | `evidence_sha256` 55 % |

`commit_reservation_class/gb/until_utc` appear on 68 % of rows and look like a commit stamp. They
are **RAM commit reservation**, not git provenance — a false friend, recorded here so nobody else
mistakes it for one.

So the currency predicate cannot be evaluated from stored data at all. It has to be **added going
forward** and **approximated backwards** — and the backwards half is where this got interesting.

## Steps 3–4: three attempts at a provenance predicate, all of which fail

I tried to build the "list of behaviour-changing commits" three times. Each attempt is reported
because the failures are the finding.

**Attempt 1 — path classes.** Commits touching paths whose content can alter an outcome
(EA includes, setfile generator, tester defaults, phase runners, run_smoke, cost model, gate
logic, portfolio rules), excluding docs/artifacts/dashboards/tests/pump-commits.
Result: **69 of 78 days** carry at least one such commit. A date-based predicate would mark every
verdict older than a day as suspect — exactly the outcome the brief warns against: *a list that
captures everything devalues the whole inventory without producing knowledge.*

**Attempt 2 — compilation order against `framework/include/**`.** An include is compiled *into*
the EA, so `ex5_mtime < last_include_change` is a mechanical fact, not a guess about intent.
Result: **3,220 of 3,286 EAs "stale"** — no better. The reason is instructive: **the include tree
conflates two different semantics.** `QM_MagicResolver.mqh` accounts for **1,806 of ~1,946**
include changes, one per EA magic allocation, and allocating a magic for QM5_41046 cannot change
QM5_10403's behaviour.

**Attempt 3 — behaviour-bearing includes only** (excluding the magic registry). This gives a
usable **113 commits**, sensibly distributed (May 22 · June 16 · July 66 · August 9) and clearly
behaviour-bearing: `QM_Common.mqh` 33 changes, `QM_NewsFilter.mqh` 18, `QM_Indicators.mqh` 15,
`QM_KillSwitch.mqh` 10, `QM_Entry.mqh` 10, `QM_TradeManagement.mqh` 9, `QM_RiskSizer.mqh` 8.

But the partition is *still* 3,220 / 66, and now the reason is structural rather than fixable:

> **A "last change" cutoff is the wrong shape.** Any actively developed repo has a recent change,
> so a global cutoff always condemns nearly everything. And the per-dependency version fares no
> better, because the include almost every EA depends on — `QM_Common.mqh` — changes every few
> days.

## The conclusion, and it changes BUILD-0's method

**A provenance-based staleness predicate cannot be made informative on this codebase.** Any
*correct* provenance predicate marks nearly the whole inventory stale, which is the same as
marking none of it.

The workable predicate is therefore **effect-based, not provenance-based**:

> Re-run a verdict and compare. Not as archaeology per EA, but as a **sampled reproduction rate**:
> re-run a stratified sample of the pool, measure how often the verdict actually changes, and let
> that rate decide whether wholesale re-running is warranted.

This converts an unbounded archaeology task into a bounded measurement, and it answers the
question that actually matters — *does the old verdict still hold?* — instead of the proxy
question *could something have changed?*, whose answer is always yes.

The 113-commit list is still worth keeping, not as a staleness predicate but as the **explanation**
for whatever the reproduction rate turns out to be. And the named stichtage stay useful because
they are semantic rather than statistical: DL-079 (2026-06-28), the Q10 portfolio dependency
`b62cf0638` (2026-07-29), the set-file backfill (2026-07-26/27), the generator fix `3844c472a`
(today), and the two-sided PF gate once it lands.

## Step 5: the catch-up list — 36 of 36 pairs need work

Scope is the delivery chain only: the Q10 PASS pool **∪** the live roster. Unit is **pairs**.

- Q10 PASS pool: **34 pairs** (40 was the row count)
- live roster: 24 sleeves
- union audited: **36 pairs**

Three questions, three consequences:

| Classification | pairs | consequence |
|---|---:|---|
| `RERUN_EVIDENCE_GONE` | **18** | verdict exists, evidence cannot be produced → re-run |
| `RERUN_PRE_CONTRACT` | **13** | produced before the 07-29 contract → re-run |
| `RUN_MISSING_GATE` | **5** | a required gate never produced a verdict → run it |
| **CURRENT** | **0** | — |

**Not one of the 36 delivery-relevant pairs is current.**

### A correction to my own number from last round

I reported that two roster sleeves lack a Q04 verdict. That understated it:

```
QM5_12778 AUDUSD.DWX   pool + roster   missing Q04, Q05, Q06, Q07, Q08, Q09_PORTFOLIO
QM5_13117 EURGBP.DWX   pool + roster   missing Q04, Q05, Q06, Q07, Q08, Q09_PORTFOLIO
```

Both hold a **Q10 PASS with six intervening gates never graded** — not a missing Q04, an absent
Q04→Q09 chain. Three further single-gate gaps: QM5_10440/NDX (Q05, roster), QM5_10692/NDX (Q05,
pool), QM5_12567/XNGUSD (Q10, roster).

### Cost, computed before proposing it

| | |
|---|---:|
| individual gate runs needed | **214** |
| at the measured 10.7 completions/h | **20.0 hours** of exclusive factory time |
| against the 784-row queue (~73 h/pass) | **27 % of one pass** |

That is affordable, and it makes the priority question concrete rather than rhetorical: 20 hours
buys a delivery chain whose every link is current. Ordering is deepest-phase-first as required —
a Q10 candidate without a valid Q04 is the most expensive gap.

## What must be implemented, going forward

The forward half is small and unambiguous, because nothing exists today. Every dispatched run
should stamp, at minimum:

1. **`framework_include_tree_sha256`** — hash of the behaviour-bearing includes (excluding
   `QM_MagicResolver.mqh`, per the finding above). One value, comparable across runs.
2. **`harness_version`** — the phase runner + `run_smoke` identity actually invoked.
3. **`cost_model_sha256`** — the venue cost/swap snapshot in force. Needed by BUILD-3 anyway.
4. **`gate_rules_version`** — a single monotonic stamp bumped whenever a grading threshold or
   formula changes; the semantic stichtage above become its history.
5. **`evidence_content_sha256`** — on every row, not 55 % of them.

With those five, the currency question becomes a string comparison instead of an archaeology
project, and the next BUILD-0 costs minutes.

## Deliberately not done

- **No re-runs started.** The catch-up list is a costed proposal; 20 hours of exclusive factory
  time against a 73-hour queue is a priority decision, and the brief reserves it.
- **The ~36k evidence-less inventory rows are not re-run.** Marked *not usable for book decisions*,
  as scoped. Wholesale re-running would take months and buys nothing for the two books.
- **No roster change.** QM5_12778 and QM5_13117 stay where they are pending the OWNER decision
  already on the list.

## Evidence

- `artifacts/behaviour_changing_commits_20260817.json` — attempt 1, 69/78 days, with exclusions and reasons
- `artifacts/framework_currency_predicate_20260817.json` — attempt 2, the compilation-order partition
- `artifacts/build0_catchup_list_20260817.json` — the 36 pairs, per-phase state, 214 runs
- state inventory over 722 recent rows and all 40 Q10 PASS rows
- `QM_MagicResolver.mqh` 1,806 of ~1,946 include changes; behaviour-bearing remainder 113
