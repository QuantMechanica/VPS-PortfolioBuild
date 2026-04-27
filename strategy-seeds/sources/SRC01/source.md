---
source_id: SRC01
tier: T1                                      # curated local PDF (OWNER-supplied)
parent_issue: QUA-191
status: active_extraction
authored-by: Research Agent
last-updated: 2026-04-27
budget_tracking:
  heartbeats_used: 3                          # scaffolding + App B card + App C card
  cards_drafted: 2                            # davey-eu-night (App B), davey-eu-day (App C)
  cards_passed_g0: 0
  cards_killed_pre_p1: 0
---

# SRC01 — Kevin J. Davey, *Building Winning Algorithmic Trading Systems*

QUA-191 was recast 2026-04-27 evening per CEO comment [`dd0f77f5`](/QUA/issues/QUA-191#comment-dd0f77f5-7b98-4331-af7b-c6e013aa3d97) (authority: [QUA-188 waiver v3](/QUA/issues/QUA-188#comment-5caf4b97-a309-442c-ad4f-de84608eb06f)) — `SOURCE_QUEUE.md` interaction `e6c0502b` accepted by Board Advisor on OWNER's behalf; the SRC01 slot now points at Davey (Tier A, proposed_order #1). Earlier Chan-book and Adam-Grimes-blog scaffolds for this slot are archived under `strategy-seeds/sources/_archived/` and `strategy-seeds/sources/_t2_pending/grimes-blog/` respectively (Grimes is now T2).

## 1. Source identity

```yaml
source_citations:
  - type: book
    citation: "Davey, Kevin J. (2014). Building Algorithmic Trading Systems: A Trader's Journey from Data Mining to Monte Carlo Simulation to Live Trading. Wiley Trading. ISBN 978-1-118-77898-2 (pbk.); ISBN 978-1-118-77891-3 (PDF). Hoboken, NJ: John Wiley & Sons."
    location: TBD                              # populated per-card with chapter/section/page on extraction
    quality_tier: A                            # peer-known practitioner; 3-time World Cup of Futures Trading® finalist (148%, 107%, 112% returns); aerospace-engineer-by-training MBA; 20+ years independent trading
    role: primary
```

Note on title: cover/spine reads *Building Winning Algorithmic Trading Systems*; the Library-of-Congress / Wiley catalog title is *Building Algorithmic Trading Systems* (the "Winning" is a marketing flourish on the cover, not in the cataloged title). Citations use the cataloged form to satisfy the BASIS-rule precision requirement; conversational references use either.

## 2. Source-text status

```yaml
source_text_path: "G:\\My Drive\\QuantMechanica\\Ebook\\PDF resources\\Building Winning Algorithmic Tr - Kevin J. Davey.pdf"
file_size_bytes: 6309632                       # 6.3 MB
file_modified: 2025-04-28                      # per `ls -la` mtime
text_extraction_method: poppler `pdftotext -layout` (verified working on TOC pages 1-14)
status: on_disk
```

## 3. Why Davey first (T1 #1)

Per `strategy-seeds/sources/SOURCE_QUEUE.md` § "Why this ordering" (commit [`950ff69`](https://github.com/QuantMechanica/VPS-PortfolioBuild/commit/950ff69)) and CEO procedural endorsement comment [`d6eb480f`](/QUA/issues/QUA-191#comment-d6eb480f-18cc-4ddb-bd4c-df5b1b8aca44):

> Davey — practitioner-focused, mechanical strategies, well-structured workbook. Best validator of the depth-first workflow without ML / HFT complications. Davey explicitly walks the reader through strategy generation, optimization, and Monte-Carlo robustness — directly aligned with V5's pipeline (P0 → P5).

Davey is also strategically valuable as SRC01 because **the book IS the V5 pipeline**. Parts II–VI describe a methodology nearly identical to QM's P-stage flow:

- Part II "Your Trading System" → V5 G0 framing
- Part III "Developing a Strategy" Chs 11–17 → V5 P1–P3 (data, limited testing, walk-forward, Monte Carlo, position sizing, documentation)
- Part IV "Creating a System" → V5 P3.5 / P4
- Part V "Considerations Before Going Live" → V5 P5–P9b
- Part VI "Monitoring a Live Strategy" → V5 P10 + Live Promotion

Cards extracted from this source therefore double as **methodology-validation evidence**: when Davey's procedure aligns with V5, that's a positive signal; when V5 is more conservative, that's deliberate; when Davey is more conservative, that's a candidate enhancement to V5.

## 4. Expected strategy count

Davey is **methodology-heavy, strategy-light** by design. The book teaches the *process* of strategy development; the named strategies are illustrative rather than a strategy library. Per OWNER Rule 1 (CEO comment [`85b9ec8e`](/QUA/issues/QUA-191#comment-85b9ec8e-8461-4579-8110-2fb2621b0470)), Research extracts EVERY distinct mechanical strategy regardless of perceived quality.

```yaml
expected_strategy_count: 3-4                  # revised post-Rule-1: App B + App C + App A Monkey + possible Ch 8/10/12 examples to-be-discovered
expected_chapter_count: 25                    # plus 3 appendices
strategy_locations:                            # validated at extraction
  - "Appendix A (Monkey Trading Example, p. 247) — RANDOM-ENTRY mechanical strategy; Davey's null-hypothesis baseline. Per Rule 1, gets a card; pipeline G0/P2 decide pass/fail. Card pending next heartbeat."
  - "Appendix B (Euro Night Strategy, p. 255) — DRAFT (S01)"
  - "Appendix C (Euro Day Strategy, p. 259) — DRAFT (S02)"
  - "Chapter 18 (Goals, Initial and Walk-Forward Testing) — pedagogical walk-through of the App B + App C strategy pair; NOT a separate strategy (S03 collapsed in earlier reading)."
  - "Chapter 10 (Trading Idea, pp. 79-83) and Chapter 8 (Designing and Developing Systems, p. 61), Ch 12 (Limited Testing, p. 103) — to be swept in Pass 2 for any example strategies described in main text that I may have skipped."
notes: |
  Most of the book's value to V5 is methodological (Parts II-VI). The strategy harvest is small but
  high-quality: each appendix strategy is given in EasyLanguage source code with all parameters,
  entry/exit rules, and Davey's own backtest commentary.
  
  Rule 1 binds: even App A Monkey Trading gets a card. Even if Ch 10's "Trading Idea" turns up
  half-formed mechanical sketches, those get cards. Pipeline G0 mechanical-only check is the gate,
  not Research's pre-judgment.
```

## 5. v0 filter rules applied to this source

Inherited from QUA-191 acceptance criteria + DL-029 strategy-research workflow + the v5_flags conventions in `SOURCE_QUEUE.md`:

- **Mechanical only** — Davey publishes EasyLanguage source code in the appendices; mechanical-discipline binding is straightforward to verify.
- **No Machine Learning** — Davey is non-ML throughout. This filter does not bind.
- **`.DWX` suffix discipline** — Davey's strategies cite EUR (Euro futures, ticker `@EU` or `EUR/USD` cash). V5 deployment maps to `EURUSD.DWX`. Cards from this source raise `dwx_suffix_discipline` in `hard_rules_at_risk`; per-card mapping happens at CTO sanity-check.
- **Magic-formula registry compatible** — Davey uses single-position-at-a-time discipline in his appendix strategies; `one_position_per_magic_symbol` Hard Rule should not bind.
- **News-compliance compatible** — Davey's appendix strategies are pattern/time-of-day-based, not news-event-based; `news_pause_default` Hard Rule should not bind.
- **Friday Close compatibility** — Euro Night and Euro Day are short-duration (overnight or intraday) strategies; both naturally exit before Friday 21:00 broker time. `friday_close` Hard Rule should not bind for the Davey appendix strategies.
- **Futures-on-currency caveat** — Davey trades Euro **futures** (CME `@EU`) on TradeStation. V5 framework targets Darwinex spot FX (`EURUSD.DWX`). Per-card mapping decisions documented at CTO sanity-check; futures-vs-spot tick-size and contract-size differences flagged in each card's `hard_rules_at_risk`.

## 6. Sub-issue queue

Populated as cards are drafted. CEO opens sub-issues under QUA-191 per the issue-tree shape in `processes/13-strategy-research.md` § "Issue tree shape" and CEO's commitment list ([comment `dd0f77f5`](/QUA/issues/QUA-191#comment-dd0f77f5-7b98-4331-af7b-c6e013aa3d97)).

| Slot | Strategy slug | Card path | Sub-issue | Status | Source location |
|---|---|---|---|---|---|
| S01 | `davey-eu-night` | `strategy-seeds/cards/davey-eu-night_card.md` | TBD | DRAFT (2026-04-27) | App B pp. 255-258 + Ch 15/18/19 cross-refs |
| S02 | `davey-eu-day` | `strategy-seeds/cards/davey-eu-day_card.md` | TBD | DRAFT (2026-04-27) | App C pp. 259-261 + Ch 15/18/19 + Ch 7 cross-refs |
| S03 | `davey-monkey-baseline` | `strategy-seeds/cards/davey-monkey-baseline_card.md` | TBD | pending — extraction queued for next heartbeat | App A pp. 247-253 (random-entry mechanical strategy; Davey's null-hypothesis baseline). **Rule 1 (CEO comment 85b9ec8e) reverses my earlier "skip-as-card" call: every distinct mechanical strategy gets a card; pipeline gates filter, Research does not pre-judge.** |
| S04 | TBD | TBD | TBD | pending — Ch 8/Ch 10 sweep for any example strategies described in main text that I may have skipped over during the App-first extraction pass | Ch 8 "Designing and Developing Systems", Ch 10 "Trading Idea", Ch 12 "Limited Testing" examples; budgeted for Pass 2 |

Skipped sources (failed V5 HARD RULE — not Research-prior-belief; Rule 1 binds):

| Source location | Reason for skip |
|---|---|
| (none yet) | — |

**Rule 1 application (CEO comment [`85b9ec8e`](/QUA/issues/QUA-191#comment-85b9ec8e-8461-4579-8110-2fb2621b0470), 2026-04-27 ~22:08 local):** Research extracts every distinct mechanical strategy that passes V5 hard rules. No prioritization, no quality-pre-judgment, no "skip the weaker ones." Pipeline gates G0 → P10 do the filtering. The "Skipped sources" table only records strategies that fail a V5 **HARD RULE** (no ML, no discretionary judgment, no martingale without 1%-cap, no scalping without P5b acknowledgement, no paywall bypass) — NOT strategies that "feel weak" or "feel like methodology demos."

**Reversal of earlier call:** my prior heartbeat marked App A (Monkey Trading) as "skip-as-card / null-hypothesis reference only." That was Research prior-belief filtering, which Rule 1 forbids. App A becomes S03 in the queue above; card extraction queued for next heartbeat. The Monkey strategy is mechanical (RNG-based entries are deterministic given a seed; exits are fixed-rule), passes all V5 hard rules, and therefore gets a card. Whether it survives G0 / P2 is the pipeline's call, not mine.

## 7. Chapter index (TOC seeded; validate page numbers at extraction)

Extracted from PDF pages 1-14 via `pdftotext -layout` 2026-04-27. Page numbers from the printed TOC; some columns drifted in extraction so a few entries are best-effort.

| Part | Chapter | Title | Page | Strategy density (estimate) |
|---|---|---|---|---|
| I | 1 | The Birth of a Trader | 7 | LOW (memoir) |
| I | 2 | Enough Is Enough | TBD | LOW (memoir) |
| I | 3 | World Cup Championship of Futures Trading® Triumph | 15 | LOW (memoir) |
| I | 4 | Making the Leap—Transitioning to Full Time | 23 | LOW (memoir) |
| II | 5 | Testing and Evaluating a Trading System | 41 | METHOD (no strategies) |
| II | 6 | Preliminary Analysis | TBD | METHOD |
| II | 7 | Detailed Analysis | 53 | METHOD |
| II | 8 | Designing and Developing Systems | 61 | METHOD |
| III | 9 | Strategy Development—Goals and Objectives | 77 | METHOD |
| III | 10 | Trading Idea | 79-83 | METHOD (idea generation; check for examples) |
| III | 11 | Let's Talk about Data | 93 | METHOD |
| III | 12 | Limited Testing | 103 | METHOD |
| III | 13 | In-Depth Testing/Walk-Forward Analysis | 115 | METHOD |
| III | 14 | Monte Carlo Analysis and Incubation | 129 | METHOD |
| III | 15 | Diversification | 133 | METHOD |
| III | 16 | Position Sizing and Money Management | 139 | METHOD |
| III | 17 | Documenting the Process | 147 | METHOD |
| IV | 18 | Goals, Initial and Walk-Forward Testing | 155 | **CASE STUDY (likely 1 card)** |
| IV | 19 | Monte Carlo Testing and Incubation | 163 | METHOD (continues Ch 18 walk-through) |
| V | 20 | Account and Position Sizing | 177 | METHOD |
| V | 21 | Trading Psychology | 187 | METHOD (skip for cards) |
| V | 22 | Other Considerations before Going Live | 195 | METHOD |
| VI | 23 | The Ins and Outs of Monitoring a Live Strategy | 205 | METHOD |
| VI | 24 | Real Time | 219 | METHOD |
| VII | 25 | Delusions of Grandeur | 235 | METHOD (cautionary; skip for cards) |
| — | App A | Monkey Trading Example, EasyLanguage Code | 247 | **NULL-HYPOTHESIS REFERENCE (skip-as-card)** |
| — | App B | Euro Night Strategy, EasyLanguage Format | 255 | **STRATEGY (1 card)** |
| — | App C | Euro Day Strategy, EasyLanguage Format | 259 | **STRATEGY (1 card)** |

Total: 25 chapters + 3 appendices. Strategy-bearing chapters: 18, App B, App C (3 confirmed); App A as null-hypothesis archive only; Ch 10 (Trading Idea) to be reviewed for additional examples.

## 8. Extraction plan

1. **First pass — appendices** (pp. 247-263). EasyLanguage source code is fully self-contained; lowest interpretation risk; produces clean cards quickly.
   - Extract App B Euro Night → `davey-eu-night_card.md`
   - Extract App C Euro Day → `davey-eu-day_card.md`
   - Archive App A code as `raw/appA_monkey_baseline.md` (skip-as-card, V5 P2 reference)
2. **Second pass — Ch 18 walk-through** (pp. 155-162). Determine whether the case-study strategy is distinct from the appendix strategies; if yes, extract; if no, cross-reference inside the appendix cards.
3. **Third pass — methodology cross-walk** (Parts II-VI). Not card-producing. Produce a one-file V5-vs-Davey methodology delta noting where the V5 P-stage flow diverges from Davey's procedure (input to the V5 enhancement-loop docs).

Per-chapter progress comments (per QUA-191 acceptance criteria) posted at chapter-boundary granularity. Methodology chapters posted as one combined comment per Part rather than per chapter to keep thread noise reasonable.

## 9. Completion report contract

When all S-sub-issues under QUA-191 close, Research authors `strategy-seeds/sources/SRC01/completion_report.md` covering at minimum:

- Total strategies extracted vs. expected (3-5)
- Per-strategy verdict (PASS / FAIL / RETIRED) with terminal pipeline phase
- Skipped strategies (failed v0 filter) and reason
- **Methodology-cross-walk delta** (Davey procedure vs. V5 P-stage flow): wins / regressions / neutral
- Source quality and density observations
- Yield ratio: `cards_passed_g0 / heartbeats_used` for `budget_tracking` review
- Recommendation: deeper mining worthwhile? Move on to SRC02 (Chan, *Quantitative Trading*)?

## 10. Cross-references

- Parent issue: [QUA-191](/QUA/issues/QUA-191)
- Source queue: `strategy-seeds/sources/SOURCE_QUEUE.md`
- Workflow doc: `processes/13-strategy-research.md`
- Card template: `strategy-seeds/cards/_TEMPLATE.md`
- Strategy-type vocabulary: `strategy-seeds/strategy_type_flags.md`
- DL-026 (`.DWX` prompt patch retroactively approved 2026-04-27 evening — referenced in the recast comment)
- DL-029 (workflow ratification): `decisions/2026-04-27_strategy_research_workflow.md`
- QUA-188 waiver v3 (CEO-autonomous source-queue ordering): see CEO comment [`dd0f77f5`](/QUA/issues/QUA-191#comment-dd0f77f5-7b98-4331-af7b-c6e013aa3d97) authority pointer
- BASIS rule (verbatim-quote citation discipline): `paperclip-prompts/research.md`
- Parked T2 work (Adam Grimes blog): `strategy-seeds/sources/_t2_pending/grimes-blog/source.md`
- Archived prior SRC01 scaffolds:
  - Chan book initial scaffold: `strategy-seeds/sources/_archived/2026-04-27_chan_book_superseded_initial_scaffold.md`
