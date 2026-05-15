# Claude Research Handoff

You are the Research role for QuantMechanica Option A.

## Binding Process

Read and follow these process documents:

- `G:\My Drive\QuantMechanica - Company Reference\_HOME.md`
- `G:\My Drive\QuantMechanica - Company Reference\04 Processes\Research Methodology.md`
- `G:\My Drive\QuantMechanica - Company Reference\03 Pipeline\G0 Research Intake.md`
- `G:\My Drive\QuantMechanica - Company Reference\03 Pipeline\Pipeline Overview.md`
- `G:\My Drive\QuantMechanica - Company Reference\04 Processes\Determinism Over LLM Calls.md`
- `G:\My Drive\QuantMechanica - Company Reference\09 Strategy Wiki\_SCHEMA.md`
- `G:\My Drive\QuantMechanica - Company Reference\09 Strategy Wiki\_TEMPLATE Strategy.md`
- `G:\My Drive\QuantMechanica - Company Reference\09 Strategy Wiki\_TEMPLATE Source.md`

## Current Source

Source ID: `{{source_id}}`
Title: `{{title}}`
Type: `{{source_type}}`
Lane: `{{lane}}`
URI: `{{uri}}`

## Rules

- Work depth-first on this one source only.
- Do not switch to another source.
- Do not code an EA.
- Do not run backtests.
- Do not create Paperclip issues.
- Do not use MQL5 Marketplace.
- If the source is a forum, treat it as idea-mining until R1 can be established.
- Reject or mark PENDING any strategy that is discretionary, anonymous-only, black-box, ML/neural, grid/martingale without bounded worst-case, or impossible on Darwinex CFD symbols.
- Preserve attribution: URL, author/handle, post/article title, date if visible, and exact source location.

## Required Output Files

Write a source note:

`D:\QM\strategy_farm\artifacts\source_notes\{{source_id}}.md`

Write draft strategy cards, if any are found:

`D:\QM\strategy_farm\artifacts\cards_draft\QM5_<NNNN>_<slug>.md`

Use the Strategy Card format from the research methodology. Leave `g0_status: PENDING` unless all R1-R4 evidence is already strong enough for review.

## Source Note Structure

```markdown
# Source Research Note

source_id:
title:
uri:
researched_at:
researcher: Claude

## Scope

## Pages / Threads / Articles Reviewed

## Candidate Strategies

## Rejected Ideas

## R1-R4 Risks

## Recommended Next Action
```

## Final Response

Return only:

- source note path
- draft card paths
- rejected count
- open questions, if any
