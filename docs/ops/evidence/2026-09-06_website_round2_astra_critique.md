⚠️ DEGRADED: single-context (headless one-pass orchestration; independent dual-agent Impeccable assessments not run).

# Website round 2 — critique and mechanical polish — REVIEW

Task `f219d76a-8b13-4e31-af9d-2084dc59877e`. Target: `C:/QM/deploy/qm-ops-refresh/tools/site-build/homepage-v4/`, served by the existing `http://127.0.0.1:8772/` server. Marketing regime: index. Data regime: archive and `strategies/avoid-monday-index-long-1e38ac.html`. All three rendered in fresh headless Chrome pages at **1440×960 and 375×960**, before and after mechanical changes. Inter, emerald, light ground and the existing funnel were preserved.

Read `C:/QM/repo/skills/web-design-taste/SKILL.md` sections 1–5 and its `impeccable-critique.md`, `taste-redesign-audit.md`, `impeccable-audit.md` references. This is a single-context browser/source audit with the reference heuristics; it is **not an independent dual-agent Impeccable critique**. The vendored CLI executable was actually attempted (`impeccable detect --json .../index.html`) and is absent. No browser overlay or detector score is claimed. The user requested a headless cycle, so no interactive permission/question workflow was started.

## Design assessment

The candle field, explicit research gate journey and full research matrix express this product. The archive is useful because it preserves the complete record with progressive paging, including failures. The detail page puts mechanism and provenance ahead of its ledger. The strongest opportunity is precision of explanation: the inspected detail's generic family text contradicts its specific tagline. Layout polish cannot resolve that content defect.

Judgement was recorded in `2026-09-06_website_round2_astra_critique/design_observations_before_metrics.md` before the parent read computed contrast results. This does not supply independent assessment provenance.

## Ranked findings and applied fixes

Paths below are relative to the local website target. Evidence images are in the same-named evidence directory beside this report.

| Priority | Finding / location | Applied result | Screenshot evidence |
|---|---|---|---|
| 1 | Orange optimization text and mixed glyphs at `archive.css:36`, `:552` had **2.59–2.80:1** contrast. Missing-gate dashes at `:555` had **1.60–1.61:1**. | Added an orange text token `#b54708`, retained bright orange for semantics/borders, and used existing readable muted ink for missing-gate marks. | `crop_before_legend.png` → `crop_after_legend.png`; `before_matrix_1440.png` → `after_matrix_1440.png` |
| 1 | Future ledger rows at `archive.css:614` multiplied text opacity by .72; purpose text was **2.92:1**, outcome text **3.06:1**. | Removed row opacity; existing muted labels and NOT REACHED outcome retain hierarchy. | `crop_before_future_gate.png` → `crop_after_future_gate.png` |
| 1 | Archive and detail declared Inter but loaded Fraunces in HTML line **6**. | Repaired the font request on the two reviewed pages to load the OWNER-selected Inter. After readiness, browser font records include Inter, IBM Plex Sans and IBM Plex Mono. Other generated pages need the same correction in their generator on a later integration pass. | `before_detail_1440.png` → `after_detail_1440.png`; font evidence in `after_metrics.json` |
| 1 | Strategy cells stayed fixed, but their column header moved out of view during horizontal scrolling (`archive.css:530`). | Added the missing `left:0`. At 375px, row and header now both sit at x=26.375; before, header x=-673.625. At 1440px both are x=61. | `before_sticky_375.png` → `after_sticky_375.png` |
| 2 | Mobile summary flex wrapping put figures in irregular columns with little row separation (`archive.css:632`). | Two equal columns and explicit 18px/24px row/column gaps; numerical content and type size retained. | `crop_before_stats.png` → `crop_after_stats.png` |
| 2 | Hovered sticky names had a translucent background, allowing scrolled content underneath to bleed through. | Composited the same emerald wash onto an opaque panel ground. | `after_sticky_375.png` |
| 2 | Escape closed mobile navigation while its accessible label still said “Close navigation” (`scripts/review-site.js:15`). | Close handler restores “Open navigation”; focus returns and hidden menu remains inert. | `interaction_checks.json` |

## Judgement memo — not applied

