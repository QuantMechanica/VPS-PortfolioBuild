# Plan: from zero to an FTMO-demo-testable book

OWNER goal: work until the book can be tested on an **FTMO demo account**. That bar is
deliberately different from a paid challenge — a demo needs a *deployable, coherent,
evidence-backed book*, not `P(pass) ≥ 0.80`. Separating the two is what makes this
reachable in days instead of weeks.

## What changed tonight: the first CHALLENGE_READY sleeves ever

```
QM5_10128 XAUUSD.DWX -> CHALLENGE_READY
QM5_10145 XAUUSD.DWX -> CHALLENGE_READY
```

`challenge_ready` went **0 → 2** against a 209-candidate inventory. Zero blockers on both.

They were never short on merit: every gate verdict existed, but the Q02/Q03 report files had
been deleted from `D:\QM\reports\work_items` and predated a rebuilt binary, so the
qualification contract — correctly — refused to certify the deployed `.ex5` with evidence
that did not belong to it. Re-running those two shallow gates closed it. **The pipeline is
proven end-to-end for the first time**, which is the precondition for everything below.

## Stage 1 — grow the pool to five, with diversification (in flight)

The full inventory finds exactly three further candidates blocked *purely* by evidence:

| EA | symbol | re-runs needed | why it matters |
|---|---|---|---|
| QM5_11421 | EURUSD | Q02–Q07 | first non-metal, non-index sleeve |
| QM5_13013 | NDX | Q02–Q07 | index lane |
| QM5_12567 | XAUUSD | Q02–Q07 | third gold sleeve |

18 backtests, all requeued on the priority track with a reversible snapshot
(`D:\QM\reports\state\requeue_evidence_gap2_20260726.json`). Result if they reproduce their
recorded verdicts: **5 ready sleeves across 3 symbols** — thin, correlated on gold, but a
genuine multi-symbol book.

## Stage 2 — the near-misses (needs gate work, not re-runs)

Six candidates sit within two blockers. The blocker histogram is unambiguous:
`q10_pass_missing` ×6, `q08_not_pass` ×5, `q03_pass_missing` ×1.

- **12710/XTIUSD and 12966/GDAXI** — `Q08 FAIL_SOFT` + no Q10. These are the two the
  qualification tool already classes as `RESEARCH_LEAD`. A soft Q08 is explicitly *not*
  sufficient for a paid challenge, but for a **demo** it is a legitimate, documented
  inclusion if flagged as such.
- **13036/GDAXI** — needs Q03 plus Q10 only.
- **13140 / 13144 / 13151** — the XTI/XNG baskets, `Q08 FAIL_HARD`. Not demo material.

Realistic ceiling from stage 2: **+3 sleeves (12710, 12966, 13036)**, giving 8 across
XAU ×3, EURUSD, NDX, XTIUSD, GDAXI ×2. That is a defensible demo book.

## Stage 3 — assemble and deploy to demo

1. Build a candidate book manifest (`sleeves` list with `ea_id`, `symbol`, `tf`,
   `risk_fixed`) and run `ftmo_book_readiness.py --book-manifest` against a fresh
   qualification + reconciliation artifact. The contract is all-or-nothing:
   `partial_book_approval: false`, so every sleeve must be ready.
2. Size the book. FTMO caps total loss at 10 %; the sleeve drawdowns here (10128 6.1 %,
   10145 4.8 %, 12567 2.4 %, 13013 3.8 %, 11421 6.4 %) are far friendlier than the density
   motors, so a conservative equal-risk allocation is workable without heroic down-sizing.
3. **Run the joint simulator over the actual candidate set** — `ftmo_bar_joint_book_sim.py`
   has only ever been run over the strictly-admissible four-sleeve book. Sleeve drawdown is
   not book drawdown, and the correlation structure is exactly what decides whether this
   book is worth a demo.
