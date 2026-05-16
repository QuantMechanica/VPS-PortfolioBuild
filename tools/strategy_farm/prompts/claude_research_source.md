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
- Reject or mark PENDING (per relaxed criteria 2026-05-15, see
  `C:/QM/repo/processes/qb_reputable_source_criteria.md`):
  - **No source link / unattributable** (R1 fail)
  - **Purely discretionary with NO rules at all** (R2 fail). Gaps in
    side-parameters are OK — Codex fills defaults.
  - **Fundamentally untestable on any DWX instrument even after porting**
    (R3 fail). Crypto / equity / options strategies that PORT to Forex,
    indices, or CFDs are valid — note the porting plan in the card.
    Special case: **SP500/SPX500/SPY/ES are permanently unavailable in the
    DWX feed (no tick data)**. If a card's edge specifically requires SPY
    intraday cash-session microstructure (e.g. opening-range breakouts
    tuned to NYSE microstructure), and no port to WS30 (Dow) or NDX
    (Nasdaq) preserves the edge → R3 REJECT at G0. If the concept ports
    cleanly to WS30/NDX → R3 PASS with port plan documented.
  - **ML / neural net / adaptive parameters / grid-without-bounded-worst-case**
    (R4 / HR14, binding)
- **Anonymous forum handles are OK** as long as you link the source URL.
  The strategy will pass or fail on its own data in P2-P7. R1 used to require
  author track record — that was dropped 2026-05-15.
- Preserve attribution: URL, author/handle (anon OK), post/article title, date
  if visible, and exact source location.

## Output policy — batch of up to 5 cards per session

OWNER 2026-05-15 mining policy: extract **up to 5** new draft cards per
research session. After the batch, decide whether the source has more
material (paused as `cards_ready`) or is exhausted (`done`).

## Required Output Files

### Source notes
`D:\QM\strategy_farm\artifacts\source_notes\{{source_id}}.md`

If the file already exists (this is a resumed-mining 2nd/3rd/Nth batch),
**append** a new section `## Batch N — <utc-iso>` rather than overwriting.
Each batch documents what you mined this session.

### Draft strategy cards (up to 5)
`D:\QM\strategy_farm\artifacts\cards_draft\QM5_<NNNN>_<slug>.md`

Use the Strategy Wiki `_TEMPLATE Strategy.md` format. **Mandatory frontmatter
fields for autonomous workflow:**

```yaml
---
ea_id: QM5_<NNNN>
slug: <descriptive-slug>
type: strategy
source_id: {{source_id}}                   # REQUIRED — for resume-mining trace
sources:
  - "[[sources/<source-slug>]]"            # human-readable wiki backlink
g0_status: PENDING                          # Step 3 G0 batch sets this
last_updated: <YYYY-MM-DD>
---
```

Allocate NEW EA IDs starting from the next free `QM5_<NNNN>` in
`C:/QM/repo/framework/registry/ea_id_registry.csv`. Do NOT collide.

## Final state decision (end of session)

After writing the batch (≤ 5 cards) and updating notes, decide:

- **5 cards AND source has more material** (forum has many more relevant
  threads, journal has many more papers, book has many more chapters, archive
  has many more PDFs not yet mined):
  ```
  farmctl set-source-status {{source_id}} cards_ready --notes-path "<notes path>"
  ```
  Source is **paused** — your 5 EAs flow through G0 → build → P2.
  When all 5 reach pipeline-end, Step 4 resume-mining flips back to active
  and you return to this source for the next batch.

- **<5 cards drafted OR source genuinely exhausted** (you searched thoroughly
  and don't see remaining high-value mechanical strategies):
  ```
  farmctl set-source-status {{source_id}} done --notes-path "<notes path>"
  ```
  Source is **permanently done**. Step 6 next wake claims the next pending.

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
- draft card paths (this batch — up to 5)
- rejected/skipped count (with one-line reason each)
- source final state: `cards_ready` (paused for pipeline) or `done` (exhausted)
- open questions, if any
