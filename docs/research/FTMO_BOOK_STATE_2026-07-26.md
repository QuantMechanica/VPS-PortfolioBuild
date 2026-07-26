# FTMO book — where we actually stand, 2026-07-26 evening

OWNER goal: a **test-worthy** FTMO book. This is the honest state, the arithmetic behind
it, and what was done tonight. Every number here comes from the live DB or the qualification
tool, not from campaign notes.

## The one-line answer

A test-worthy book cannot be assembled from the current pool, and the reason is not the one
the campaign notes assume. It is not basket magic (fixed today, moved `challenge_ready`
0 → 0), and it is not raw trade density. It is that **the dense strategies we own are dense
because they are fragile** — Q08 rejects them — and the two candidates that are genuinely
sound are not dense enough to move a 10 % target.

## Wall 1 — the qualification funnel (live count, 209 candidates)

| criterion | pass | note |
|---|---:|---|
| build clean | 207 | |
| active magic registered | 201 | baskets now 14/14 after today's fix |
| Q04 PASS | 86 | the survivorship gate, as designed |
| **Q08 strict PASS** | **14** | soft passes deliberately do not count for a paid challenge |
| **Q10 row present** | **34** | 175 candidates have never reached the closing verdict |
| Q08 baseline stream linked | 127 | |
| fresh intraday MAE stream | 142 | |
| trades ≥ 50 | 163 | |
| **`challenge_ready`** | **0** | 2 candidates sit at `RESEARCH_LEAD` |

Source: `ftmo_qualification.py` read-only inventory, 2026-07-26T17:39:41Z, 209 EA-symbol
candidates.

Note the shape: Q08-strict (14) and Q10 coverage (34) are the throttles, and they are doing
their job. 13 candidates hold **both** Q08 PASS and Q10 PASS and still fail — on evidence
files that are missing or older than the binary they are supposed to certify.

## Wall 2 — the density/drawdown inversion

Q10-confirmed pool, trades over the ~7.5 y full-history window:

| EA | symbol | PF | trades | ≈tr/yr | DD % |
|---|---|---:|---:|---:|---:|
| 13213 | USDJPY | 1.16 | 1624 | 217 | 22.8 |
| 13301 | GDAXI | 1.28 | 742 | 99 | 14.5 |
| 10692 | NDX | 1.08 | 686 | 91 | 14.9 |
| 10128 | XAUUSD | 1.05 | 433 | 58 | 6.1 |
| 12969 | USDJPY | **1.54** | 331 | 44 | **2.0** |

Exactly one sleeve exceeds 200 tr/yr, and it carries 22.8 % drawdown at PF 1.16. FTMO caps
total loss at 10 %, which forces such a sleeve to roughly 0.4× size — and 0.4× of a
PF 1.16 edge, after FTMO costs, is close to nothing. The inversion is the whole problem:
**what is dense is fragile, what is sound is thin.** 12969 is the one counterexample
(PF 1.54 at 2.0 % DD) and it is the archetype the sourcing doctrine was built on:
intraday-flat, broker-clock arithmetic, no overnight exposure, hence no gap drawdown.

Caveat worth testing rather than assuming: sleeve drawdown is not book drawdown. Six
genuinely uncorrelated 20 %-DD sleeves do not produce a 20 %-DD book. The joint simulator
(`ftmo_bar_joint_book_sim.py`) exists to answer that, and it has only ever been run over the
strictly-admissible 4-sleeve book. Running it over the dense-but-drawdowny set is an open
question with real upside.

## Wall 3 — the density cohort that was supposed to fix this

Thirteen EAs (20030–20045) were built in the 07-22 campaign as intraday-flat density motors,
hit a self-inflicted schedule-ledger trap that produced zero trades, and were repaired
07-22/25. Nobody verified the repair. Verified now:

- **Trading and profitable: exactly one.** QM5_20039 `onr-mid-brk` on NDX — Q02/Q03/Q04 PASS,
  PF 1.11–1.15, 419 trades, +$22 k. Stalled at Q05 on an INFRA_FAIL, requeued.
- **Trading and ruinous: three.** 20033 (PF 0.58–0.88, DD 76–93 %), 20040 (Q05 FAIL, DD 99.6 %),
  20041 (PF 0.86, DD 81 %). Dead on merit.
- **Still firing zero trades after the repair: four.** 20030, 20034, 20038, 20044 — the
  FX/commodity legs. The repair worked on index symbols only; the fail-closed trap is
  effectively still in force for these.
