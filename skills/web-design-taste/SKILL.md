---
name: web-design-taste
description: Design-taste and review guidance for the QuantMechanica public website (landing page, 3,300-row strategy archive table, strategy detail pages). Light ground, STEEL + EMERALD brand, Inter display. Adapted from Leonxlnx/taste-skill (MIT), pbakaus/impeccable (Apache-2.0) and github/awesome-copilot web-design-reviewer (MIT); see NOTICE.md.
---

# QuantMechanica web design taste

Applies to every agent that designs, builds or reviews the public website
(deploy worktree `tools/site-build/homepage-v4`, served locally on 8772).
The OWNER's explicit words always win over anything here. Hard limits that are
not design choices: no private tokens on the page (no VPS paths, hostnames,
terminal names, account numbers, magic numbers, EA ids, card files, set values,
parameter names or values, ticket ids); numbers only from `public-data/*.json`;
brand spelling "QuantMechanica"; no deploy without the Mission-Control receipt.

## 0. Name the regime before touching code

State in one line which surface you are on. The two regimes have different rules.

- **Marketing surface**: index, about, pipeline, performance, blog. Persuade and
  explain. Restrained editorial polish.
- **Data surface**: strategy archive table, strategy detail pages. The full
  dataset is the product. Scannability, density, predictability, zero decoration.

## 1. Brand tokens (fixed)

- Ground: light, steel-tinted paper (`--paper`), panels white, ink slate
  (`--ink`, `--ink-2`, `--ink-3`). Never pure `#000`/`#fff` for text or ground.
- Accent: emerald, one family (`--accent` #059669 for text/links on paper,
  `--accent-bright` #10b981, `--accent-soft`, `--accent-on-dark` #34d399).
  Exactly one accent on the site; the hero CTA, table highlights, funnel flow and
  chart emphasis all use it. Steel blue stays a structural secondary only.
- Semantics are not decoration: `--pass` green, `--fail` red, `--warn` orange
  (#f97316, never amber). They never serve as accents.
- Display and headings: Inter 600/700, tracking -0.02 to -0.03em (floor -0.04em),
  `text-wrap: balance`. This is the OWNER's deliberate choice; do not swap it for
  a trend face. Body: IBM Plex Sans 17px, measure 60-70ch. Data: IBM Plex Mono
  with `font-variant-numeric: tabular-nums`.
- Structure comes from hairlines and spacing, not from cards. Radius 4px max on
  controls; no shadows on blocks; no gradients; no glow; no glass.
- Light theme is the site. No inverted sections mid-page.

## 2. Marketing surface

- Hero fits the first viewport: headline "The Quantitative Edge." in at most two
  lines, one lead of at most ~20 words, one primary and one secondary action,
  the candle field behind at low contrast (rest state must be a readable chart,
  never blank). No trust strip, no counters stuffed under the CTA.
- Left-aligned or split compositions; never everything centred.
- At most one eyebrow per three sections; numbered section markers only when the
  content is a real sequence (the gate journey qualifies, feature lists do not).
- No three identical cards as a feature row. Vary layout families down the page.
- One label per intent; the same CTA wording in nav, hero and footer.
- Motion ceiling: one authored moment (the funnel), a once-only 8px reveal on
  scroll, hover underline. Everything else static. `prefers-reduced-motion`
  keeps content visible and offers a pause control.
- Copy: plain, specific, the company's own words. No "elevate", "seamless",
  "unleash", no invented names, no decorative version stamps or scroll cues.
- Charts are drawn to a scale, labelled in mono, coloured from tokens, with
  hairline grid; candle fields use realistic OHLC (volatility clustering,
  intrabar-derived wicks, fixed pitch).

## 3. Data surface

- A real table: one row per strategy family, sticky header, sortable columns,
  filter chips, search, and progressive reveal for 3,300 rows. Never a curated
  "top five" in place of the dataset. Wide tables scroll inside their own
  container; the page never scrolls sideways.
- Density is correct here: tight padding, hairline row dividers, mono figures,
  status as small semantic chips. No cards around metrics.
- Detail pages: headline (name), one-line tagline, then "How it trades" in
  words, markets and timeframes, the evidence ledger per gate (purpose, outcome,
  date, extent), and a plain note on what is not published. No parameters.
- Motion: none beyond hover and focus states.
- Empty, loading and error states are designed, not blank.

## 4. Verify before you hand over (from the craft floor)

Run these on the built result, once, in one batched inspection round
(desktop 1440 and mobile 375), then fix and stop:

- Contrast: body and placeholders >= 4.5:1, large text >= 3:1, chips and links
  included.
- Type: measure 60-75ch, display <= 6rem, tracking floor -0.04em, no orphans,
  no overflow with the real copy at every breakpoint.
- Spacing: tight groups, generous separation, more space above a heading than
  below it; read the computed values, do not guess.
- Motion: one authored moment; exponential ease-out from a visible default.
- States: hover, focus-visible, disabled, empty, error; keyboard operable.
- Browser surfaces: selection colour, focus ring, underline offset, tabular
  numerals, scrollbar inside the table container.
- Exposure scan: grep the generated HTML for `QM5_`, parameter names, `.set`,
  magic numbers, hostnames. Zero hits.
- Coverage: every brief requirement present and findable within seconds.

## 5. Review protocol (critique and audit)

A reviewer reads the brief, renders the page (headless Chrome or
`scratchpad/render_page.sh`), then scores against `references/impeccable-critique.md`
(heuristics) and `references/taste-redesign-audit.md` (generic-pattern audit),
adds the mechanical checks from `references/impeccable-audit.md`, and returns
findings as file:line + screenshot crop, ranked by user impact. Findings that
contradict the OWNER's pinned choices (Inter, emerald, light ground, funnel by
Astra) are reported as notes, never applied.

## 6. Out of scope for this site

GSAP scroll-hijacking, pinned stacks, kinetic type, dome galleries, magnetic
hover; image generation and stock photography; design-system install matrices;
"avoid Inter" defaults; "cut the data" density rules on data surfaces.

## References (vendored, see NOTICE.md)

- `references/impeccable-craft-floor.md`: verify list and refuse list.
- `references/impeccable-typeset.md`, `impeccable-layout.md`, `impeccable-polish.md`.
- `references/impeccable-critique.md`, `impeccable-audit.md`: review playbooks.
- `references/taste-redesign-audit.md`: generic-AI-pattern audit checklist.
- `references/taste-skill-v2-full.md`: the full source (data, read selectively).
- `references/web-design-reviewer.md`: screenshot-driven review workflow.
