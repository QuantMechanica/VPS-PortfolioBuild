# Gate-funnel autopsy — what kills EAs at each gate, and what to do about it

Method: nine independent analysts, one per gate, Q10 back to Q02; one synthesis; three adversarial
verifiers instructed to refute. 13 agents, 0 errors, 1.24 M tokens, ~25 min wall clock. Read-only,
factory OFF. Run `wf_9ccef311-1cc`; per-agent returns in the workflow journal.

All three verifications returned **SURVIVES**, each with a specific correction folded in below.

## The finding that changes Sunday

**53.6 % of the book's risk sits on sleeves whose Q07 multi-seed gate never varied the seed.**

`q07_multiseed.py` runs the Q06-stressed setfile five times under seeds [42, 17, 99, 7, 2026] and
passes when the PF range across seeds is < 20 % and every seed clears PF 1.0. Of **157** Q07-PASS
(EA, symbol) pairs, **75 recorded `variance_pct=0.00`** — the five runs produced byte-identical
results. Twelve of those 75 are in the Sunday manifest:

| EA | symbol | risk |
|---|---|---:|
| QM5_12567 | XNGUSD | 0.9797 |
| QM5_10919 | XTIUSD | 0.9181 |
| QM5_12567 | XAUUSD | 0.7465 |
| QM5_1556 | XAUUSD | 0.6017 |
| QM5_11165 | AUDCAD | 0.5230 |
| QM5_11421 | AUDUSD | 0.3614 |
| QM5_10513 | XAUUSD | 0.3050 |
| QM5_12989 | XAUUSD | 0.2420 |
| QM5_10939 | GBPUSD | 0.1887 |
| QM5_1567 | EURUSD | 0.1791 |
| QM5_10911 | GDAXI | 0.1276 |
| QM5_10440 | NDX | 0.0577 |
| **sum** | | **5.2305 / 9.75 = 53.6 %** |

Zero variance across five seeds has exactly two explanations: the seed never reached the EA, or the
EA is genuinely deterministic. The gate cannot tell them apart and stamps PASS either way — so for
these twelve, Q07 certified nothing. The Q07 auditor attributes the first cause to an injector
defect that wrote no `qm_rng_seed` when `magic_slot_offset != 0`, repaired in tree at `1224d518b`
(2026-07-14, which does touch `q07_multiseed.py`). That attribution is plausible and unverified
here; the *measurement* — 75 of 157 pairs, 12 in the book, 53.6 % of risk — is direct from
`work_items.payload_json.verdict_reason` and stands on its own.

This is an evidence-integrity finding, not a claim that the sleeves are bad. Re-running Q07 on the
repaired injector is expected to re-confirm most of them and to flip some genuinely seed-fragile
ones to FAIL. That is the point: right now we do not know which.

**Correction to a related gate:** the gate should grade `variance_pct == 0.00` with identical trade
counts as INVALID, not PASS, so the class fails loud. That is a criteria change and needs OWNER.

