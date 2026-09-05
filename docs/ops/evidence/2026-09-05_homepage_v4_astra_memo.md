# Homepage proposal: The Quantitative Edge.

Task: 93aaf7ea-55b3-4210-893a-92c6b4afe7b7. Local Astra review copy only. Status: REVIEW; local implementation and browser checks complete; CEO review required.

## Where the CEO draft is right / wrong

1. **Headline.** The evidence-first lead is useful, but replacing the requested headline removes the site's strongest identifying phrase. Restore “The Quantitative Edge.” and let the lead explain the work rather than promise returns.
2. **Records block.** “Inside every record” explains navigation rather than showing research. Replace it with the supplied snapshot: 3,097 distinct strategies tested; 124,145 completed backtests; 18 gates; 8 currently qualified market/timeframe pairs, against a target of 25. These are different units, not interchangeable success counts.
3. **Funnel.** Three equal text columns explain phases but show no selection. Use a wide elliptical inlet, long straight converging walls and a short narrow outlet. This is a recognisable physical filter rather than another content panel.
4. **Strategies in motion.** Small traces express research observations more precisely than glossy balls. Ink gate meshes and steel traces fit the later workshop brief. Particle motion is illustrative: the supplied gate totals are independent censuses, with increases and zeros, so consecutive ratios are not observed pass probabilities. Publishing those ratios as pass rates would fabricate a cohort. Exact counts remain visible and accessible; zero never silently becomes 100% passage.
5. **Mechanics.** Three compact charts in a row flatten distinct hypotheses. Use three full-width rows: session liquidity/ICT-SMT, indicator regime, and calendar/relative-value behavior. Each row has a short hypothesis and its own light terminal chart. All charts are explicitly synthetic illustrations, not results from those models.
6. **Header.** Restore the candle field as a quiet instrument behind the headline. Keep it sufficiently faint for text contrast, and static when reduced motion is requested. The navigation, contact, disabled newsletter, canonical links and footer remain usable.

## My concept

**Preferred — the filter instrument (Canvas).** A sideways conical funnel with an elliptical open mouth, straight walls, visible mesh stations, and a short outlet. Three labelled phase bands sit above it; eighteen gate readouts sit in an expandable ledger below. The aesthetic risk is the large technical drawing with a visibly empty outlet: the supplied Q15–Q17 counters are all zero. The separate eight-pair qualification statistic must not be illustrated as eight Q17 graduates. Fine steel traces move left to right, with independent gate densities derived from each gate's count divided by the supplied tested-strategy total. Segment boundaries restart observations, so the display does not imply that a single cohort follows the entire chain. Gate totals are exact; motion is explicitly illustrative, not an estimate of conditional survival.

**Alternative — three evidence ribbons (SVG and CSS).** Three separated horizontal ribbons represent the phase cohorts. Each gate is a transverse ruler with an exact count; ribbon widths encode each independent count. It is the clearest statistical picture and adapts well to a stacked mobile layout, but does not meet the OWNER's request for one physical funnel as directly. Prefer this if measured conditional passage becomes more important than the funnel metaphor.

The preferred implementation uses no external JavaScript dependencies, caps the canvas pixel ratio at two, stops offscreen, and provides a persistent keyboard-operable Pause/Play button. Astra's reduced-motion default is a static frame; the later v4 brief can opt into calm content motion without changing this default. An accessible sentence, static phase labels and an HTML gate table carry the information without canvas. The new code budget is below 60 KB. Laptop 60 fps is a target; browser frame timing on this review host will be reported as host evidence, not a laptop certification.

The public JSON is supplied in the sibling homepage-v4 copy and is copied byte for byte into Astra, where it was absent. Its snapshot is 2026-09-05T16:26:41Z, schema qm.public-funnel-stats/v1. No research numbers are invented or scraped from operational state for the page.

## Open design questions for the CEO

- Approve the physical funnel with the explicit independent-cohort explanation, or prefer the three-ribbon alternative until a cohort-linked pass-rate export exists?
- Should the qualified-pair target remain next to the current eight, or move to the pipeline page to avoid reading a research target as a product promise?
- The third mechanism is calendar/relative value. Confirm the public example taxonomy before attaching any real strategy results to these illustrative charts.
- The later v5 brief selects steel, Fraunces and Plex. This prototype keeps its shell but uses the steel instrument treatment in the new sections; the v4 system remains the CEO's integration surface.

## Verification

Browser verification passed at 1400, 800 and 390 px with no horizontal overflow and zero console/page errors. All 18 visible ledger entries and 18 accessible table rows are present, as are three mechanics charts, canonical link, contact/newsletter and footer. Keyboard Pause works and persists through reload. Both funnel and candle header are static under reduced motion. Two normal-motion frames two seconds apart differ by 1337 pixels within the funnel canvas. The review-host median and p95 requestAnimationFrame intervals are 16.7/16.8 ms over 120 samples; this is not a laptop certification.

The new funnel plus homepage enhancement JavaScript totals 13,844 bytes. Node syntax checks passed. The visible-text exposure scan passed. The public snapshot is byte-identical to the supplied sibling snapshot. The first mobile check exposed hidden-table intrinsic-width overflow; the table now has a clipped block box with an explicit table role and the corrected run passes.

Review artifacts: `2026-09-05_homepage_v4_astra/astra-1400.png`, `astra-800.png`, `astra-390.png`, individual funnel crops, two motion frames, `browser-verification.json`, reproducible browser check, before/after source copies, exact proposal patch and SHA-256 manifest. The copy is served locally on port 8771. No deploy-repository commit, push or deployment occurred. Independent cohorts prevent honest conditional pass rates; that remaining data limitation is explicit on the page and requires a cohort-linked export, not design invention.
