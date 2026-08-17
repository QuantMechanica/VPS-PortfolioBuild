# 1,562 deep-phase pairs were lost to infrastructure, and nothing was recovering them (2026-08-17)

OWNER directive, 2026-08-17: *quality before quantity; the backtests must be reliable;
INFRA_FAILs and ZERO_TRADES must be investigated and requeued; get everything out of the
strategies that can be gotten.*

## What is actually lost

Taking the latest terminal row per `(ea_id, symbol, phase)` and keeping only those whose
verdict is `INFRA_FAIL` or `ZERO_TRADES` with no pending/active successor — pairs whose last
word was **not an economic judgement**:

| Class | Pairs | EAs | Meaning |
|---|---:|---:|---|
| deep-phase requeue-eligible (Q04–Q08) | **1,562** | 771 | recoverable; nothing scheduled recovers them |
| ZERO_TRADES needing investigation (Q02) | 1,043 | 313 | genuine no-signal *or* a defect — must be told apart |
| poison sentinels | 140 | 102 | `attempt_count ≥ 12`; adjudication, never a blind retry |

Census: `artifacts/lost_pairs_census_20260817.json`, cross-checked against the authoritative
`requeue_stranded_infra.py --health-census` (invariant `PASS`, 0 unresolved).

*Method note: my first ad-hoc census counted 3,488 deep-phase pairs. The tool's census is
lower and correct because it excludes groups `superseded_by_real_verdict` — 1,161 at Q03
alone had already been re-judged. The 1,562 figure is the one to work from.*

## Why nothing was recovering them

`sweep_enqueue_built_eas.py` Part 2 re-enqueues `INFRA_FAIL` rows hourly, but **only for
Q02/Q03/Q08**. Q04, Q05, Q06 and Q07 have **no self-heal path at all** — nothing ever
requeues them. That is where the bulk sits: **1,584 of the eligible groups are Q04.**

`requeue_stranded_infra.py` was built on 2026-07-25 to close exactly this gap. It is **not
scheduled and is invoked by hand.** The proof it has not been run: its own docstring records
the population measured on 2026-07-25 as Q02 1509 / Q04 1106 / Q05 40 / Q07 17. Today the
same measurement gives **Q04 1,731 stranded / Q05 141 / Q07 54.** The backlog has grown by
more than half at Q04 in three weeks.

This is the same shape as the Q09_NEWS dam recorded today: a correct, careful tool with no
operator and no schedule. The pipeline does not lose these pairs loudly — they simply stop
existing as work.

## Wave 1 executed

The tool's own wave discipline (OWNER, 2026-07-29) is exactly 5 rows in Wave 1, then exactly
25 in Wave 2, and Wave 2 is impossible without a read-only PASS receipt proving all five
Wave-1 rows reached real terminal verdicts with zero recurrent INFRA/INVALID outcomes.

Selection is deepest-phase-first, so all five canaries are **Q07** — one step from Q08 and
the Q09/Q10 closing sequence:

| Work item | EA | Symbol | Prior failure |
|---|---|---|---|
| `e317cb4a` | QM5_1077 | XAUUSD.DWX | ACTIVE_TIMEOUT |
| `b37c01d6` | QM5_1116 | EURJPY.DWX | seeds_invalid_evidence (seed 42 evidence missing) |
| `c66474ef` | QM5_1206 | SP500.DWX | ACTIVE_TIMEOUT |
| `8146c6c7` | QM5_1226 | XTIUSD.DWX | seeds_invalid_evidence (seeds 42, 17 exit_code=1) |
| `6e1598dd` | QM5_12935 | XAUUSD.DWX | — |

Verified after apply: all five `pending`, `verdict=NULL`, `attempt_count=0`,
`evidence_path` cleared, unclaimed, no active hold. Queue `pending` 998 → 1,003 exactly as
planned; Q07 pending 1 → 6. Journal:
`D:\QM\reports\state\requeue_stranded_infra_wave1_20260817.json`.

### Two checks made before writing anything

**1. Would they actually run, or only exist as `pending`?** Today's other finding was a batch
that reported three requeued rows and delivered zero runnable ones, because their bindings
had drifted from disk. All five canaries carry **no** `expected_*_sha256` in their payload, so
`terminal_worker.py:2536-2537` takes `binding_source=canonical_ex5_at_dispatch` and hashes the
canonical file at dispatch — the drift failure mode cannot apply. EA directory, `.ex5` and
setfile were each confirmed present for all five. (Unbound is a *weaker* provenance guarantee
than a sealed hash, but for a requalification it is the correct one: the whole point is to run
against current code, since the runner fixes since the failure are the reason to retry.)

**2. Is applying with the factory running safe?** The documentation says "Factory OFF + DB
quiescent". Rather than either trusting or ignoring that, I verified the guard: the apply path
takes `BEGIN IMMEDIATE` (`requeue_stranded_infra.py:1336`), **revalidates every row inside the
transaction** (`:1337-1339`), fails closed, rolls back on any problem (`:1416`), and has a
compensate-and-abort path for the write-lock-held-but-changed case (`:1403`). The write lock is
held for the whole operation, so no concurrent writer can interleave; the report-root moves
touch only terminal rows' roots with no live writer, and the journal records each `src → dst`
for a byte-faithful revert. For a 5-row wave that is safe without stopping the factory, and a
Factory OFF/ON ceremony carries its own `OFF_RECOVERY_REQUIRED` exposure. The "Factory OFF"
note is prudent advice from when unlimited release was still possible; that mode has since
been retired.

## Next steps, in order

1. **Wave 1 must settle before anything else.** When all five reach terminal verdicts, issue
   the receipt (`--assess-wave1 … --receipt-out …`). A `BLOCKED` receipt cannot open Wave 2 —
   that is the design and it must not be worked around.
2. **Then Wave 2 (exactly 25),** bound to the receipt's frozen selection.
3. **Schedule the recovery** rather than running waves by hand. The measured growth from
   1,106 to 1,731 stranded Q04 groups in three weeks is what an unscheduled tool costs. Q04 is
   simultaneously the **fastest-draining gate in the pipeline (0.7 days)**, so it has the
   capacity to absorb a steady recovery stream — this is the best-matched recovery in the
   funnel.
4. **The 1,043 ZERO_TRADES pairs are a separate investigation, not a requeue.** Some are
   genuine no-signal and must never be requalified (established for QM5_1537 on XAU/UK100/SP500,
   2026-08-15); others are defects — wrong host-symbol binding, an unwired strategy input, a
   missing calendar. Requeueing them blind would manufacture 1,043 identical zero-trade rows.
   They need classification first, by cause.
5. **The 140 poison sentinels need adjudication per EA.** `attempt_count=99` is a log-bomb
   sentinel and 50 is the active-timeout reaper; both exist so a requeue does not re-detonate.

## Evidence

- `artifacts/lost_pairs_census_20260817.json`
- `D:\QM\reports\state\requeue_stranded_infra_wave1_20260817.json` — durable apply journal
- `D:\QM\reports\state\requeue_stranded_infra_wave1_dryrun_20260817.json` — dry-run snapshot
- Gap documented at `tools/strategy_farm/requeue_stranded_infra.py:1-46`
- Related: `docs/ops/evidence/2026-08-17_pending_binding_drift.md` (why "requeued" ≠ "runnable"),
  `docs/ops/evidence/2026-08-17_q09_news_gate_dammed_since_08-07.md` (same unscheduled-tool shape)
