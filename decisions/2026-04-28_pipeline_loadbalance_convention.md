---
dl: DL-035
date: 2026-04-28
title: Pipeline-Operator load-balancing dispatch convention — `target_terminal: T1..T5 | any` + binding de-dup tuple, T1-T5 parallel discipline
authority_basis: DL-023 (CEO broadened-autonomy waiver, class 4 — internal process choices → parallel-run rules) + DL-029 (Strategy Research Workflow — T1-T5 load balancing) + DL-025 (T6 boundary)
recording_issue: QUA-301
companion_to: DL-029 (DL-035 operationalises the dispatch convention named in DL-029); canonical spec lives in [`processes/15-pipeline-op-load-balancing.md`](../processes/15-pipeline-op-load-balancing.md) authored under QUA-246
source_change: Pipeline-Operator ACK child of QUA-297 created this heartbeat
status: active
---

# DL-035 — Pipeline-Operator Load-Balancing Dispatch Convention (interim)

Date: 2026-04-28
Issue: [QUA-297](/QUA/issues/QUA-297) (OWNER 2026-04-28 audit — operational changes triggered)
Recording issue: [QUA-301](/QUA/issues/QUA-301) (this entry's authoring task)
Owner: CEO (`7795b4b0-8ecd-46da-ab22-06def7c8fa2d`) — convention; Pipeline-Operator (`46fc11e5-7fc2-43f4-9a34-bde29e5dee3b`) — execution
Recorder: Documentation-KM (`8c85f83f-db7e-4414-8b85-aa558987a13e`)
Authority: [DL-023](./2026-04-27_ceo_autonomy_waiver_v2.md) — class 4 "internal process choices → parallel-run rules". Companion to [DL-029](./DL-029_strategy_research_workflow.md) (research workflow → T1-T5 load balancing).
Status: Active. Operational convention; canonical spec is [`processes/15-pipeline-op-load-balancing.md`](../processes/15-pipeline-op-load-balancing.md).

> **Recorder's note (Doc-KM scope per BASIS).** This DL records the *dispatch convention* CEO ratified under broadened-authority on 2026-04-28 in response to OWNER audit feedback ("all 5 MT5 instances should work in parallel"). The full operational spec — least-loaded round-robin, symbol-affinity tie-break, de-dup registry schema, evidence contract, escalation thresholds — is the canonical [`processes/15-pipeline-op-load-balancing.md`](../processes/15-pipeline-op-load-balancing.md) authored under QUA-246. This DL is the at-a-glance ADR for cross-reference; the process file is the operational source of record.

> **DL-NNN-collision note.** QUA-301 preallocated this entry as **DL-034**. While QUA-301 was being staged, `agents/docs-km` had already committed DL-033 for the OWNER addendum on no-strategy-prioritization + canonical lifecycle (recording task QUA-272, commit `f434e6b`). Per registry convention "skipped numbers are intentional gaps; do not reuse" and the "max(existing) + 1" allocation rule, the QUA-301 omnibus shifts up by one: heartbeat → DL-034, this entry → **DL-035**, EA Review Gate → DL-036. The work product itself is unchanged.

> **Path-detail reconciliation note.** QUA-301's task description named the de-dup index file as `D:\QM\Reports\pipeline\dedup_index.json`. The canonical operational spec at [`processes/15-pipeline-op-load-balancing.md`](../processes/15-pipeline-op-load-balancing.md) (authored Pipeline-Op 2026-04-27 under QUA-246) implements the same tuple contract as a CSV registry at `D:\QM\reports\state\factory_run_dedup_v1.csv` with lock file `factory_run_dedup_v1.lock`. The committed file paths win — they were authored against actual runner output schemas. This DL records the convention; the process file holds the file paths.

## Decision

Pipeline-Operator load-balances backtest issues across MT5 factory terminals `T1`-`T5` per a **least-loaded round-robin with symbol-affinity tie-break** policy. Every backtest issue spawned at the issue tier carries a `target_terminal: T1 | T2 | T3 | T4 | T5 | any` selector; Pipeline-Operator picks the least-loaded eligible terminal when `target_terminal: any`. The de-dup tuple `(ea_id, version, symbol, phase, sub_gate_config)` is binding — the same tuple is never executed twice; any rerun must change the `sub_gate_config` digest (for example, an explicit CTO-approved `retry_tag`) to produce a new tuple. T1-T5 work in parallel under this policy; T6 is out of write scope.

## Why

OWNER audit on 2026-04-28 (QUA-297) surfaced that earlier overnight cycles had not exercised the full T1-T5 fleet in parallel — work had piled onto a subset of terminals while others sat idle. OWNER's directive: "all 5 MT5 instances should work in parallel."

The least-loaded policy operationalises that directive without inventing a separate scheduler: it just picks the terminal with the lowest active-job count, breaks ties on symbol-affinity (warm cache), and respects the per-terminal one-active-scanner cap. The de-dup tuple closes the obvious failure mode where parallel dispatch could otherwise re-run the same combination twice across two terminals.

## Authority

Falls inside [DL-023](./2026-04-27_ceo_autonomy_waiver_v2.md) § "Broadened CEO authority", class 4 — *internal process choices → parallel-run rules*. Companion to [DL-029](./DL-029_strategy_research_workflow.md) which named "T1-T5 load balancing" as part of the research-to-pipeline workflow shape but did not specify the dispatch policy. DL-035 fills that gap with a binding policy.

CEO acted unilaterally per the DL-023 decision rule ("err toward acting"). No OWNER surfacing required; OWNER audit was the trigger, but the response is in-class for CEO.

## Scope

- **Applies to:** all backtest issues spawned in the V5 Pipeline Operations project that target MT5 factory terminals T1-T5; all P1-P10 phase runs.
- **Does not apply to:** T6 anything (DL-025 boundary); EA review/approval gates (DL-030 + DL-036); strategy-card extraction (DL-029 § research); live-deploy (V5 hard rule).

## Convention summary (binding for Pipeline-Operator)

1. **Issue spawn carries `target_terminal`.** Issue creators (CTO, Pipeline-Op, Development) tag the backtest issue with `target_terminal: T1..T5 | any`. `any` is the default and the recommended value unless symbol-affinity or sweep-isolation requires pinning.
2. **Pipeline-Op picks least-loaded for `any`.** Build eligible terminal set (`active` or `idle_or_stalled`, terminal PID alive, not quarantined). Rank by active job count, lowest first. Tie-break: prefer terminal whose most recent completed run used the same symbol; then round-robin pointer.
3. **De-dup is binding, not advisory.** Tuple `(ea_id, version, symbol, phase, sub_gate_config)` is never executed twice. Storage path and schema live in [`processes/15-pipeline-op-load-balancing.md`](../processes/15-pipeline-op-load-balancing.md) § "De-Dup Registry".
4. **One active scanner per terminal max.** No multi-cohort packing on a single terminal — even when nominally idle.
5. **T1-T5 parallel discipline.** All five terminals carry concurrent work whenever the queue can supply it; OWNER's parallel-fleet expectation is the binding floor, not a soft target.

For evidence contract, escalation thresholds, quarantine handling, restart procedure, and full schema, defer to the canonical process file.

## Cross-links

- **Authority basis:** [DL-023](./2026-04-27_ceo_autonomy_waiver_v2.md) — CEO Autonomy Waiver, broadened scope.
- **Companion DL:** [DL-029](./DL-029_strategy_research_workflow.md) — research workflow that named T1-T5 load balancing as a shape requirement; DL-035 is the dispatch policy that operationalises it.
- **Boundary basis:** [DL-025](./DL-025_t6_deploy_boundary_refinement.md) — T6 stays out of write scope; this DL only governs T1-T5.
- **Canonical operational spec:** [`processes/15-pipeline-op-load-balancing.md`](../processes/15-pipeline-op-load-balancing.md) (authored under QUA-246).
- **Source / driver:** [QUA-297](/QUA/issues/QUA-297) — OWNER 2026-04-28 audit ("all 5 MT5 instances should work in parallel").
- **Recording task:** [QUA-301](/QUA/issues/QUA-301) — this DL entry's authoring task (the recording omnibus for DL-034 / DL-035 / DL-036).
- **Pipeline-Op ACK:** child issue of QUA-297 spawned by CEO this heartbeat (Pipeline-Operator's ACK handle for the directive).
- **Registry:** [`decisions/REGISTRY.md`](./REGISTRY.md) — DL-035 row.
- **DL-027 propagation classification:** `reference_only` — no agent prompt body change.

## Reversal / lifecycle

DL-035 stays "interim" until the policy is exercised through at least one full SRC0N cohort (Wave 2 baseline runs) and the de-dup registry is observed under realistic load. If post-cohort review shows the policy needs tightening (e.g. explicit per-symbol pinning, cohort-priority weights, anti-starvation rules), CEO records the refinement as a successor DL-NNN and updates [`processes/15-pipeline-op-load-balancing.md`](../processes/15-pipeline-op-load-balancing.md) accordingly.

## Boundary reminder

T1-T5 only. T6 OFF LIMITS (DL-025). This DL governs dispatch, not strategy approval, EA review, or live deploy. The de-dup tuple is the only hard guarantee Pipeline-Op makes about not re-running combinations; PASS/FAIL judgement remains with the gate-evaluating agent.

— CEO operational convention under DL-023 broadened-autonomy waiver, ratified 2026-04-28 in response to OWNER audit (QUA-297). Recorded by Documentation-KM 2026-04-28.
