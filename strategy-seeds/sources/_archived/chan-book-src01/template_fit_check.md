# SRC01 — Strategy Card Template fit-check vs V5 v0 filter

> **Purpose:** confirm `strategy-seeds/cards/_TEMPLATE.md` already encodes every v0-filter condition, so per-card extraction is mechanical (read book → fill template → run v0-filter checklist → either save card or log rejection in `v0_filter_rejections.md`).
> **Authority:** CEO scaffolding authorization (QUA-191 comment `fe3e23a5`, 2026-04-27).
> **Scope:** template structure only. No body claims about the Chan book.

## v0-filter terms (per QUA-191 acceptance criteria)

The issue lists five v0-filter conditions:

1. **mechanical** (no discretionary judgment)
2. **no ML** (no machine learning entries / exits / sizing)
3. **no `.DWX` suffix** — see § Term ambiguity below
4. **fits the magic-formula registry**
5. **news-compliance compatible**

## Template coverage map

| v0-filter term | Template field that enforces it | Status |
|---|---|---|
| mechanical | § 11 Allowability Check, item 1: "Strategy concept is mechanical (no discretionary judgment)" | **Covered** |
| no ML | § 10 Initial Risk Profile `ml_required: false` (V5 hard-fail if true); § 11 item 2: "No Machine Learning required (V5 ban — `EA_ML_FORBIDDEN`)" | **Covered** (double-gated) |
| no `.DWX` suffix | *not currently enforced in template* — see § Term ambiguity | **OPEN — needs CEO confirmation before extraction** |
| fits the magic-formula registry | Implicit via § 12 Implementation Notes (CTO assigns ea_id at APPROVED) and `_TEMPLATE.md` strategy_id `SRC{source_id}_S{n}` scheme; framework spec `V5_FRAMEWORK_DESIGN.md` § Magic schema (line 30) defines the formula `ea_id * 10000 + symbol_slot`. No explicit allowability item for "fits magic formula" in template. | **Partial — recommend adding §11 item** |
| news-compliance compatible | § 6 Filters references `QM_NewsFilter`; § 11 item 5 covers Friday Close compatibility but **does not explicitly cover news-compliance variant compatibility per `PIPELINE_PHASE_SPEC.md` P8**. | **Partial — recommend adding §11 item** |

## Term ambiguity — `no .DWX suffix`

The issue lists "no `.DWX` suffix" as a v0-filter pass condition. This contradicts `framework/V5_FRAMEWORK_DESIGN.md` line 28:

> **`.DWX` suffix discipline** — Symbols carry `.DWX` in research and backtest, stripped only at deploy packaging. `framework/scripts/strip_dwx_at_deploy.ps1` is the only sanctioned stripper.

V5 strategies normally **do** carry `.DWX` in research / backtest. Three plausible readings of the issue's phrasing:

1. **Reading A — Darwinex-symbol-feasible:** the v0 filter wants ideas that work on Darwinex's `.DWX`-suffixed symbol set. Effectively: "Darwinex MT5 native data only" per framework line 32. Anything requiring a non-Darwinex universe (US single stocks, leveraged ETFs not on Darwinex, etc.) fails.
2. **Reading B — source-citation literal:** the source's quoted symbols should not contain `.DWX` (because Chan's book, written in 2013, would never use that suffix). This is trivially always true and not a useful filter.
3. **Reading C — typo:** the intended condition was something else (e.g., "Friday Close compatible" or "Model 4 compatible") and `.DWX` was misplaced from the framework rules list.

**Research's working assumption:** Reading A. This matches `V5_FRAMEWORK_DESIGN.md` line 32 ("Darwinex MT5 native data only") and is the only reading that produces a meaningful filter signal during extraction.

**CEO action requested:** confirm Reading A on QUA-191, OR clarify the intended filter. No card extraction will rely on this term until disambiguated.

## Recommended template additions (preview, NOT yet applied)

If CEO approves, Research proposes adding three items to `_TEMPLATE.md` § 11 Allowability Check before SRC01 extraction begins, so every card is gated on the issue's exact v0-filter wording:

```markdown
- [ ] All symbols required by the strategy are available on Darwinex MT5 native data with `.DWX` suffix (or feasibly added per `framework/include/QM/...` symbol-list extension)
- [ ] Magic-number assignment is feasible under `framework/registry/magic_numbers.csv` schema (ea_id × 10000 + symbol_slot)
- [ ] Strategy is compatible with all news-compliance variants Research / Quality-Tech currently support (default ON per P8); document any required exception
```

These additions do **not** change card structure — they just make the v0-filter conditions explicit at allowability-check time so reviewers don't have to re-derive them per card.

**No file edit yet.** Research will edit `_TEMPLATE.md` only after CEO ratification on the QUA-191 thread, since the template is shared scaffolding and a non-trivial edit in advance of confirmation could regress other agents' assumptions.

## Mechanical-extraction checklist (final shape after disambiguation)

Once source text arrives and CEO disambiguates `.DWX`, the per-strategy extraction loop is:

1. Read chapter section in source text.
2. Identify distinct mechanical strategies (entry rule + exit rule + symbol class).
3. Copy `_TEMPLATE.md` to `strategy-seeds/cards/SRC01_S<NN>_<slug>_card.md`.
4. Fill § 1-10 from source verbatim where required (no paraphrase of performance claims).
5. Run § 11 Allowability Check including the three additions above.
6. If any item fails: do NOT save card; append entry to `v0_filter_rejections.md` with chapter / section / fail reason.
7. If all pass: commit card with `status: DRAFT`, post per-chapter progress comment on QUA-191.

## Output

Result of fit-check: **template covers 2 of 5 v0-filter terms cleanly; 3 need explicit allowability items + 1 term needs CEO disambiguation**. No template edits applied — proposal documented here for CEO review on QUA-191.
