---
source_id: SRC01
parent_issue: TBD                           # CEO opens new SRC01 issue per OWNER directive 2026-04-27 ~17:15 local
prior_parent_issue: QUA-191                  # superseded; QUA-191 was Ernest Chan book (now BLOCKED_PAYWALL)
status: active_extraction
authored-by: Research Agent
last-updated: 2026-04-27
---

# SRC01 — Adam Grimes blog archive (`adamhgrimes.com`)

This file replaces the prior SRC01 scaffolding (Ernest Chan, *Algorithmic Trading*) per OWNER directive on QUA-191 dated 2026-04-27 ~17:15 local time. The prior content is preserved at `strategy-seeds/sources/SRC01/archived/2026-04-27_chan_book_superseded_by_owner_directive.md` for audit.

## 1. Source identity

```yaml
source_citations:
  - type: article                            # multi-post blog archive; each strategy card cites its specific post URL + access date
    citation: "Grimes, Adam H. The Blog of Adam H Grimes. https://www.adamhgrimes.com/ — multi-post archive; per-post URL + publication date cited per strategy card."
    location: TBD                              # populated per-card with post URL + publication date + access date
    quality_tier: B                            # blog of credible practitioner (former hedge-fund trader; published author of "The Art and Science of Technical Analysis", Wiley 2012)
    role: primary
```

Why this source first, per OWNER directive 2026-04-27 ~17:15 local:

> "Adam Grimes blog archive (https://adamhgrimes.com/blog/ or equivalent) — entire archive is public. Many discrete trading-strategy posts. **Best first source for depth-first workflow validation.**"

The prior CEO recommendation (Chan book first, ratified on QUA-188) is superseded by OWNER's accessibility-first reorder. Chan's book is paywalled and Research will not bypass paywalls; Chan's blog at `epchan.blogspot.com` is deferred to P1 priority (after Grimes / Ehlers / Raschke complete).

## 2. Source-acquisition mode

Public web. Research locates content via `WebFetch` (and `firecrawl-search` / `firecrawl-scrape` when those skills are loaded into the active session). Every cited claim must include:

- specific post URL (slug-form, e.g. `https://www.adamhgrimes.com/trade-pullbacks/`)
- post publication date (from the post header)
- access date (the date Research fetched the content)

Raw evidence (full verbatim post body) is saved under `strategy-seeds/sources/SRC01/raw/<YYYY-MM-DD>_<slug>.md` so future readers can reconstruct the citation context independently of the live site.

## 3. Coverage strategy

Grimes's blog has been active since at least 2013 with hundreds of posts spanning trade methodology, market commentary, and trader psychology. Research filters for posts that contain mechanical-enough rules to map onto the V5 4-Module pattern. Posts that are pure psychology, pure commentary, or describe purely discretionary decision-making are flagged-and-skipped per § 4 below.

Initial pass priority (ordered by mechanical-rule density observed during 2026-04-27 first scrape):

1. `pullback-trade-works/` — 2014-09-10 — pullback fundamentals (qualitative; thesis only)
2. `trade-pullbacks/` — 2014-11-05 — **canonical pullback trade with explicit ATR stop + 1R first-target rule** ← **FIRST CARD**
3. `the-anti-a-trading-lesson-from-roku/` — 2019-09-23 — first countertrend pullback ("Anti") with explicit "break of N-day low" entry options
4. `trade-complex-consolidations/` — TBD scrape — consolidation breakouts
5. `nested-pullback/` — TBD scrape — pullback-within-pullback variant
6. `selective-intraday-trades-a-deep-dive-into-the-snap-pullback/` — TBD scrape — intraday pullback specialization
7. Subsequent posts via blog archive walk

## 4. v0 filter rules applied to this source

Inherited from QUA-191 acceptance criteria (still binding under the new SRC01) plus DL-029 strategy-research workflow:

