---
name: qm-strategy-card-extraction
description: Use when Research is extracting strategies from a CEO-approved source (book, paper, blog, video) into V5 Strategy Cards. Don't use without an approved source — Research never works on unapproved input. Don't use to evaluate or score a card; that's CEO + Quality-Business review.
owner: Research Agent
reviewer: CEO + Quality-Business
last-updated: 2026-04-27
basis: paperclip-prompts/research.md (V5 BASIS) + strategy-seeds/cards/_TEMPLATE.md
---

# qm-strategy-card-extraction

Procedure for converting an approved research source into one or more V5 Strategy Cards. Mirrors the canonical research workflow: depth-first, exhaustive, one source at a time, no breadth fan-out.

## When to use

- CEO has approved a specific bounded source (book / paper / blog / video / forum thread)
- A new card needs to be created from a section of an already-approved source
- You are filling out the new V5 fields per QUA-236 (`source_citations[]`, `strategy_type_flags[]`, `framework_alignment`)

## When NOT to use

- No CEO-approved source — Research must propose first; no work without approval
- You are reviewing or scoring a card (that is CEO + Quality-Business work, not Research)
- You are mining a V4 SM_XXX EA's source code for re-implementation — that is Development territory, not Research

## Core rule (non-negotiable)

**Complete one source fully before touching the next.** V1 Research went breadth-first across 81+ "edges" with fuzzy attribution; V5 replaces that. Read depth-first, extract every distinct strategy from THIS source, then move on.

## Workflow

### 1. Confirm approval

Before reading anything: confirm the source has CEO approval (Paperclip issue + comment trail). If approval is implicit / verbal, post a `request_confirmation` interaction on the parent issue and wait.

### 2. Read the entire source

- Books: end-to-end, capture page numbers
- Papers: full read including appendices
- Blogs: read the full archive of the cited section, not just one post
- Videos: timestamp key claims as `HH:MM:SS-HH:MM:SS`

### 3. Identify each distinct strategy

A "distinct strategy" = its own entry rule + exit rule + market-inefficiency thesis. Two timeframes of the same rule = one strategy with timeframes listed. A rule with two filter variants = one strategy with both variants.

If a single named system in the source is actually two strategies in a trench coat (e.g. "long mode" + "short mode" with different entry mechanisms), split into two cards.

### 4. Allocate slug + strategy_id

- `slug`: lowercase kebab-case ≤ 16 chars (e.g. `breakout-atr`, `gotobi`). Allocated at extraction time.
- `strategy_id`: `SRC{source_id}_S{n}` — `n` is sequential per source (S01, S02, …)
- **Filename pattern:** `strategy-seeds/cards/<slug>_card.md`
- `ea_id` is **not** allocated here — that is CEO + CTO at APPROVED stage. Leave `ea_id: TBD` in the card header.

### 5. Fill the V5 template

Copy `strategy-seeds/cards/_TEMPLATE.md` to the new file. Do **not** delete unfilled fields — leave them as `TBD` so reviewers can see what is missing. Required header fields:

```yaml
strategy_id: SRC{source_id}_S{n}
ea_id: TBD
slug: <kebab-case>
status: DRAFT
created: YYYY-MM-DD
created_by: Research
last_updated: YYYY-MM-DD
strategy_type_flags: [<from controlled vocab>]
```

### 6. New V5 fields (per QUA-236)

| Field | Rule |
|---|---|
| `source_citations[]` | Multi. List every source cited in the strategy. Each entry has `type`, `citation`, `location`, `quality_tier` (A/B/C), `role` (`primary` or `supplement`). At least one entry must be `role: primary`. |
| `strategy_type_flags[]` | Multi. Pick from the controlled vocabulary in `strategy-seeds/strategy_type_flags.md`. Expect 3-6 flags per card; <2 = under-specified, >8 = probably two strategies. |
| `framework_alignment` | Map the strategy to the V5 4-module pattern (No-Trade / Entry / Management / Close). Note where strategy logic lives in each module. |

### 7. Fill body sections

Per the template, with verbatim author claims (always quoted):

- **Concept:** 2-3 sentences plain English market-inefficiency thesis
- **Markets & Timeframes:** what the source recommends
- **Entry Rules:** pseudocode, one bullet per condition, indicator names exact-as-source
- **Exit Rules:** pseudocode
- **Filters:** pseudocode
- **Parameters to test:** list with source's defaults
- **Author claims:** verbatim quotes with quote marks ("…", page/timestamp)
- **Initial risk profile:** what the source says about risk; if silent, write `Source silent — defer to V5 default RISK_FIXED $1k backtest, RISK_PERCENT 0.25 live`

### 8. Sanity-check before submit

- All `TBD` fields are intentional (not forgotten)
- `source_citations[]` has at least one `role: primary`
- `strategy_type_flags[]` has 3-6 entries
- ML-based strategies are **not allowed in V5** (per V5 framework). If the source uses ML for entries/exits/sizing, mark `status: REJECTED_ML_FORBIDDEN` and stop — Research may still log the strategy for V6 reconsideration but does NOT submit for build.

### 9. Submit for review

Submit cards as a batch from one source. CEO + Quality-Business review together (not separately). Reviewer verdicts:

- `APPROVE` → status moves to APPROVED, ea_id allocated by CEO + CTO
- `REJECT` → status REJECTED with reason
- `REQUEST_CLARIFICATION` → cards return to Research with comments

### 10. Wait for build

After submit, **wait**. Do not start the next source until all cards from this source have terminal verdicts (APPROVED / REJECTED). This is the depth-first discipline.

## Boundary

- This skill does **not** decide what gets built. CEO + Quality-Business review decides.
- This skill does **not** allocate `ea_id`. That is CEO + CTO at APPROVED stage.
- This skill does **not** modify `framework/` or write any MQL5 — Research outputs are markdown cards only.

## References

- `paperclip-prompts/research.md` — V5 BASIS Research Agent system prompt
- `strategy-seeds/cards/_TEMPLATE.md` — canonical card template
- `strategy-seeds/strategy_type_flags.md` — controlled vocabulary for `strategy_type_flags[]`
- `framework/V5_FRAMEWORK_DESIGN.md` § "Strategy Allowability" — what's allowed in V5 vs. forbidden (ML)
- `processes/13-strategy-research.md` — process-level wrapper for this skill
- `decisions/2026-04-26_v5_restart_clean_slate.md` — depth-first restart rationale
