# Funnel design decision — 2026-09-05

Status: design recorded before implementation; local draft for REVIEW. Task 2de2ad78-5327-4e4e-9eea-13f82ac9ffd8, coordinated with the priority-96 v5 critique. The binding v5 brief and the design principles supplied in both task payloads govern this work.

## Concept: an open instrument funnel

A narrow elliptical inlet rim, two straight converging walls, a distinct shoulder, and a short parallel outlet make the left-to-right silhouette a physical funnel. The inlet is visibly open. No S-shaped bottle body, round-ended capsule, radial shading, or toy balls. A restrained steel wash makes the interior readable; ink mesh screens form eighteen gates. The shape illustrates selection, not a numerical area scale.

Strategy observations appear as fine steel line segments. A deterministic stratified population encounters the validation screens; the fraction whose route extends past each Q02–Q08 screen follows that gate's recorded count divided by strategies tested. Rejected traces turn towards the screen's lower edge and fade. A few continuing traces reach the neck. This is an aggregate process illustration, not a replay of individual strategy histories. Fraunces remains outside the instrument; IBM Plex Mono labels and tabular counts supply its technical voice.

## Data limits determine the choreography

The supplied census reports 3,097 strategies tested and 50 Q08 clearances. It does not provide linked individual gate histories. Q00 has zero recorded clearances and Q01 three; neither is a denominator for baseline testing. From Q09 onward, subset retests are explicitly not a cohort chain (101, 32, 51, 2, 0, 11, then zeroes). Multiplying those counts into conditional survival probabilities would invent evidence. The continuing traces therefore demonstrate the later process without claiming later clearance or a conversion rate. All eighteen actual numbers, including zeroes, remain printed and available in the accessible table. No zero is silently relabelled “pending” or treated as a recorded pass.

The eight qualified **pairs** and target of twenty-five belong in a separate, labelled summary. They are not eight surviving **strategies**, not a Q17 pass count, and not the denominator or result of the funnel animation. The component updates its associated introductory and basis copy in the DOM to remove the old unsupported width/ball claims; the corresponding permanent HTML changes are proposed separately, without editing the CEO-owned file.

## Legibility and rhythm

Three phase headers align to gate ranges above the instrument. Eighteen gate IDs and exact counts sit in an evenly spaced ledger below it, connected to their screens with quiet ink guides; none is rotated. Full gate names remain in the screen-reader table and a native expandable gate register. At narrow widths the instrument preserves a readable minimum width within a labelled horizontal scroll region, while the control, interpretation, and gate register fit the viewport. Desktop and 800px renders must confirm this before review.

At rest the vessel, screens, population, labels, and counts are already drawn. Traces advance left to right continuously. Under reduced motion they advance more slowly, as explicitly requested for this content animation; Pause/Play is persistent, keyboard accessible, and carries a visible focus ring. Pausing freezes the instrument, including across reload. IntersectionObserver and page visibility suspend animation offscreen; elapsed time does not accumulate into a burst on return. ResizeObserver and DPR-aware backing dimensions preserve sharpness.

## Delivery boundary

Only the local draft's scripts/qm-funnel.js is replaced. No libraries, deployment, deploy-repository commit, CSS-file edit, or HTML-file edit. The supplied data-src fetch, window.QMFunnel.mount entry point, aria description, hidden table, record-stat refresh, and static fetch-failure fallback remain. Final implementation bytes, patch, renders, supplied CEO-probe output, explicit reduced-motion verification, and pixel comparisons will be frozen with the v5 critique evidence on agents/board-advisor.

## Implementation close-out — 22:02Z

The local implementation is complete for REVIEW. The final script is 20,404 bytes. Both 1400px and 800px checks explicitly emulate reduced motion and measure 2,119 / 2,232 changed funnel pixels over two seconds; both paused comparisons measure zero. The supplied CEO probe measures 2,095 changed pixels with no console errors, but reports reduced motion false on this host, which is why the explicit probe is necessary. Counts, keyboard pause, reload persistence, native accessibility table, DPR 2, offscreen suspension, remount cleanup and 390px page containment pass. The expanded gate register uses one column at 800px for easier reading.

See the [full critique and delivery](2026-09-05_design_v5_astra_critique.md), [frozen implementation](2026-09-05_design_v5_astra_critique/qm-funnel.js), [browser evidence](2026-09-05_design_v5_astra_critique/browser_verification.json), and [pixel/hash receipt](2026-09-05_design_v5_astra_critique/verification.json). Shape and later-phase traces remain explicitly illustrative because the public census cannot support a conditional conversion chain across all eighteen gates. No integration or deployment is implied.
