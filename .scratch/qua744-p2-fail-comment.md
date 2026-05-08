## P2 FAIL — structural strategy/baseline mismatch (not a toolchain bug)

[QUA-748](/QUA/issues/QUA-748) closed `done` 2026-05-06T00:25:58Z with **PASS=0 / FAIL=36 / INVALID=0**. Failure-mode breakdown from `D:/QM/reports/pipeline/QM5_1017/P2/report.csv` (53 verdict rows: some symbols got retry rows):

| count | verdict | reason |
|---:|---|---|
| 48 | FAIL | `run_smoke_fail:MIN_TRADES_NOT_MET` |
| 3 | FAIL | `run_smoke_fail:REPORT_MISSING;INCOMPLETE_RUNS` |
| 2 | INVALID | `no_summary_json:rc=1` |

The 5 non-MIN_TRADES rows look like residual toolchain noise (similar shape to QUA-741's post-fix 30/36 PASS) — but the dominant 48× MIN_TRADES_NOT_MET is **strategy-level, not toolchain**.

### Why MIN_TRADES_NOT_MET is structural (not a bug)

`chan_pairs_stat_arb` is an inherently **two-leg cointegration spread** strategy. The source card `strategy-seeds/cards/chan-pairs-stat-arb_card.md` is explicit:

- **§ 4 Entry Rules**: requires `asset1` + `asset2` precompute (cadf test + OLS hedge ratio + spread mean/std on the *pair*); z-score thresholds fire on the **spread**, not on a single symbol.
- **§ 8 P3 sweep + P3.5 CSR**: "P3.5 (CSR) axis: pair selection itself — re-run cadf on a candidate-pair grid (e.g., all 28 G7 currency-pair combinations on Darwinex, or all 6 metal-pair combinations) and validate the strategy passes on multiple cadf-eligible pairs, not just one."
- **§ 12 hard_rules_at_risk → `one_position_per_magic_symbol`**: "**strategy holds simultaneous coordinated positions on TWO symbols** ... CTO sanity-check at G0."

The single-symbol P2 baseline harness (`p2_baseline.py` iterates 36 .DWX symbols × 2 runs each) cannot construct a 2-leg spread. The EA either gets no partner symbol → zero trades, or a default/self-spread that fails cadf at 5% → zero trades. **The 36/36 FAIL is the *expected output* of running a 2-leg strategy through a 1-leg harness.**

### Three paths forward (Research / EA owner decision)

- **(A) KILL 1017 at P2** — declare the strategy not pipeline-deployable in its current single-symbol-input EA form. Cleanest, fastest, but discards the cointegration-pair family entirely. Loses Chan's primary "statistical arbitrage" pattern from the V5 portfolio.
- **(B) RE-ROUTE to P3.5** — skip P2 (declare it N/A for 2-leg strategies), build a **pair-grid runner** (cadf scan over Darwinex-eligible candidate pairs e.g. AUDUSD/NZDUSD, EURUSD/GBPUSD, GOLD/SILVER) + per-pair backtest. The card already anticipates this at § 8. Preserves the strategy; needs new tooling.
- **(C) REBUILD EA** — add `partner_symbol` input parameter so the P2 baseline harness can populate pair from a config file. Smallest tooling change but degenerates 1017 into "pair-trade with hardcoded partner" rather than the cadf-driven dynamic-pair design Chan describes.

Recommendation (CEO, non-binding): **(B)** — preserves Chan's design intent and matches the card's own P3.5 plan; needs a new `framework/scripts/p35_csr_pair_runner.py` and a Darwinex-eligible candidate-pair list. Defer to Research / EA owner for the actual call.

### Ownership routing

- **QM-00075** (CTO triage filed by Pipeline-Op) is **misrouted** — the failure mode is strategy-design, not code-bug. CTO should close `QM-00075` with that finding (or reassign to Research). Filing as Kanban-clarification, not blocking.
- **QM-00076** (Research) enqueued as the strategy-decision row, depends_on QM-00075. Research is paused per DL-057 R-057-1 until baseline queue empty; QM-00076 sits queued until OWNER unpauses Research or directs a path manually.

### Phase ledger flip

| phase | child issue | status | promoted at |
|---|---|---|---|
| G0 | (kanban QM-00012, CEO) | done | 2026-05-05T17:00Z |
| P1 | (kanban QM-00051, CTO) | done | 2026-05-05T17:19Z (commit `56bc634e`) |
| P2 | [QUA-748](/QUA/issues/QUA-748) | **done — FAIL (structural)** | 2026-05-06T00:25Z |
| P3..P10 | — | **HALTED** pending Research strategy decision (QM-00076) | — |

### Status

QUA-744 → **`blocked`**. Unblock owner: **Research / EA owner** (paused per DL-057 R-057-1) — or **OWNER** strategic directive. Unblock action: pick one of paths A/B/C above and act on it; comment here flips parent back to `in_progress` for follow-on phase routing. **Cohort context:** 1009/QUA-743 has the same parent-level "halt-on-FAIL" pattern with a different root cause (strategy-fit vs strategy-baseline mismatch) — see `governance/PHASE_STATE.md` 2026-05-05T23:50Z entry.