4. Produce demo deployment artifacts: presets with `ENV=live`, `RISK_PERCENT` set,
   `RISK_FIXED=0`, magic registry consistent (`ea_id*10000+slot`), and a deploy manifest.
   **A demo account is not T_Live** — no Hard-Rule AutoTrading gate applies to it, but the
   same verification discipline does.

## Stage 4 — what a paid challenge would additionally need (out of scope tonight)

The density arithmetic is unchanged and honest: only one Q10-confirmed sleeve exceeds
200 trades/year and it carries 22.8 % drawdown at PF 1.16. A paid challenge needs six to
eleven uncorrelated intraday-flat motors; we have two (12969, and 20039 pending Q05). That
is a multi-week sourcing programme, not a deployment step.

## Parallel track — stop the factory wasting itself

This is what unblocks everything above, because the gates that produce decision-grade
verdicts are starved: the pending queue is 96 % Q02 with **one** pending Q08 and **zero**
pending Q10.

Root-cause analysis in `docs/ops/evidence/2026-07-26_infra_fail_root_cause_analysis.md`:
2,553 of 5,879 runs in seven days were written off as infrastructure, and they are
**deterministic per (EA, symbol)** — QM5_11896 failed 119 of 119 runs. Fixes in flight with
Codex: a poison-pill quarantine so proven-dead work stops consuming slots, and a pre-run
gate that validates the calendar the EA actually reads.

## Framework review (OWNER question: does the framework still fit?)

Answer: **in one specific and severe respect, no.**

`QM_FrameworkInit` fails closed when `QM_NewsInit` cannot read the calendar, and inside the
tester that is a hard `INIT_FAILED` (`framework/include/QM/QM_NewsFilter.mqh`; live mode
degrades gracefully, the tester does not). The reader tries the absolute path, then the
absolute path with `FILE_COMMON`, and only then the basename in `Common\Files` — and since
MT5 build 5833 rejects absolute paths with error 5002, **the only functional route is
`Roaming\MetaQuotes\Terminal\Common\Files\<basename>`**, for *both* calendar files.

The severity comes from the population: **2,838 of 3,314 EA source directories (86 %) enable
the news filter by default** (`QM_NEWS_TEMPORAL_PRE30_POST30` + `QM_NEWS_COMPLIANCE_DXZ`),
and the failing WTI cohort carries settings *identical* to the healthy control QM5_12969. So
this is not a cohort defect — it is a fleet-wide hard dependency.

Net effect: a silent copy failure in a housekeeping PowerShell script — exactly what happened
tonight, verbatim `The process cannot access the file ... because it is being used by another
process` — bricks OnInit for 86 % of the EA population inside the tester, and the pipeline
records it as `INFRA_FAIL` with no pointer to the cause. Roughly 500 such failures per week.

Three things follow, in order of value:

1. **The pre-run gate must validate what the EA reads.** `run_smoke` checks the `D:` source
   and logs `news_calendar_status=OK` while the EA reads the Common copy. Briefed to Codex.
2. **Reconsider fail-closed-in-tester for a data dependency most strategies do not need.**
   An EA whose edge has nothing to do with news still inherits a hard dependency because the
   default is on. Either the default should be off for strategies that do not declare a news
   interaction, or the tester path should degrade like the live path and mark the run
   `NEWS_UNAVAILABLE` instead of destroying it. **This is an OWNER decision — it changes gate
   semantics, so I am not making it unilaterally.**
3. A broader EA-population audit is running (cohort defect scan) to find the other shared
   template defects — the `QM5_201xx` GBPUSD family currently producing `ZERO_TRADES` is the
   next candidate.

## Immediate next actions

1. Watch the 18 requeued backtests; re-run qualification when they land (expect 2 → 5).
2. Land Codex's poison-pill so Q08/Q10 stop starving.
3. Enqueue Q10 for 12710, 12966, 13036 once their Q08/Q03 positions are resolved.
4. Assemble the manifest and run the joint simulator over the real candidate set.
5. Bring the framework news-dependency decision to OWNER.