- **Never executed at all: three.** 20031, 20037, 20045 — queue items still `pending`.
- **QM5_20007, the decisive experiment: never had a single clean run.** 21 work items, 100 %
  INFRA_FAIL — every one of them on `SP500.DWX`, all with the same
  `shared_bases_history_lock_storm` signature. The grid motor-factory that was supposed to
  settle whether intraday density is achievable on our instruments **has never been
  evaluated**. Its own card states the falsification: if no lane clears Q04+Q08 net,
  intraday-on-our-instruments is empirically closed. We do not know, because one symbol's
  history contention ate every attempt while its NDX / XAUUSD / GDAXI runs sat unclaimed.
  **Correction 2026-07-26 (OWNER):** an earlier version of this note called SP500 a
  backtest-only symbol and used that to justify skipping it. That is wrong — SP500 is
  live-tradable and QM5_11132 has traded it in the deployed DXZ book since 2026-07-19
  (`ORDER_ROUTABLE_CONFIRMED`, evidence
  `docs/ops/evidence/DXZ_11132_SP500_DIRECT_ROUTABILITY_2026-07-16.md`). The SP500 lane is a
  legitimate FTMO candidate and its history-lock storm is a defect to fix, not a reason to
  drop the symbol.
- **QM5_1581 does not exist** — an unbuilt `.mq5` stub with no `.ex5` and zero work items.
  It is not the Baltussen sleeve the campaign notes assume.

So the honest count of confirmed intraday-flat motors is **two**: 12969 and (pending Q05)
20039. The requirement is six to eleven.

## Actions taken tonight

1. **Q08 re-runs enqueued for the two densest recoverable EAs.** Both died at Q08 on
   *infrastructure*, not merit, so this is a free retry on real material:
   - QM5_10582 XAUUSD — 3113 trades (~415/yr), PF 1.11, clean Q02→Q07 PASS chain. The
     densest EA in the farm, never judged. It was also looping: Q07 has been PASS since
     04:07 today, yet three further Q07 runs were queued instead of retrying Q08.
   - QM5_9936 USDJPY — 1252 trades (~167/yr), PF 1.28, net $149 k.
2. **Evidence-gap requeue for the two candidates closest to `challenge_ready`.** QM5_10128
   and QM5_10145 (both XAUUSD) clear everything except Q02/Q03 evidence files that were
   deleted from `D:\QM\reports\work_items` (whole directories gone — not the log pruner,
   which only removes `*.log` and explicitly keeps every JSON) and that predate the rebuilt
   binary anyway. Re-running is the correct fix, not a workaround: qualification must
   certify evidence that provably pertains to the deployed binary. Four rows flipped
   `done → pending`, reversible from
   `D:\QM\reports\state\requeue_evidence_gap_20260726.json`, and placed on the priority
   track so they are not buried behind 2089 pending Q02 items.
3. **Queue-shape finding:** the pending queue is 96 % Q02 (2089 of ~2175) with exactly one
   pending Q08 and no pending Q10. The gates that produce FTMO-relevant verdicts are
   starved by shallow-gate volume.

## What would actually move the needle, in order

1. **Unblock QM5_20007.** It is the single highest-information action available: it either
   yields a family of intraday density motors or falsifies the whole intraday thesis on our
   instruments. Blocker is an EA-side journal bomb, i.e. a logging fix, not a strategy
   question.
2. **Carry 20039 through Q05–Q10.** The one profitable intraday candidate the campaign
   produced. Treat it as the prototype that proves the cohort's design can work.
3. **Diagnose the residual zero-trade trap on the FX/commodity legs** (20030/20034/20038/
   20044) and execute the three that never ran (20031/20037/20045). Cheap — the EAs exist.
4. **Run the joint book simulator over the dense set**, not only the strictly-admissible
   four, to find out whether correlation structure lets drawdowny sleeves coexist under the
   10 % cap.
5. Only then assemble and MC-gate a book.

## What this means for the goal

A test-worthy book is a multi-week programme, not a session. The realistic near-term
milestone is different and worth naming: **the first `challenge_ready` sleeves the farm has
ever produced** (10128/10145, pending the Q02/Q03 re-runs) — which proves the qualification
chain works end to end. Two correlated gold sleeves are not a challenge book, but going
0 → 2 converts an untested pipeline into a demonstrated one.