1. **Content contradiction, high impact.** `strategies/avoid-monday-index-long-1e38ac.html:28` says Tuesday-open to Friday-close holding in its tagline, while How it trades says “Intraday, contained within the session” and closes within the target session. The family-derived explanation should be replaced with a verified strategy-specific explanation from publishable metadata. Do not infer private settings. See `after_detail_1440.png`, where both statements are visible.
2. **First-screen hierarchy.** `index.html:40` has a 34-word lead rather than the skill's approximately 20-word target; at 375px the headline wraps to three lines rather than two. The archive introduction and summary put search below the first viewport. Consider shorter copy and collapsible summary disclosure while retaining all 3,339 rows and the wide matrix. No copy, headline sizing or section ordering was changed. See `before_home_375.png`, `after_archive_375.png`.
3. **Motion ceiling.** The hero has a persistent candle animation (`scripts/qm-hero-bg.js:317`) in addition to the funnel. Reduced motion produces a visible static hero and a stopped funnel with a disabled explanatory control, but ordinary mode exceeds the skill's one-authored-moment ceiling. Keep the funnel; consider a static hero or an explicit hero pause. That motion-design decision was left unchanged.
4. **CTA accent.** The default primary CTA is dark ink with emerald hover. The skill describes an emerald hero CTA. This is an intentional-looking composition choice rather than a contrast defect, so it remains a note for OWNER.

## Craft-floor verification

| Check | Result and limits |
|---|---|
| Contrast | After correction, **zero measured failures on all six page/width combinations** for DOM text/glyphs (4.5:1 normal, 3:1 large); enabled archive placeholder 5.44:1. Computation composites backgrounds and inherited opacity. Canvas pixels, disabled controls and every possible hover combination are not certified. Initial archive metrics caught the streaming response before paging/font readiness; final checks explicitly wait for load, fonts and the initialized 200-row count. |
| Type | Inter loaded on all three reviewed pages; tracking -.03em, above the -.04em floor; display below 6rem. Archive lead max 65ch, detail explanation 72ch; width shrinks on mobile. Headline line-count judgement remains above. |
| Spacing | Computed section padding 96px desktop / 64px mobile on marketing; detail rows 18px desktop / 14px mobile with 6px mobile internal gap. Mobile stats now use explicit grid gaps. |
| Overflow | `document.scrollWidth - viewportWidth = 0` at 1440 and 375 on all three pages. The approximately 2,000px matrix scrolls in its own container. |
| States / keyboard | Initial 200 rows → Show more 500; unmatched search displays the empty explanation with zero rows; clearing search restores 200; Enter sorts and updates aria-sort; 2px focus outline observed; mobile Escape closes, restores label/focus and makes menu inert. Simulated performance-data failure yields an explanatory message with an external-record fallback. Static archive has no fetch-loading state; its noscript content retains the full table. |
| Motion | Reduced-motion hero remains visible; funnel control says motion stopped and is disabled. Ordinary-mode extra hero animation remains a judgement finding. |
| Browser surfaces | Selection colors and underline offsets exist in the shared stylesheet; matrix values compute tabular-nums; table scrollbar stays local; focus visible; sticky header/first-column alignment verified after scrolling. |
| Exposure | **3,369 generated HTML files scanned; zero matches before and after** for EA IDs, known parameter identifiers, set-file extensions, private drive paths/host markers, terminal names and magic-ID labels. Exact regex coverage is retained in `exposure_after.json`; this is a defined scan, not a claim of exhaustive semantic secrecy certification. |
| Brief coverage | Hero, archive routes, real matrix, search/filters, progressive paging, detail mechanism, markets, gate ledger and non-publication note are present. Numbers retain their existing public-data basis; this pass does not adjudicate differing snapshot/census denominators. |

The error-path and reduced-motion tests initially used the wrong expected control label; the harness was corrected to the actual explicit reduced-motion label. No product fix was needed for that check. The sticky-header defect was found by the interaction round and received one focused recheck after its fix.

## Run notes and handoff

All changes are **local only** in the integration copy; no site git add/commit/push and no deploy. Evidence-only commits use canonical `C:/QM/repo/docs/ops/evidence/` on `agents/board-advisor`, as required by this cycle's direct instruction. `mechanical.patch` and `changed_files.json` make the four changed site files reviewable. Homepage source and funnel source are unchanged.

Full before/after viewport screenshots cover all six page/width pairs; additional matrix, ledger, sticky, empty-state and six crop images are retained. Before crops replay the original saved stylesheet in an isolated browser route; original untouched before viewport captures are also retained. Measurement, capture and interaction scripts are included for reproduction. No review-only web server was started; the existing 8772 server remains untouched. Headless browsers were closed by their owning scripts/Playwright contexts. No human-visible overlay was injected. No ignore file or bundled detector executable was found in the provided skill package; no storage slug tool is available, so the explicit target path is the run identity.

**REVIEW**: mechanical fixes verified within this scope; copy, motion and composition findings remain open. Questions skipped: headless single-pass scheduled task; judgement decisions are recorded for review.
