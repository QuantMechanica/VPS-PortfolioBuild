# SRC01 — Source Header

> **Status:** scaffolding only. No body claims extracted. Awaiting OWNER source-text drop per QUA-191.
> **Created:** 2026-04-27 by Research Agent (`7aef7a17`).
> **Authority:** CEO scaffolding authorization on QUA-191 (comment `fe3e23a5`, 2026-04-27), under DL-017 / QUA-188 broadened CEO autonomy.

## 1. Source identity

```yaml
source_id: SRC01
type: book
citation: "Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. 1st edition. Wiley Trading."
isbn_print: 978-1-118-46014-6
isbn_ebook: 978-1-118-67699-8
publisher_doi: 10.1002/9781118676998
publisher_url: https://www.wiley.com/en-us/Algorithmic+Trading%3A+Winning+Strategies+and+Their+Rationale-p-9781118460146
quality_tier: A
```

`quality_tier: A` rationale: peer-recognized author (Chan runs QTS Capital Management; published Wiley Finance series); the book is the canonical practitioner reference for mechanical mean-reversion / momentum strategies on equities, ETFs, forex, and futures.

## 2. Selection authority

- OWNER ratification of CEO default ordering — `QUA-188` (interaction `194a59ce` on `QUA-144`).
- Chan-first chosen because the book is clean and well-structured; validates the depth-first workflow before stress-testing on Kaufman or Grimes.

## 3. Source-text status

| Date | Event |
|---|---|
| 2026-04-27 | Research checked all standard locations (`C:\QM\repo`, `C:\QM`, `D:\QM`, `G:\My Drive\QuantMechanica\Ebook\`, `G:\My Drive\QuantMechanica - VPS Portfolio Build\`) — **no PDF/EPUB/MOBI of the book reachable**. Logged in QUA-191 comment `447efedf`. |
| 2026-04-27 | CEO approved BASIS-safe scaffolding work in QUA-191 comment `fe3e23a5`. Issue `blocked` until OWNER provides source text. |
| TBD | OWNER drops source text → Research re-opens issue and begins extraction. |

Expected drop path (any of these works):
- `G:\My Drive\QuantMechanica\Ebook\Chan_Ernest_Algorithmic_Trading_2013.pdf` (or `.epub`)
- Drive share link in a QUA-191 comment, fetched and cached at `seed_assets/sources/SRC01/Chan_Ernest_Algorithmic_Trading_2013.pdf`

## 4. Citation header — required fields per Strategy Card

Every Strategy Card extracted from this source MUST populate the following fields exactly as below in its `## 1. Source` block:

```yaml
type: book
citation: "Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. 1st edition. Wiley Trading."
location: "chapter <N> § <section title>, page <P>"   # both chapter+section AND page required
quality_tier: A
```

`location` examples (illustrative format, not real extractions):
- `"chapter 3 § Bollinger Bands, page 52"`
- `"chapter 4 § Intraday Mean Reversion: Buy-on-Gap Model, page 78-81"`
- `"chapter 7 § Opening Gap Strategy, page 132-135"`

If a strategy spans multiple sections, list the primary location and reference secondaries via `also: ["chapter X § ...", ...]` underneath `location`.

## 5. Verbatim-quote discipline

Per V5 BASIS rule and QUA-191 acceptance criteria:

- **Author Claims** section of every card MUST quote the book verbatim with quote marks and page number.
- No paraphrase of performance numbers. If Chan writes "the Sharpe ratio was 1.45 on this dataset", the card prints `"the Sharpe ratio was 1.45 on this dataset" (page N)` — not "Chan reports a Sharpe around 1.5".
- If the book gives no performance claim for a strategy, the `Author Claims` block lists `(none stated by author)` rather than fabricated estimates.

## 6. Chapter scope

See `chapter_index.md` in this folder for the verified chapter list (sourced from the publisher TOC, not from the book interior). Strategy Cards are produced one per distinct strategy, indexed back to chapter + section.

## 7. Output convention

When extraction begins:

- Each candidate card lands at `strategy-seeds/cards/SRC01_S<NN>_<slug>_card.md` per `_TEMPLATE.md`.
- Per-chapter progress comments go on QUA-191 (acceptance criterion: progress comment at least every full chapter).
- Source Completion Report at `strategy-seeds/sources/SRC01/completion_report.md` when all 8 chapters are processed (regardless of how many cards survive the v0 filter).
- Cards-skipped-by-v0-filter logged at `strategy-seeds/sources/SRC01/v0_filter_rejections.md` with reason for skip.
