# Research Methodology V2

> **V5 Source:** Notion `Research Methodology V2` (id `34947da5-8f4a-81d3-acf3-e1e0d6074d4a`)
> **Migrated to repo:** 2026-04-26

**This is the single most important process revision in V5.** V1's research agent ran parallel queries across multiple sources, producing wide-but-shallow output that was hard to audit, hard to reproduce, and easy to hallucinate. V2 replaces breadth-first with depth-first.

## The Rule

> **Complete one source fully before touching the next.**

## Source-Completion Workflow

### Step 1 — Source Selection (OWNER approves)

Research Agent proposes a specific, bounded source:

- A named book (title, author, edition, ISBN)
- A specific paper (title, authors, year, DOI if available)
- A specific blog/article (URL, author, date)
- A specific video or lecture series (URL, presenter)

OWNER (or CEO agent with delegated authority) approves the source before work begins. No research without approved source.

### Step 2 — Exhaustive Strategy Extraction

Read/consume the entire source. For every distinct strategy mentioned, create a Strategy Card per the template at `strategy-seeds/cards/_TEMPLATE.md`:

```yaml
strategy_id: SRC{source_id}_S{n}
source:
  type: book | paper | article | video
  citation: full citation
  location: page numbers / timestamp / section
name: human-readable strategy name
concept: 2-3 sentence summary
entry_rules: list as code-like pseudocode
exit_rules: list as code-like pseudocode
filters: optional conditions
timeframes: which TFs the source recommends
markets: forex / indices / commodities / stocks
parameters_to_test: list
author_claims: the source's own performance claims (verbatim, with quote marks)
initial_risk_profile: estimated risk from description
```

### Step 3 — Cards Reviewed by CEO + Quality-Business

All Strategy Cards from a source go to CEO agent + Quality-Business agent for review. They can:

- APPROVE for EA build
- REJECT (too vague, too similar to existing, data unavailable)
- REQUEST-CLARIFICATION (re-read specific section, provide more detail)

### Step 4 — EA Build — One at a Time

Approved strategies go to Development agent, **one at a time**. For each:

1. Dev writes MQ5 code from the Strategy Card using V5 framework (`framework/V5_FRAMEWORK_DESIGN.md`)
2. Pipeline-Operator runs initial smoke test (1 symbol, 1 year, Fixed Risk $1K — V5 backtest convention)
3. If smoke passes: full Baseline Sweep
4. Quality-Tech audits the code vs. the Strategy Card (did Dev faithfully implement the source?)
5. CEO reviews BL results: PASS/FAIL/REJECT
6. If PASS: strategy promoted to next pipeline phase per `docs/ops/PIPELINE_PHASE_SPEC.md`
7. **Only then** does Development start the next EA

### Step 5 — Source Completion Report

When all approved strategies from a source have been built and tested, Research Agent writes a **Source Completion Report**:

- How many strategies extracted
- How many approved by CEO
- How many PASSed baseline
- Key observations about the source's overall quality
- Recommendation: is this source worth deeper exploration, or move on?

This report is archived in Git under `strategy-seeds/sources/SRC{id}/source.md` and referenced in the YouTube episode covering that source.

### Step 6 — Then and Only Then, Next Source

Only after Step 5 is CEO allowed to approve a new source for Research Agent.

## Why This Matters

V1's research agent produced 81+ "edge types" across 46 research rounds, but attribution to specific sources was often fuzzy, re-tests were hard, and several "edges" turned out to be duplicates or near-duplicates that we discovered only when building EAs. V2's discipline means:

- Every EA traces to a specific source citation
- We can tell a YouTube audience exactly where a strategy came from
- Duplicates are caught at extraction time, not at build time
- Source quality is measurable (X% of strategies from source Y passed baseline)
- Legal/citation hygiene for potentially publishing strategy books later

## Anti-Patterns (Forbidden in V2)

- Pulling strategies from "general trading knowledge" without a source citation
- Opening 5 books and extracting partial strategies from each
- Skipping the Strategy Card step and going straight to code
- Building 3 EAs in parallel from one source (sequential only)
- Labeling a strategy with source "unknown" or "various"
- Re-ordering: Research must not decide which source to work on; CEO approves queue order

## Seed Source List (Proposed)

To be refined with OWNER. Candidate first-sources:

1. "Algorithmic Trading" by Ernest Chan (known, well-structured, good first source)
2. "New Trading Systems and Methods" by Perry Kaufman (encyclopedic — use selected chapters)
3. Adam Grimes' trading blog archive (blog post-by-post)
4. John Ehlers' signal-processing papers (narrow, technical)
5. Linda Raschke's educational content

Final ordering: OWNER's call. One at a time. No exceptions.
