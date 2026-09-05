# QuantMechanica website — design brief v5 (CEO design lead, 2026-09-05)

OWNER verdict on the current site (2026-09-05 ~19:20Z): "Das Design der Website ist echt schrecklich und lieblos." He asked that the design skills be switched on for Claude and Astra. This brief is the binding design direction for both. It applies the editorial-treatment rules of the `artifact-design` skill: honor the existing system only where it is deliberate, ground every choice in the subject, pair typefaces on purpose, let layout do the spacing, do not stamp cards on everything, and avoid the templated "AI look".

## 1. Diagnosis of the current look

- System font stack (Inter/SF fallback, no loaded face), pure white ground, Apple-grey ink `#1d1d1f`, one green accent, rounded cards everywhere, centred hero, `rounded-lg` panels: this is the generic template the skill warns about. Nothing in it says "quant research workshop".
- The charts are the only element with character (light TradingView-style terminal frames, OWNER-chosen). Keep them and build the rest of the identity around the instrument.
- The archive (3,339 named families with gate journeys) is the real product; the shell must present it like a serious research record, not a SaaS landing page.

## 2. Concept

**"The instrument panel of a research workshop."** A build-in-public quant house that publishes its evidence. Visual world: precision instruments, terminal charts, evidence tables, gate stamps, tabular numbers, hairline rules. Tone: exact, calm, confident, never salesy. One place of boldness: the hero headline "The Quantitative Edge." set in the display face, everything around it quiet.

## 3. Tokens (binding)

Colour (light-first; the OWNER chose the light TradingView chart profile):

| Token | Hex | Role |
|---|---|---|
| `--ink` | `#0f1720` | primary text, chart ink, hairlines at low alpha |
| `--ink-2` | `#3a4653` | secondary text |
| `--ink-3` | `#6b7785` | captions, mono labels |
| `--paper` | `#f4f6f8` | page ground (cool, steel-tinted, not pure white, not cream) |
| `--paper-2` | `#ffffff` | panels, tables, chart frames |
| `--steel` | `#2954d4` | brand accent (links, focus, key rules, funnel flow) - the QuantMechanica steel blue |
| `--steel-soft` | `rgba(41,84,212,.10)` | accent wash |
| `--pass` | `#0a7d4f` | semantic PASS only (never decoration) |
| `--fail` | `#c8412d` | semantic FAIL only |
| `--warn` | `#b7791f` | semantic mixed/pending |
| `--line` | `rgba(15,23,32,.12)` | hairlines |

Type (Google Fonts, with real fallback stacks; `font-display: swap`):

- Display: **Fraunces** (variable, opsz on, weight 500-600, tracking -0.02em, `text-wrap: balance`). Used for H1/H2 and the big numbers' captions, never for body.
- Body: **IBM Plex Sans** 400/500/600, running text at 17-18px, measure ~65ch.
- Data: **IBM Plex Mono** 400/500 for eyebrows, gate ids, chips, tables, axis labels, stat figures (`font-variant-numeric: tabular-nums`).
- Scale: 13 / 15 / 17 / 20 / 24 / 32 / 44 / 64 / 88 (clamp on the two largest). Line-height 1.15 display, 1.55 body.

Layout: 12-column grid, max content 1180px, asymmetric editorial compositions (text column 5/12, instrument 7/12), vertical rhythm on an 8px base with generous section spacing (96-128px). Structure is encoded by **hairline rules and mono eyebrows**, not by cards. Cards are reserved for records (archive rows, stat tiles). Numbered markers only where the content is a real sequence (the gate journey, the pipeline phases).

Motion: hero candle field (existing script), funnel (Astra's design), subtle reveal on scroll (opacity/translate 8px, 400ms, once), hover underline animations on links, chart cursor hairline. Reduced-motion: content animations keep running slower with a pause control; decorative reveals are disabled.

## 4. Components

- **Nav**: wordmark "QuantMechanica" in IBM Plex Mono 500 with tracking, small; links in Plex Sans; a 1px steel rule under the nav; sticky.
- **Hero**: eyebrow (mono, steel) - H1 Fraunces "The Quantitative Edge." - lead (Plex Sans, 20px, measure 60ch) - two buttons (primary = ink fill, secondary = hairline outline; no pill radius: radius 4px). Candle field behind at low contrast.
- **Numbers block ("The record, in numbers")**: six figures as instrument tiles: figure in Plex Mono 44px tabular, caption in Plex Sans 15px, thin top rule per tile, no shadows, no rounded corners beyond 4px; one line of basis text underneath.
- **Gate funnel**: Astra's design (ticket 2de2ad78) restyled with these tokens: steel flow, ink sieves, mono labels.
- **Mechanics rows**: vertical, text left (eyebrow + h3 Fraunces + 2-3 sentences) and chart right in an instrument frame (1px ink hairline, mono axis labels, light TradingView colours).
- **Live record panel**: mono figures, chart in the same frame, "View the DARWIN record" as a text link with arrow.
- **Archive list**: dense research-record rows: name (Fraunces 24px), tagline (Plex Sans), family + status chips (mono, outlined), markets in mono; hairline separators; sticky filter toolbar.
- **Detail page**: same components; gate journey as a numbered ledger (Q02...), chips per market, retest sequences shown as "FAIL -> PASS".
- **Footer**: three columns, mono eyebrows, risk disclosure in 13px.
- **Buttons/links**: focus-visible ring in steel 2px; hover underline grows from left.

## 5. Copy rules

Plain, specific, honest. Name things by what visitors recognise. No "proven edge", no survival percentages without source, no throughput boasts. Brand spelling always "QuantMechanica".

## 6. Anti-patterns (reject on sight)

Inter/Space Grotesk/system-only type; pure white or cream grounds; centred-everything; rounded cards with shadows on every block; gradient heroes; emoji markers; accent rails on cards; generic three-column feature grids; decorative numbers; stock "trust badges".

## 7. Delivery

- Claude implements the system on the local homepage-v4 copy (style tokens, shell, homepage sections, archive list + detail templates, blog/about/pipeline/performance pages restyled) - local only, no deploy.
- Astra reviews as co-designer against this brief and the skill principles, delivers critique + refinements + the funnel in the new system.
- OWNER sees both at http://127.0.0.1:8772/ and decides; deploy stays behind the Mission-Control card.