- **Mechanical only** — discretionary judgment is OK as a context overlay (e.g., "wait for a strong trend") but every entry/exit/stop rule on the card must be reducible to a mechanical condition. If the card cannot specify entry/exit/stop in pseudocode, flag and skip the post.
- **No Machine Learning** — V5 hard rule `EA_ML_FORBIDDEN`. Grimes does not use ML; this filter is unlikely to bind.
- **`.DWX` suffix discipline** — Grimes references stocks (e.g., ROKU), futures (ES), and FX (EUR, GBP) by their conventional symbols, not Darwinex `.DWX` suffix forms. Cards from this source raise `dwx_suffix_discipline` in `hard_rules_at_risk`; per-card mapping happens at CTO sanity-check.
- **Magic-formula registry compatible** — `magic = ea_id*10000 + symbol_slot` (per CLAUDE.md). Grimes's posts use single-position-at-a-time discipline; pyramiding is mentioned as an option but is excluded from V5 cards by default per `one_position_per_magic_symbol` Hard Rule.
- **News-compliance compatible** — Grimes's posts are pattern-based, not news-event-based; the `news_pause_default` Hard Rule should not bind, but per-card validation still applies at G0 intake.
- **Friday Close compatibility** — Grimes is a swing trader; positions can hold across Friday 21:00 broker time. Cards must either survive forced flat at Friday close (timing the swing accordingly) OR document why a disable is requested.
- **Equities-on-stocks caveat** — Several Grimes examples use US equities (e.g., ROKU). The V5 framework targets Darwinex FX / indices / commodities feeds; equities-pattern strategies will be flagged and may be re-mapped to the closest Darwinex instrument only with explicit CEO + CTO approval before card draft.

A "flag and skip" post still gets a one-line entry in § 6 below documenting the post URL and the reason it was skipped, so the source completion report is auditable.

## 5. Expected strategy count

```yaml
expected_strategy_count: TBD                 # populated after first archive walk (estimate ~10-25 mechanical-enough posts in archive)
expected_post_count: 200+                    # rough estimate from blog archive index; majority will be psychology/commentary, not strategy
notes: |
  Grimes's blog density of mechanical-rule posts is far lower than a structured book. The
  first-pass scrape on 2026-04-27 found 3 of 10 search-result posts contained explicit
  mechanical entry/stop rules; the rest were qualitative/structural. Research will revise
  the expected count after the first 5 cards are drafted to anchor a yield rate.
```

## 6. Sub-issue queue

Populated as cards are drafted. Each row maps to one sub-issue under the (forthcoming) CEO-issued SRC01 parent issue per the issue-tree shape in `processes/13-strategy-research.md` § "Issue tree shape".

| Slot | Strategy slug | Card path | Sub-issue | Status | Source post |
|---|---|---|---|---|---|
| S01 | grimes-pullback | `strategy-seeds/cards/grimes-pullback_card.md` | TBD | DRAFT | https://www.adamhgrimes.com/trade-pullbacks/ (2014-11-05) |

Skipped posts (failed v0 filter):

| Source post URL | Reason for skip |
|---|---|
| https://www.adamhgrimes.com/pullback-trade-works/ | Thesis-only post; entry/stop/exit rules are explicitly qualitative and not mechanically reducible. Concept already covered by `grimes-pullback` card from `trade-pullbacks/`. |
| https://www.adamhgrimes.com/trading-a-powerful-trend-in-gold/ | 2025-10-09 post on a specific gold trade; entry rules are descriptive ("inside bars are your friends here", "a bar or two to get in") rather than mechanical. No stop or exit rules stated. |

## 7. Completion report contract

When all sub-issues under the (forthcoming) CEO SRC01 parent issue close, Research authors `strategy-seeds/sources/SRC01/completion_report.md` covering at minimum:

- Total posts surveyed, total strategies extracted, total skipped (with skip reasons aggregated)
- Per-strategy verdict (PASS / FAIL / RETIRED) with terminal pipeline phase
- Observations about source quality and yield-per-post rate
- Recommendation: continue mining Grimes archive deeper, or move to SRC02 (Ehlers / mesasoftware)?

## 8. Cross-references

- New parent issue: TBD (CEO to open NEW SRC01 per OWNER directive 2026-04-27 ~17:15)
- Prior parent issue: [QUA-191](/QUA/issues/QUA-191) — superseded; recast to "Chan blog (P1)" or closed-as-superseded per OWNER directive
- Workflow doc: `processes/13-strategy-research.md`
- Card template: `strategy-seeds/cards/_TEMPLATE.md`
- Strategy-type vocabulary: `strategy-seeds/strategy_type_flags.md`
- DL-029 (workflow ratification): `decisions/2026-04-27_strategy_research_workflow.md`
- Boundary doctrine: `paperclip-prompts/research.md` § ANTI-PATTERNS — "general trading knowledge" without citation is forbidden; this file's per-post URL + access date convention enforces it.
- OWNER directive (this pivot): comment `5c2daac6-bb76-47e0-ac35-bebea46c9bc4` on QUA-191, posted 2026-04-27T17:12:48Z
