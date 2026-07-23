---
title: Strategy Research Workflow (source → strategy → pipeline)
owner: OWNER
last-updated: 2026-07-22
authority: OWNER
---

# 13 — Strategy Research Workflow

This process turns an OWNER-authorized research source into falsifiable Strategy
Cards and moves those cards into the deterministic EA pipeline. Repository and
runtime artifacts are the source of truth; worker personas and reviewer names
are not gates.

## Authority and gate contract

There is one human approval authority: **OWNER**.

| Gate | Decider | Required evidence | What it authorizes |
|---|---|---|---|
| Source authorization | OWNER | Identified, accessible source | Extraction from that source |
| G0 | OWNER | R1-R4 review recorded on the card | Build, instrumentation, debugging, compilation, T1-T5 deployment, and non-live tests |
| Build | Deterministic checks | `.mq5`, `.ex5`, registry, setfiles, compile PASS, matching hashes | Entry into phase tests |
| P2-P10 | Deterministic phase rules | Version-bound reports and numerical thresholds | Advance to the next prescribed phase |
| T6/live promotion | OWNER | All required phase PASS evidence, execution contract, signed deploy manifest | The exact approved deployment only |

`g0_status: APPROVED` is the canonical G0 field. Once OWNER sets it, a separate
descriptive lifecycle field such as `status: DRAFT` does not block implementation
or non-live testing. Such disagreement is metadata debt to correct, not a reason
to invent an additional approval gate.

G0 means *approved for falsification*. It is not evidence that a strategy is
profitable, robust, portfolio-worthy, or live-safe. A successful compile or a
non-zero smoke test also does not imply promotion.

## Trigger

- OWNER authorizes one source from the source queue or supplies a source directly.
- A previously extracted source is reopened because cited material was missed.

No extraction starts from an unapproved source.

## Responsibilities

| Activity | Responsible worker | Binding output |
|---|---|---|
| Select/authorize source | OWNER | Source state and citation |
| Extract mechanical strategies | Research worker | Source notes and draft cards |
| Review R1-R4 and decide G0 | OWNER, with optional reviewer analysis | `g0_status` plus reasons/evidence |
| Allocate EA ID | Deterministic registry procedure | Unique registry row |
| Implement and debug | Development worker | Card-conformant source and diagnostics |
| Compile/build validation | Build tooling | Versioned binary and build evidence |
| Run phase tests | Pipeline tooling | Immutable, version-bound reports |
| Audit evidence | Any assigned reviewer | Findings only; no independent authority |
| Promote to T6/live | OWNER | Signed manifest bound to exact artifacts |

Claude, Codex, or any later worker may perform a responsibility when dispatched,
but changing the worker does not change gate semantics.

## Sequential source discipline

- Exactly one source lane is active at a time.
- A source produces at most two candidate cards before the controller advances,
  unless OWNER explicitly expands the batch.
- Work one strategy through the feedback loop before opening unnecessary parallel
  work from the same source.
- Missing source text blocks extraction and names OWNER as the unblock authority.

The controller records source/card/task state in the strategy-farm database and
artifacts described by
[OPTION_A_STRATEGY_FARM_RUNBOOK.md](../docs/ops/OPTION_A_STRATEGY_FARM_RUNBOOK.md).

## Strategy Card discipline

Use one Markdown card per strategy in the active strategy-farm card directories.
Every card must contain:

- source identity and precise page, section, or timestamp citations;
- mechanical entry, exit, sizing, session, and invalidation rules;
- `strategy_type_flags` from the controlled vocabulary;
- framework hook mapping and applicable V5 Hard Rules;
- explicit assumptions and known evidence gaps;
- `g0_status` and the recorded OWNER decision.

Do not present author claims, expected profit factor, expected drawdown, or
estimated trade density as backtest results. Only a report bound to the tested
source/binary hash, setfile hash, symbol, timeframe, data range, model, and cost
assumptions is test evidence.

## Lifecycle

```text
authorized_source
  -> extraction
  -> card_draft
  -> OWNER_R1-R4_review
  -> g0_status: APPROVED | REJECTED | CHANGES_REQUIRED
  -> build_and_debug
  -> deterministic_build_gate
  -> P2..P10
  -> killed | portfolio_candidate
  -> OWNER_promotion_decision
```

### Step details

1. **Authorize source.** Record source identity, location, and OWNER authorization.
2. **Extract.** Produce source notes and one card per distinct mechanical strategy.
3. **Decide G0.** OWNER records APPROVED, REJECTED, or CHANGES_REQUIRED from R1-R4.
4. **Build/debug.** On `g0_status: APPROVED`, allocate the EA ID, implement the
   card, compile, instrument rejects when needed, and prove that entry hooks can
   fire on real test data. Zero trades is a diagnostic outcome, not an automatic
   strategy rejection.
5. **Bind evidence.** Every result records exact source/binary/setfile hashes and
   the actual test interval. Results from an older binary cannot validate a new
   build.
6. **Run phase gates.** Apply the numerical phase specifications without reviewer
   discretion. Infrastructure failures are rerun; strategy failures are retained
   as negative evidence.
7. **Reach verdict.** A card is killed with its evidence or becomes a portfolio
   candidate. Both are valid research outcomes.
8. **Promote separately.** Only OWNER may approve T6/live, using a complete
   execution contract and artifact-bound signed manifest. No upstream approval
   silently carries into this decision.

## Lineage and enhancements

- A new insight from a different source is a new strategy and new card.
- A pipeline-derived improvement to the same source strategy is a new version of
  that strategy and reruns every required phase from the beginning.
- The lineage decision depends on where the insight came from, not superficial
  similarity of the EA code.

## Hard rules

- No build from a card whose `g0_status` is not `APPROVED`.
- Do not demand obsolete role signatures after OWNER G0 approval.
- No PASS/FAIL claim without exact version-bound evidence.
- No result-year label that differs from the actual tester interval.
- No T6/live action from G0, compile PASS, or smoke-test success alone.
- No Machine Learning in V5 EAs.
- No manual-discretionary entry or exit rule.
- Preserve negative and zero-trade results; do not hide failed candidates.

## References

- [Option A Strategy Farm Runbook](../docs/ops/OPTION_A_STRATEGY_FARM_RUNBOOK.md)
- [EA Life-Cycle](01-ea-lifecycle.md)
- [Enhancement loop](14-ea-enhancement-loop.md)
- [Pipeline phase specification](../docs/ops/PIPELINE_PHASE_SPEC.md)
- [Controlled vocabulary](../strategy-seeds/strategy_type_flags.md)
