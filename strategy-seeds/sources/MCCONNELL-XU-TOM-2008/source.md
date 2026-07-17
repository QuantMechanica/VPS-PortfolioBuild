---
source_id: MCCONNELL-XU-TOM-2008
source_id_status: OWNER_APPROVED_NAMED_SOURCE
source_type: paper
title: Equity Returns at the Turn of the Month
authors: John J. McConnell and Wei Xu
publication: Financial Analysts Journal 64(2), 2008, 49-64
doi: https://doi.org/10.2469/faj.v64.n2.11
full_text_url: https://business.purdue.edu/faculty/mcconnell/publications/Equity-Returns-at-the-Turn-of-the-Month.pdf
ssrn_journal_record: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1135217
ssrn_working_paper_record: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=917884
status: EXTRACTION_COMPLETE_CARD_REJECTED_DUPLICATE
created: 2026-07-17
created_by: Research
last_updated: 2026-07-17
approval_basis: "Explicit OWNER-approved McConnell and Xu (2008) extraction delegated in this workspace on 2026-07-17."
full_text_status: REPRODUCIBLE_PUBLIC_AUTHOR_HOSTED_JOURNAL_PDF_READ_END_TO_END
cards_extracted:
  - tom-index-long
---

# McConnell and Xu (2008) — Equity Returns at the Turn of the Month

## Source approval and scope

The OWNER explicitly approved this bounded paper for extraction on 2026-07-17. This record covers the peer-reviewed 2008 *Financial Analysts Journal* article only. It does not treat later summaries, trading blogs, or existing QM cards as evidence for claims made by McConnell and Xu.

## Source identity and reproducibility

- Canonical citation: McConnell, John J., and Wei Xu. 2008. "Equity Returns at the Turn of the Month." *Financial Analysts Journal* 64(2): 49-64. DOI: https://doi.org/10.2469/faj.v64.n2.11.
- Full article PDF: https://business.purdue.edu/faculty/mcconnell/publications/Equity-Returns-at-the-Turn-of-the-Month.pdf.
- The PDF is hosted under John McConnell's Purdue faculty publication path. It contains 17 physical PDF pages: one JSTOR/CFA cover page followed by the complete 16-page journal article, journal pages 49-64.
- Research read the PDF end-to-end on 2026-07-17, including all figures, Tables 1-5, notes, conclusion, and references. The journal article has no appendix.
- The journal-version SSRN metadata record is `abstract_id=1135217`. The earlier 50-page July 2006 working-paper record is `abstract_id=917884`.
- Legacy QM material cites `SSRN 925589` and sometimes adds the subtitle "Trading Strategies and Implications for Investors and Managers." Neither identifier nor subtitle was reproduced in the primary records inspected here and must not be used as the canonical 2008 citation.

The 2008 source itself is therefore fully reproducible and creates no full-text blocker. The separate 2006 working-paper delivery redirected to its SSRN abstract during this audit; it was not used and is not represented as read.

## Full-read page map

| Journal pages | Content inspected | Extraction relevance |
|---|---|---|
| 49-50 | Definition, prior studies, data, and daily-position convention | Defines Day -1 as the last trading day and Days +1 through +3 as the first three trading days of the new month. |
| 51-52 | U.S. value- and equal-weighted results, subperiods, outlier and GARCH checks | Establishes the return concentration and statistical robustness; does not define a broker execution rule. |
| 53-55 | Size, price, year-end, and quarter-end tests | Shows the effect is not only a small-stock, low-price, January, or quarter-end result. |
| 56-59 | Volatility and 34 non-U.S. equity markets | Reports no higher turn-of-month volatility and broad international evidence. |
| 60-61 | Bills, bonds, and payday-hypothesis tests | Bond evidence is mixed; trading volume and mutual-fund flows do not support the proposed payday explanation. |
| 62-63 | Conclusion, notes, and limitations | Restates the empirical result and leaves its cause unresolved. |
| 64 | References | Checked in full; no appendix follows. |

## What the paper establishes

- The empirical turn-of-month interval is Day -1 through Day +3: the last trading day of the old month and the first three trading days of the new month.
- The paper measures daily index returns. Economically, the complete four-return window begins before the Day -1 close-to-close return and ends at the Day +3 close.
- U.S. results use CRSP value-weighted and equal-weighted market indices. The paper also analyzes size and price portfolios and Datastream country indices.
- The effect appears in both early and later subperiods, survives an outlier deletion check, and is not explained by higher return volatility.
- The international exercise finds a positive turn-of-month-minus-other-days difference in all but one of the 34 non-U.S. markets and a meaningful effect in most of them.

