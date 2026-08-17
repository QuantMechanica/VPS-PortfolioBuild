# A two-month-old `.ex5` voids healthy backtests — QM5_1119, with 20 more queued behind it

## What surfaced

`stream_and_selfreport_missing` reappeared after 24 h at zero: work item
`61ea8ed9`, **QM5_1119 / XAGUSD.DWX / Q04**, `INFRA_FAIL`, all three folds voided.

I have been watching this reason string every round as the **Host-Slot-Magic class** (task
18954866). It is not that class. Four wrong turns, each corrected by a measurement, are recorded
below because the sequence is the useful part.

## The runs were healthy — that is the whole point

| Fold | `exit_code` | `report_pf` | `report_trades` | stream `trades` | `pf_net` | status |
|---|---:|---:|---:|---:|---:|---|
| F1 | 0 | 0.70 | **206** | **0** | None | INVALID |
| F2 | 0 | 0.71 | **197** | **0** | None | INVALID |
| F3 | 0 | 1.06 | **183** | **0** | None | INVALID |

The surviving journal confirms a normal run end-to-end:

```
18:58:19  Tester   XAGUSD.DWX,H1: testing of QM5_1119...ex5 from 2023.01.01 to 2023.12.31 started
18:58:21  Trade    2023.01.04 06:00:00  market buy 1.19 XAGUSD.DWX sl: 23.943 tp: 24.447
18:58:21  Trade    2023.01.04 13:15:55  take profit triggered #2 buy 1.19 XAGUSD.DWX
19:05:03  Tester   final balance 104299.06 USD
19:05:03  Tester   OnTester result 1.062504052747507
19:05:03  Tester   Test passed in 0:01:08.395
```

**A test that passed in 68 seconds, traded 206 times and ended up 4.3 % — discarded as an
infrastructure failure.** Not because the backtest failed, but because one evidence channel was
never written.

And the decisive absence: across **6,772 journal lines, zero** lines matching
`selfreport|self.report|stream|\.csv`. The EA did not fail to write the stream. **It never
attempted to.**

## Root cause: the binary predates the emitter

Neither `QM5_1119.mq5` nor its sibling declares an emitter — both include only
`<QM/QM_Common.mqh>`, so stream emission lives in the shared framework include. Source is
therefore *not* the discriminator. The binary is:

| EA | `.ex5` built | size | wrote a stream today? |
|---|---|---:|---|
| **QM5_1119** | **2026-06-21** | **141,840 B** | **no — 0 of 206 trades** |
| QM5_1118 | 2026-07-14 | 308,546 B | yes — 491 / 1310 / 389, matching `report_trades` exactly |
| QM5_10295 | 2026-07-14 | 321,734 B | yes — 41 / 44 / 46 |

QM5_1119's binary is two months old and **less than half the size** of siblings that work. The
framework includes changed on 07-01, 07-02, 07-20, 08-16 and 08-17. A binary compiled before the
trade-stream emitter existed cannot emit it, which is exactly what the journal shows.

## Blast radius, measured — and honestly bounded

`artifacts/stale_ex5_census_20260817.json`. Of **3,274** built binaries (median 277,960 B),
**65 fall below 200 kB**, essentially all from one 2026-06-21 build batch.

**23 EAs with 57 pending rows sit on such a binary** — 20 of those rows are QM5_1119's own
Q04 fan-out, created today at 16:52, i.e. up to **60 fold-runs** of guaranteed-void work.

The proxy was tested against outcomes rather than assumed, Q04 rows decided since the 07-06
evidence wall:

| cohort | n | INFRA_FAIL | rate |
|---|---:|---:|---:|
| small binary (<200 kB) | 48 | 20 | **41.7 %** |
| large binary | 4,996 | 788 | 15.8 % |

**2.6× elevated — supportive at n=48, not merely n=1.** But 28 of those 48 produced economic
verdicts, so a stale binary is a **risk factor, not a certainty.** Scoping accordingly:

- **Proven:** QM5_1119. Mechanism read from its journal, reproduced today, 20 rows queued.
- **Elevated risk only:** the other 22 EAs / 37 rows. Not asserted as broken.

## Why this looked like a requeue and is really a rebuild

The 20 pending symbols are **exactly** the cohort that INFRA_FAILed on 2026-06-18/22
(AUDCAD … XTIUSD, GDAXI), and they are **disjoint** from the 11 symbols that earned economic Q04
verdicts on 07-01…07-04. So a recovery sweep requeued a two-month-old failed cohort today, and the
first member to run **reproduced the original failure** — because nothing in the requeue path asks
whether the binary can produce the evidence the gate requires.

This is the "repetition limit belongs at the level of the cause" rule with a concrete instance: the
cause is a stale artefact, so no number of requeues can clear it.

## Four corrections of my own, in order

| I concluded | Falsified by |
|---|---|
| Host-Slot-Magic class (as reported every round) | the authoritative scanner: QM5_1119 has **0** affected pairs |
| grep for `req.symbol_slot = qm_magic_slot_offset` finds it | that *is* the over-counting historical detector the scanner's own docstring warns about; and the **proven-fixed** QM5_11424 is itself in `affected_pairs`, so that set is a historical requalification cohort, not current breakage |
| missing magic-registry row for XAGUSD is the cause | QM5_1118 has **no** XAGUSD row either and wrote a perfect stream (491 trades) |
| the run-directory `.log` is this run's journal | it is the **terminal-wide daily journal**; my first read showed `qm_ea_id=12935` at 14:47, hours before this item was claimed at 16:54 |

**And one process failure I will not dress up.** I wrote a pre-registration file for the
QM5_1118 / QM5_10295 pair at 17:15:32. Their verdicts had already landed at **17:07:00** and
**17:13:09**. That is not a pre-registration and it is not presented as one; the file records the
timestamps against itself. The hypothesis it contained was falsified within two minutes by the very
case predicted to replicate.

## What actually fixes it

A **rebuild**, not a requeue. The pending rows carry no verdicts, so rebuild-then-run is clean and
raises no rebinding question — a rebuilt `.ex5` would otherwise require requalification, never a
hash rebind.

Deliberately **not** done: no hold applied. `farmctl` exposes no hold or quarantine operator, and
inventing an unsupported one would be exactly the fail-closed-label-without-an-operator defect this
finding is an instance of. Builds belong to Codex under the capability contract, so the repair is
dispatched there rather than executed by me against a live factory (7 active claims, and the
magic-resolver race requires serial builds).

## Evidence

- work item `61ea8ed9-0846-44c6-9706-82c06be2a7af`, aggregate `q04_aggregate/v2`, 3 folds
- journal `D:\QM\reports\work_items\61ea8ed9…\QM5_1119\raw\20260817.log` — 6,772 lines, retained
  **only because of the 12 h retention raise**; under the previous 2 h rule this root cause would
  have been unavailable
- `artifacts/stale_ex5_census_20260817.json` — 3,274 binaries, 65 below cut, 23 EAs / 57 rows
- `tools/strategy_farm/scan_host_slot_magic.py` — `qm.host-slot-magic-affected-set/v2`,
  781 affected sources / 260 EAs / 1,902 pairs, `affected_pre_fix`
- `artifacts/prereg_registry_coverage_20260817.json` — the falsified hypothesis, with the timing
  admission recorded in place
