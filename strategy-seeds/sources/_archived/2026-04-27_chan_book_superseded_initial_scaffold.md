---
source_id: SRC01
parent_issue: QUA-191
status: source_text_pending
authored-by: Research Agent (QUA-191)
last-updated: 2026-04-27
---

# SRC01 — Ernest Chan, *Algorithmic Trading: Winning Strategies and Their Rationale*

This is the per-source identity and drop-convention file required by `processes/13-strategy-research.md` § "Per-step responsibilities" step 1 and § "Exits" (parent close → `completion_report.md`). It is the first concrete artifact for SRC01, scaffolded while the source text itself is still pending.

## 1. Source identity

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. 1st edition. John Wiley & Sons. ISBN 978-1-118-46014-6."
    location: TBD                              # populated per-card with chapter/section/page on extraction
    quality_tier: A                            # peer-known practitioner; quantitative-finance staple
    role: primary
```

Why this source first, per CEO recommendation (ratified on QUA-188 / QUA-144 interaction `194a59ce`): "clean, well-structured book validates the depth-first workflow before stress-testing it on Kaufman's scope or Grimes' cadence."

## 2. Drop-path convention (binding for OWNER)

OWNER drops the source text at one of the following paths. Research will pick whichever is present (PDF preferred for verbatim page citations; ePub or text accepted but page-citation accuracy degrades).

```
G:\My Drive\QuantMechanica\Ebook\Chan_AlgorithmicTrading.pdf       ← preferred
G:\My Drive\QuantMechanica\Ebook\Chan_AlgorithmicTrading.epub      ← acceptable
G:\My Drive\QuantMechanica\Ebook\Chan_AlgorithmicTrading.txt       ← fallback
```

If OWNER prefers a different filename, name it in a QUA-191 comment and Research updates this file.

If only an ePub or text dump is provided, Research will cite by chapter + section heading (and approximate page if reflowable). The `_TEMPLATE.md` § 9 "Author Claims" hard rule still requires verbatim quotes; section-level citations are acceptable when page numbers are not available.

## 3. Source-availability status (current)

```yaml
checked: 2026-04-27
checked_paths:
  - "G:\\My Drive\\QuantMechanica\\Ebook\\"               # exists; contains only figures/ subfolder, no book file
  - "G:\\My Drive\\QuantMechanica\\"                       # broad recursive search, no chan/algorithmic-trading file
  - "C:\\QM\\"                                             # broad recursive search, no chan/algorithmic-trading file
  - "D:\\QM\\"                                             # broad recursive search, no chan/algorithmic-trading file
result: not_found
unblock_owner: OWNER
unblock_action: "Drop Chan PDF/ePub/text at one of the paths in § 2 above, or specify a different filename via QUA-191 comment."
```

## 4. Expected strategy count

Best estimate from public TOC of the 2013 1st edition (TBD pending direct TOC scan):

```yaml
expected_strategy_count: TBD                  # populated after first chapter scan
expected_chapter_count: 8                     # public TOC: Background, Backtesting, Mean-Reversion of Stocks/ETFs, Mean-Reversion of Currencies/Futures, Interday Momentum, Intraday Momentum, Risk Management, Conclusion
notes: |
  Chan's "Algorithmic Trading" (2013) reportedly walks through ~12-18 named example strategies across the
  mean-reversion and momentum chapters, plus several auxiliary risk-management overlays. The exact count
  depends on whether each "example" is a distinct strategy with its own backtest or a parameter-variant of
  a prior one. Research will produce the final count after a TOC scan in the first extraction pass.
```

The expected-count field is non-binding — actual count is whatever the source contains. It exists only so CEO can size the sub-issue dispatch in step 5.

## 5. v0 filter rules applied to this source (per QUA-191 acceptance criteria)

Strategies extracted from this source must pass ALL of the following, or be flagged-and-skipped per the parent issue:

- **Mechanical only** (no discretionary judgement) — `_TEMPLATE.md` § 11 checkbox.
- **No Machine Learning** — V5 hard rule `EA_ML_FORBIDDEN`. Statistical fits like Kalman filter, regression, HMM-with-EM are NOT ML in the V5 sense per `strategy-seeds/strategy_type_flags.md` § E (`ml-required` definition). True ML (gradient-boosted trees, neural nets, online learners) → flag and skip.
- **`.DWX` suffix discipline** — V5 framework references symbols with the `.DWX` suffix. Strategies citing symbols without `.DWX` raise `dwx_suffix_discipline` in `hard_rules_at_risk`.
- **Magic-formula registry compatible** — `magic = ea_id*10000 + symbol_slot` (per CLAUDE.md). Strategies needing multi-instance / multi-magic accounting per symbol → flag and surface to CEO before extraction.
- **News-compliance compatible** — Strategy must survive the V5 P8 News Impact gate (modes OFF / PAUSE / SKIP_DAY per `decisions/2026-04-25_news_compliance_variants_TBD.md`). Pure news-trading strategies → flag and surface to CEO.
- **Mean-reversion-of-stocks / pairs-trading caveat** — Several Chan chapters use a US equities universe with corporate-action-adjusted prices via CRSP-style data. The V5 framework targets Darwinex FX / indices / commodities feeds; pairs-on-equities strategies will be flagged and may be re-mapped (e.g., to FX cross-pairs) only with explicit CEO + CTO approval before card draft.

A "flag and skip" strategy still gets a one-line entry in this file's § 6 below documenting why it was skipped, so the source completion report is auditable.

## 6. Sub-issue queue

Populated after extraction begins. Each row maps to one sub-issue under QUA-191 per the issue-tree shape in `processes/13-strategy-research.md` § "Issue tree shape".

| Slot | Strategy slug | Card path | Sub-issue | Status | Notes |
|---|---|---|---|---|---|
| S1 | TBD | TBD | TBD | not yet extracted | first extraction pass blocked on source text |

Skipped strategies (failed v0 filter) — record here with one-line reason:

| Source location | Reason for skip |
|---|---|
| TBD | TBD |

## 7. Completion report contract

When all sub-issues under QUA-191 close, Research authors `strategy-seeds/sources/SRC01/completion_report.md` covering at minimum:

- Total strategies extracted vs. expected
- Per-strategy verdict (PASS / FAIL / RETIRED) with terminal pipeline phase
- Skipped strategies (failed v0 filter) and reason
- Observations about source quality and density
- Recommendation: deeper mining worthwhile? Move on to SRC02?

## 8. Cross-references

- Parent issue: [QUA-191](/QUA/issues/QUA-191)
- Workflow doc: `processes/13-strategy-research.md`
- Card template: `strategy-seeds/cards/_TEMPLATE.md`
- Strategy-type vocabulary: `strategy-seeds/strategy_type_flags.md`
- DL-029 (workflow ratification): `decisions/2026-04-27_strategy_research_workflow.md`
- v0 filter origin: QUA-191 issue description "Acceptance criteria" + `paperclip-prompts/research.md` boundaries
