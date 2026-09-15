---
source_id: QM-RESEARCH-YYYY-NNNN
source_type: internal_research
source_author: Kimi
source_model: <exact Kimi model id captured at runtime, e.g. kimi-code/kimi-for-coding>
source_artifact: strategy-seeds/sources/QM-RESEARCH-YYYY-NNNN/source.md
source_sha256: <hex of source.md, filled at mint>
source_uri: QM-RESEARCH://YYYY-NNNN
timestamp: <UTC ISO-8601>
task_id: <originating router task id>
hypothesis_family: <momentum|mean_reversion|breakout|...|failure-mode|regime-conditioning>
research_trial_count: <the search_history_ledger count for this family — DECLARED, evidence-backed>
---

# QM-RESEARCH-YYYY-NNNN — <edge title>

> HYPOTHESIZE artifact template (design doc sec 3.1). Kimi-authored, IMMUTABLE by
> content hash + append-only ledger + git history. Any later edit mints a new
> version id with a parent link — never a silent rewrite. Every quantitative claim
> below MUST cite a computed-output file recorded (with sha256) in research.json
> (numeric-provenance rule, design doc sec 2.4). An LLM-computed number is never the
> evidence.

## Research question
<The precise question DISCOVER set out to answer.>

## Source datasets
<OBSERVE dataset stamp + manifest sha256 (dataset_id); evidence paths + hashes.>

## ML method
<Clustering / dimensionality reduction / tree feature-importance / etc., if any.
Offline research instrument only — never enters the EA.>

## Observations
<What the data showed. Each figure cites its computed-output file (sha256).>

## Proposed market mechanism
<The economic / behavioural cause — conditional and interpretable, not a prediction.
Form: "When A + B + C holds, subsequent behaviour differs materially from baseline.">

## Candidate edge
<The mechanizable edge, in condition -> behaviour-differs-from-baseline form.>

## Confidence / uncertainties
<Calibrated confidence and the open uncertainties.>

## Likely confounders
<Survivorship, symbol concentration, regime, transaction cost, selection bias.>

## Related existing strategies
<ea_id / strategy_id references to what QuantMechanica already trades/tests, so the
critic can judge whether this is genuinely distinct.>

## Fenced manifest block
```qm-research-manifest
research_json_sha256: <hex>
lineage_json_sha256: <hex>
critic_receipt_json_sha256: <hex>
dataset_manifest_sha256: <hex>
```

## Critic receipt
<Reference to critic_receipt.json (cross-vendor, non-Kimi critic); repo_write must
be false or research_source.verify fails closed (design doc sec 5).>

## Hypothesis lineage
<Version and parent link (lineage.json). Post-holdout edits mint a new version.>

## Research provenance
<The ML-derived narrative. Exempt from the ML text-scan at intake and in
mechanization_check, keyed on this exact heading string.>
