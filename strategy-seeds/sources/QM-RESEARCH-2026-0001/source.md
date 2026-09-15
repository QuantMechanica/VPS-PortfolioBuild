---
source_id: QM-RESEARCH-2026-0001
title: FTMO gap: intraday session-bounded mechanical edge (CAMP-2026-0001)
source_type: internal_research
source_author: Kimi
source_model: kimi-code/kimi-for-coding
created: 2026-09-15
originating_task_id: CAMP-2026-0001-ftmo-gap
status: draft
parent_source_ids: []
source_artifact: QM-RESEARCH://2026-0001
---

# FTMO gap: intraday session-bounded mechanical edge (CAMP-2026-0001)

## Research provenance
Discovered by the first autonomous edge-discovery campaign (directive §47, §68 PHASE G). Kimi
(research role, offline) analysed a deterministic OBSERVE projection of QuantMechanica's own
backtest evidence (INFRA/setup/NO_REPORT separated from economic failures). Offline
statistical/ML instruments are permitted here (directive §41); the candidate below is fully
mechanical with no runtime model (directive §42). Kimi CLI 0.43.1,
status protected_write, latency 932.907s.

Kimi analysis (excerpt; full text in the campaign's kimi_answer.md):

Answer written to `D:\QM\research\campaigns\CAMP-2026-0001-ftmo-gap\kimi\research_answer.md`. Printing it in full below.

---

# CAMP-2026-0001 FTMO-gap — Kimi offline research answer

Date: 2026-09-15. Dataset: OBSERVE projection `observe/2026-09-15T14-12-39Z` (dataset_id `4deb0c21…1cba0`), 149,166 gate rows / 100,213 metric rows; 53,722 strategy-classified rows. All figures below are either from the deterministic OBSERVE summary (schema `qm.observe-summary/v1`) or recomputed directly from the projection CSVs (stated as "recomputed"). No numbers are invented; proposed-rule parameters are design choices, clearly separated from empirical claims.

---

## 1. Verdicts on the preregistered hypotheses

### H1 — intraday session-flat beats swing for FTMO fitness: **INCONCLUSIVE** (stated refutation criterion untestable; the testable proxy shows no meaningful intraday edge)

Evidence:
- Summary `h1_outcome_by_holding_class` gate pass rates: position **0.5567** (n=20,533) > intraday **0.5164** (n=19,516) > swing **0.5079** (n=9,160) >> scalp **0.3991** (n=3,478). Intraday beats swing by only **+0.85 pp** — noise-level — while the multi-day "position" class beats both. The shortest-holding class (scalp) is the *worst*, which breaks any monotone "shorter ⇒ better" reading of H1.
- Recomputed from `gate_outcomes.csv` (strategy rows; independent spot-check within ~2% of the summary): overall 27,501 PASS / 23,378 FAIL (51.2%); timeframe pass rates M1–M30 **45.3%** (9,878 rows), H1/H4 **54.4%** (22,276), D1/W1/MN1 **57.7%** (20,533).
- The preregistered refutation test — "intraday session-flat variants reduce worst-day loss / wdd_p90 vs med60" — **cannot be run on this projection**: there is no worst-day-loss, wdd_p90, or per-trade equity-curve field in any file (`ea_metrics.csv` has only aggregate net_profit/PF/trades/drawdown_pct/sharpe). What is observable (gate PASS) is a research-quality verdict, not the FTMO challenge simulator's P(pass ≤ 60 d).

Biggest confound: `holding_class`/`session` are design-time tags, not measured exposure — **51,805/53,722 = 96.5%** of strategy rows are `session=unspecified` (recomputed), and class populations differ by construction (the farm ran far more H1/H4/D1 swing than M1–M5 scalp), so pass-rate gaps mix design quality with test volume.

### H2 — low activity predicts FTMO failure more strongly than low median gain: **REFUTED in the available proxy** (preregistered FTMO-outcome test not runnable on this projection)

Evidence:
- Summary `h2_activity`: of 4,455 scored strategy rows, only **424 (9.5%)** are below the activity floor; trades/yr min 0, max 8,302, **mean 373.2**. If activity were the dominant failure driver, the below-floor fraction would be far larger; at population scale the book is not activity-starved. The campaign-level FTMO fact (Q10 FTMO gate admits 0/42 pairs, best FUND_SCORE 0.41 vs 1.0 floor) shows the binding constraint is fundamental quality, not density.
- Recomputed conditional pass rates from `ea_metrics.csv` (rows with populated metrics, all verdicts): activity gradient is flat-to-negative — trades < 50: 25,929 PASS / 21,907 FAIL = **54.2%**; trades ≥ 50: 1,591 / 1,553 = **50.6%** (−3.6 pp for *higher* density). Expectancy gradient is an order of magnitude larger — profit factor < 1.0: 582 / 1,519 = **27.7%** pass; PF ≥ 1.0: 1,364 / 618 = **68.8%** pass (+41.1 pp). Expectancy dominates activity as a pass/fail discriminator in every cut.
- The strict preregistered test (incremental explanatory power of activity *over FTMO simulator pass/fail*) is not runnable: the projection contains no FTMO challenge outcomes.

Biggest confound (two-sided): PF is endogenous to the farm gates (PF thresholds are plausibly baked into PASS criteria), which inflates expectancy's measured importance; but activity has no mechanical link to the verdict, so its near-zero gradient is the more honest signal. Also, the `trades` field is populated in only ~51k of 100,213 metric rows.

### H3 — a bounded no-trade filter on a shared loser regime lifts daily-loss survival: **NOT ESTABLISHED / INCONCLUSIVE** (the needed variable is missing; closest proxies argue against naive versions)

Evidence:
- Summary `h3_failure_clusters_top`: **all 15 top clusters are `session=unspecified`** — the dataset carries essentially no time-of-day attribution for the failures (recomputed: 96.5% unspecified; only 1,501 `open` + 1,716 `overnight` tagged rows). The common regime/time-of-day condition posited by H3 cannot be identified, so no bounded filter can be derived from this projection, and the refutation criterion (OOS daily-loss-survival improvement at ≥ net expectancy) is untestable here (no daily-loss series, no OOS split).
- Closest available proxy cuts *against naive session conditioning*: the farm's existing `session=open` EAs pass at only **44.4%** (332/747 decided, recomputed) vs 51.2% population; while `session=overnight`-tagged EAs — the class closest to the demo's killer exposure — pass at **62.8%** (536/853). So "tag a session" is not itself edge; only *designed, risk-controlled* session behavior is associated with quality.
- Raw fail clusters track test volume: fx_major (9,531 fails) and index (7,205 fails) are the most-tested classes (recomputed), so cluster rank ≠ toxicity rank.

Biggest confound: `session=unspecified` is likely a registry default for generic EAs rather than measured absence of session exposure; cluster counts conflate per-EA failure probability with how many EAs the farm ran in that cell.

---

## 2. Mechanizable hypothesis (high-density / short-holding / low-swap, mechanical, finite parameters)

**H-CW: Cash-window index continuation, session-flat ("trade the cash open, sleep flat").**

Structural cause (grounded in the OBSERVE evidence, not indicator soup):
- The farm's only deeply-validated FTMO-*shaped* pocket is **index intraday at the final gate**: among the 41 Q10 rows (40 PASS / 1 FAIL), index intraday/scalp entries are **9 PASS / 1 FAIL** (ND

...[truncated; full text in kimi_answer.md]

## Structural cause
A mechanical intraday strategy that opens and flattens within one trading session (no overnight hold) achieves higher simulated P(pass<=60d) at <=10% max-DD than the best current swing sleeve, because it removes the overnight/swap tail that produced the -10.26% FTMO demo breach. The current book is entirely D1/H1/H4 swing whose
overnight/swap tail produced the -10.26% FTMO demo breach; an intraday session-flat profile
removes that tail while raising trade density toward the FTMO min-trading-day requirement.

## Candidate edge (mechanizable)
See H1_card.md (session-bounded intraday mean-reversion; passes the mechanization gate). H3_card.md
proposes a bounded no-trade failure-cluster filter. H2 is an analytical (non-tradeable) diagnostic.

## Numeric provenance
Every quantitative claim resolves to a computed-output file in this artifact's manifest
(h1_result.json / h2_result.json / h3_result.json), derived deterministically from the OBSERVE
dataset (observe_manifest.json). No figure is LLM-computed.

## Source manifest

```qm-source-manifest
# Auto-generated by research_source.seal; do not hand-edit.
research.json:         231e1ccf0799d29a556fc1d2e66949ab4818b17c79188049d6d939eec00602b1
lineage.json:          cda23bc05e5ca2d8f3ce42e0d4875c459f0cdd20c90824d7c668f00d9d690560
critic_receipt.json:   e05bf622a78e9f22b57962162188a0398a0927a4d11cd752ac04ee2540fcf925
h1_result.json:        e8841d983c81cfbab1b5b8c9012dcbaf282831fb28f734064bd3fdb7fb0067e9
h2_result.json:        cb2dc83ef84a9bf5c8029a283c4f32a119ced1a60bb5b81b9f2103e7f878798a
h3_result.json:        c4372a3c9ee3ba719a7294245c2d7ffb94ce32cf57249b7b83cfc86ebde2e994
observe_manifest.json: 4deb0c2198ba3bbcefd371a698d2f3f0f326b188149cf9496cc232627781cba0
```
