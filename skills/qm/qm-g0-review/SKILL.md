---
name: qm-g0-review
description: Use when CEO is reviewing a Research-submitted Strategy Card for G0 (Gate 0) approval or rejection. Don't use without a submitted card in strategy-seeds/cards/. Don't use to evaluate P2+ pipeline results — this gate is research quality only.
owner: CEO
reviewer: Research
last-updated: 2026-05-08
basis: docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md § G0 + processes/qb_reputable_source_criteria.md
---

# qm-g0-review

Procedure for running the G0 (Gate 0) review on a Strategy Card, confirming source quality and architectural fit before any EA implementation is authorized.

## When to use

- Research has submitted a Strategy Card (`strategy-seeds/cards/<slug>_card.md`)
- The card status is `g0_verdict: PENDING` or blank
- CEO needs to formally approve or reject before CTO receives an EA build task

## When NOT to use

- Card does not exist yet (Research must submit first)
- Card already has `g0_verdict: APPROVED` or `g0_verdict: REJECTED`
- Reviewing P2/P3/higher pipeline results — this is a research quality gate only

## G0 Checklist (QB Reputable Source Criteria R1-R4)

Per `processes/qb_reputable_source_criteria.md` (BINDING for all G0 verdicts):

| Criterion | Question |
|-----------|----------|
| **R1 Source quality** | Author has verifiable track record (peer-known practitioner, academic, or institutional). Not anonymous, not blog-only. |
| **R2 Mechanical completeness** | Entry, exit, stop, and position sizing rules are explicit. No discretionary decisions required. |
| **R3 Darwinex-native data** | All required data is in the Darwinex CFD feed (no Bloomberg-only, no options data, no external API). |
| **R4 Architecture fit** | EA_ML_FORBIDDEN not violated. One-position-per-magic-symbol compatible. No sub-minute execution required. |

## Procedure

### 1. Read the card

```
strategy-seeds/cards/<slug>_card.md
```

Note the YAML header: `source`, `source_citation_short`, `strategy_type_flags`, `ea_id`, `g0_verdict`.

### 2. Evaluate R1-R4

For each criterion, record: PASS / FAIL / UNCERTAIN with a one-line reason.

### 3. Check strategy_type_flags vocabulary

Cross-reference flags against `strategy-seeds/strategy_type_flags.md` controlled vocabulary.  
Note any proposed vocab gaps — these go into the G0 verdict comment, not as a block.

### 4. Verdict decision

- **APPROVED**: All R1-R4 PASS (UNCERTAIN on R3/R4 acceptable if Board Advisor confirms Darwinex coverage)
- **REJECTED**: Any R1 FAIL (source quality non-negotiable) OR any R2 FAIL (can't implement without discretion)

### 5. Update the card

If APPROVED:
```yaml
g0_verdict: APPROVED
g0_reviewer: CEO
g0_reviewed_at: YYYY-MM-DD
```

If REJECTED:
```yaml
g0_verdict: REJECTED
g0_reviewer: CEO
g0_reviewed_at: YYYY-MM-DD
g0_rejection_reason: "<R1/R2/R3/R4 failure summary>"
```

### 6. Commit the card update

```bash
git add strategy-seeds/cards/<slug>_card.md
git commit -m "g0(<slug>): G0 APPROVED/REJECTED — R1/R2/R3/R4 verdict"
```

### 7. If APPROVED — create CTO build task

File a Paperclip issue assigned to CTO:
- Title: `Build EA for <slug>`
- Body: card path, ea_id (if allocated), G0 commit hash
- Link to the card in `strategy-seeds/cards/<slug>_card.md`

## Boundary

- G0 APPROVED does not mean the strategy will PASS P2 — pipeline gates filter that.
- CEO is interim G0 reviewer until Quality-Business (Wave 2) is hired.
- R1 and R2 are hard blocks. R3/R4 may be waived by Board Advisor confirmation only.
- Do NOT allocate `ea_id` during G0 — that happens at CTO build-task creation.

## References

- `processes/qb_reputable_source_criteria.md` — R1-R4 definitions (BINDING)
- `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md` § G0 — gate spec
- `strategy-seeds/cards/_TEMPLATE.md` — card YAML schema
- `strategy-seeds/strategy_type_flags.md` — controlled vocabulary