## What the paper does not establish

- It is an empirical return study, not a complete trading-system specification. It gives no order type, tradable instrument, stop, take-profit, sizing rule, retry behavior, commission model, spread model, or live risk limit.
- It does not test `NDX.DWX` or the Nasdaq-100 specifically. `NDX.DWX` is an OWNER-requested QM proxy for the broad equity-index effect, not a source-named instrument.
- It does not establish pension, 401(k), payroll-deferral, or month-end buying pressure as the cause. Its NYSE-volume and TrimTabs mutual-fund-flow tests provide no support for the payday hypothesis, and the authors leave the cause unresolved.
- It does not authorize SMA, volatility, January, quarter-end, or momentum filters. Those are separate variants or overlays.
- It contains no post-2005 evidence and no FTMO/Darwinex CFD transaction-cost evidence.

## Distinct strategies extracted

One strategy candidate was identified:

| Slot | Slug | Card | State |
|---|---|---|---|
| S01 | `tom-index-long` | `strategy-seeds/cards/tom-index-long_card.md` | REJECTED_DUPLICATE; terminal verdict; `ea_id: TBD` |

Country, size, price, bond, and year/quarter partitions are robustness analyses, not separate entry/exit systems. No additional cards were extracted from them.

## Source window versus conservative MT5 translation

The paper's full empirical window includes the Day -1 daily return. A live EA cannot infer every exchange holiday from past D1 bars alone before that final old-month session begins. The rejected normalization card documents a conservative no-lookahead translation:

1. Enter long on the first executable tick of the first actual `NDX.DWX` D1 session whose month differs from the last completed D1 bar.
2. Exit on the first executable tick after the third actual D1 session of that new month has closed.
3. Keep the V5 Friday-close safeguard enabled; if it flattens earlier, mark the monthly cycle complete and do not re-enter.

This translation intentionally captures only the new-month portion of the source interval and may miss the prior-close-to-first-tick gap. It must never be described as an exact replication of all four source returns. A source-faithful Day -1-open version would require an independently reviewed, versioned exchange-calendar contract and is outside this rejected card.

## Duplicate and lineage audit

The repository helper reported no exact string duplicate for slug `tom-index-long` and strategy ID `MCCONNELL-XU-TOM-2008_S01`, but its scan does not cover the farm approved-card store and does not compare semantic mechanics. Manual adjudication overrides that narrow clean result:

- `QM5_1049_mcconnell-turn-of-month` is an exact same-source, same-direction, same-index-family predecessor and already targets `NDX.DWX`.
- `QM5_20004_turn-of-month-index-long` is an exact same-paper and near-identical rule duplicate under a different source label.
- `QM5_12847_turn-of-month-sp500`, `QM5_9931_bandy-turn-of-month-overlay-index`, `QM5_10023_rw-eom-flow`, and `QM5_10888_risk-tom-index` are parameter/filter variants in the same equity-index turn-of-month family.
- Registry-only `QM5_12904_uk100-tom-pension` is another likely family member, but no canonical card was found during this audit.
- Van Hemert energy turn-of-month momentum cards are not duplicates: they use commodity symbols and a momentum-direction condition rather than unconditional long equity-index exposure.

Research verdict: this extraction is a source-normalization and conservative-rule proposal, not evidence of a new edge family. OWNER-delegated CEO + Quality-Business confirmed the exact same-source/semantic duplicate and issued terminal `REJECTED_DUPLICATE` on 2026-07-17. No new EA ID may be allocated and no prior pipeline evidence transfers automatically to the changed execution rule.

## Open review blockers

- Exact-duplicate/lineage adjudication is terminally resolved as rejection of a new identity.
- `framework/registry/dwx_symbol_matrix.csv` records `NDX.DWX` with `FAIL_tail_mid_bars` dated 2026-04-27, although the history-range registry lists D1 coverage for 2021-2026. Data validation must be resolved before any build or baseline claim.
- The available NDX history is far shorter than the paper's 1926-2005 U.S. sample and permits only a modern proxy falsification, not replication of the published sample.
- Friday-close and news-pause defaults can truncate or skip a source window and require explicit reviewer acceptance as conservative FTMO adaptations.

## Completion state

The approved 2008 source has been read completely and one normalization card was extracted and terminally rejected as a duplicate. Research made no EA-ID, registry, magic-number, framework, build, pipeline, retirement, or deployment change.