> **CORRECTION 2026-07-25, after the audit was written.** The synthesis called the Q10 ingester
> "the single highest-leverage fix — 20 EA-symbol pairs unblocked for live" and ranked it above a
> mass Q02 requeue on that basis. That ranking is wrong. **All 20 orphaned pairs are already in the
> DXZ Sunday book** (measured: intersection of the 20 against
> `portfolio_manifest_sunday_final_24sleeve_DRAFT_20260719.json` = 20 of 20, 0 outside). They are
> the sleeves revalidated overnight, which are already trading. The ingester yields **zero new live
> sleeves.**
>
> `ftmo_qualification.py` is not the DXZ admission path. Its own module docstring: *"The DXZ
> portfolio-rescue route intentionally accepts selected Q08 soft fails. That state is useful for
> portfolio research but is not sufficient evidence for a paid prop challenge. This tool keeps the
> two contracts separate."* So the block was on the **FTMO challenge track only**.
>
> What the ingester is still worth: it makes the DB describe reality (dashboards, cockpit and
> morning_brief currently under-report the book's gate status), it makes those 20 eligible for the
> FTMO challenge track — a named company objective — and it closes the KS-baseline-vs-qualification
> split below. That is real value, but it is not a density lever, and the synthesis's arithmetic
> comparing it against a Q02 requeue compared two different things.

## Second finding: 20 Q10 passes exist on disk and in no database

`q10_confirmation.py` writes `aggregate.json` plus a Q13 KS baseline, and writes nothing to sqlite.
Only a queued `terminal_worker` dispatch creates the `work_items` row. The overnight revalidation ran
the runner out-of-band with the factory OFF, so its results never landed in the DB.

Verifier reproduced the count independently, by a different path: **27 distinct Q10-PASS (EA, symbol)
pairs on disk, 7 in `work_items` → 20 orphaned.** It then attacked the population on four
contamination modes and refuted all four — every EA `status=active` in the registry, every symbol a
routable `.DWX`, every aggregate backed by a completed full-history run with a real `report.htm`, no
duplicate inflation.

`ftmo_qualification.py` hard-requires a Q10 PASS work_item (`STRICT_PHASES`), so these 20 currently
fail admission as `q10_pass_missing`.

Framing corrected by the verifier and adopted here: these are **20 pairs newly eligible for live
admission**, not 20 guaranteed live sleeves. Q11–Q13 remain OWNER/manual gates and several of the 20
share a `strategy_id`, so portfolio correlation will cull some.

The same architectural defect produces a second symptom: **0 % of Q04 `aggregate.json` survive on
disk** — the runner writes into a volatile work-item directory that is later purged, so ~8 000 Q04
verdicts cannot be re-audited. One persistence fix serves Q04 and Q10 together.

## Third finding, live-safety: the KS kill-switch fails open

`QM_KillSwitchKS.mqh` on a failed baseline load:

```
g_qm_ks_baseline_loaded = false;
// Not a fatal init failure — baselines only exist for Q13 burn-in EAs.
QM_LogEvent(QM_INFO, "KS_BASELINE_ABSENT", ... "action":"ks_killswitch_dormant" ...);
```

A live EA whose baseline is missing or mismatched trades on with the KS distribution kill-switch
**silently disabled**, logged at INFO. There are 27 baselines on disk against 7 Q10 PASS rows in the
DB — the kill-switch layer and the admission layer read two different sources for one fact.

Not a throughput item. Flagged for OWNER as a live-safety decision: should a missing baseline be
fatal at OnInit for an EA running in `ENV=live`?

## Correction to my own earlier framing

I told OWNER that Q08 is "the wall — 9 PASS out of 502". **That was wrong.** The Q08 auditor
established that `FAIL_SOFT` is the working portfolio-track admission tier, not a rejection: all 73
distinct FAIL_SOFT sleeves have Q09/Q10 rows downstream. The real Q08 problem is narrower and
different — the 8.5 neighborhood and 8.7 PBO sub-gates return INVALID for fixed-param card EAs
because they need a ≥2-config optimisation grid that Q03 never publishes, and INVALID is treated as
blocking. That blocks ~17 sleeves.

## What actually rejects, per gate

| gate | rows | dominant real cause |
|---|---:|---|
| Q02 | 72 709 | 68 % infrastructure. `summary_missing_retries_exhausted` alone is 43 737 rows (88 % of the infra mass) and is stored under `payload.final_failure`, with `verdict_reason` NULL — invisible to any survey reading `verdict_reason`. Strategy rejection is a pure frequency screen: `MIN_TRADES_NOT_MET` ~3 900, `pf_below_q02_floor` **0**. |
| Q03 | 12 607 | Adds no orthogonal selection. `q03_plateau_runner.py` is fully built, tested, preregistered — and **wired into nothing**. Production Q03 is a bare `run_smoke` re-applying the Q02 trade floor; 104 of 106 Q03 rejects had already cleared Q02 on that same criterion. |
| Q04 | 15 163 | The genuine killer, and largely correct: 70.8 % of pairs are real OOS decay. But 981 pairs never got a verdict at all (`incomplete_fold` 577, `EMPTY_EXPERT`/`M0_1970` ~289), and rows inflate 2.75× from duplicate dispatch (one EA-symbol spawned 386 rows). |
| Q05 | 839 | Near coin-flip. 31 stuck index-symbol infra pairs; 10 parked in `FAIL_DD_PORTFOLIO_REVIEW`, a lane nothing consumes. |
| Q06 | 362 | Thresholds are byte-identical to Q05 (imported). Q05 injects reject_prob 0.00, Q06 injects 0.10 — so Q06 is the same backtest with a 10 % trade rejection. The documented cost stress (slippage +5, spread ×3, commission ×3) was never implemented; the runner docstring admits it. |
| Q07 | 310 | See the headline: 75 of 157 PASS pairs have zero seed divergence. |
| Q08 | 502 | Not a pass-rate wall. ~17 sleeves blocked by 8.5/8.7 INVALID for want of an optimisation grid Q03 never emits. `DL077_MIN_QUALITY_PASSES` is hardcoded 1 while DL-077 (status **PROPOSED**) proposes 4. |
| Q09 | 102 | DL-083's ratified 0.15/0.40/0.020 live only in `marginal_contribution_eval.py`, which has **zero callers**. The production path runs `DEFAULT_MAX_CORR=0.30` and `SHARPE_DEGRADE_EPS=1e-3` — the latter is ~1/60 of the bootstrap SE, so it rejects DD-improving diversifiers on noise. |
| Q10 | 9 in DB | Ran almost never because it is 1:1 downstream of Q08 PASS. 23 of 24 real runs are unrecorded. |

## Programme

### Track A — infrastructure, no criteria change, no OWNER gate

1. **Dispatch dedup first.** Refuse a new work_item when an active/pending one exists for the same
   (ea, symbol, phase); route retries through `attempt_count`. Recovers no pairs but ~9 600 wasted
   backtest launches. Doing this before any requeue is what makes the requeues affordable.
2. **Q10 → DB ingester.** Walk the aggregates, upsert work_items + ea_metrics keyed on
   `generated_at_utc`, ingest INVALID as INVALID. Then re-run `ftmo_qualification`. **20 pairs.**
3. **Q09 sleeve-stream export repair.** `load_streams` gates on the stream file, not the backtest;
   five pairs with 60–296 Q08 trades are stamped NEED_MORE_DATA because their stream has < 20.
   Proven repairable — 11421 already progressed NEED_MORE_DATA → FAIL → PASS after a stream fix.
4. **Shared cold-cache retry helper** in `_phase_utils`. Today `run_with_launch_fault_retry` retries
   only `0xC0000142`; a BARS_ZERO / M0_1970 run exits 1 and goes terminal at attempt 0. This class
   leaks at every gate. Then requeue warm: Q05 41, Q07 17, Q08 13, Q06 5, Q10 3. **Never re-import
   `.DWX` history.**
5. **Q04 fold-summary + expert-path hardening**, then requeue its 981 unmeasured pairs.

### Track B — evidence defects

6. **Mirror `payload.final_failure` into `verdict_reason` and backfill.** 43 430 rows currently
   carry a NULL reason. Any survey of why the factory fails is blind to its largest class.
7. **`ACTIVE_TIMEOUT` is a harness kill stamped `verdict='FAIL'`** (`farmctl.py:4338`) at Q02 (242),
   Q03 (11), Q06 (1). It inflates the apparent strategy-rejection rate and freezes ~29 Q02 pairs at
   a fake strategy-FAIL that will never be requeued. Map to INFRA_FAIL, backfill.
8. **Point Q04 at the durable report root** and exclude aggregates from the purge.
9. **Requeue the 75 zero-variance Q07 pairs** on the repaired injector — evidence integrity. Start
   with the 12 in the book.
10. Stale docstrings: Q06 and Q10 both still say `DD < 15%`; the enforced constant is 25.0.

### Track C — criteria changes, OWNER decision required

- **C1 — Q09 thresholds.** Verifier correction, important: DL-083 line 51 says *"Admission itself
  remains an OWNER gate; this DL calibrates the recommendation engine only."* So the live 0.30 is
  **not** a violation — porting 0.15/0.40/0.020 into `portfolio_admission.py` is a **new** decision
  DL-083 deliberately deferred, not clerical wiring. ~8 pairs at stake. The open sub-question is
  regime-split correlation vs single Pearson.
- **C2 — Q08 8.5/8.7 INVALID.** ~17 sleeves, the largest mid-funnel unlock and the sharpest fork.
  The block is enforced by a code comment citing an "OWNER 2026-07-17" ruling; the only 07-17
  decision file governs neighborhood **FAIL**, not unevaluable **INVALID**. Options: waive to PASS
  (admits unmeasured overfitting risk), waive to the Q09 portfolio track (correlation still gates
  them — the honest middle), or wire Q03 to publish the sweep grid so the sub-gates genuinely
  compute (correct long-term, near-zero recovery now). Also ratify or fix
  `DL077_MIN_QUALITY_PASSES = 1` against DL-077's proposed 4.
- **C3 — Q03.** Either wire the plateau runner or formally ratify trade-floor-only and retire the
  orphan. The current state implies a gate that does not run.
- **C4 — Q07 zero-variance → INVALID**, and **Q02 gate ordering** if Q02 is ever to screen
  profitability rather than frequency.

## What the audit could not answer

- Whether any requeued infra pair actually *passes*. Every Track A number is measurements recovered,
  not passes. No backtests were run.
- Whether the Q02 `summary_missing` class re-measures cleanly. Its transient classification rests
  **entirely** on a pair-level recovery rate of 73.8 %, because every log and evidence directory for
  those 43 737 rows is purged. **Canary 50 pairs before releasing the rest** — this is not optional.
- Q04 no-fire ground truth: 0 of 3 787 no-fire aggregates survive on disk.
- Whether a live EA actually loads its KS baseline at OnInit. The write path is verified, the
  runtime is not.

## Corrections to the synthesis, from verification

- Stuck Q02 pairs are **~2 246**, not the synthesis's ~1 289 — under-compressed by 1.7×. Cuts in
  favour of the requeue's value. All-gate stuck total ~3 301.
- "Zero remaining attrition" on the 20 Q10 orphans is wrong; Q11–Q13 still apply.
- "DL-083 numbers are already ratified, this is mostly wiring" is wrong; see C1.
- The one genuine inter-audit contradiction — the Q06 auditor claiming Q10 still sits at DD 15.0 —
  is refuted: `q10_confirmation.py:50` reads 25.0, and QM5_13213/USDJPY empirically passed at
  dd 22.80 on 2026-07-25, which is impossible under a 15 % ceiling.
