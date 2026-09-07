# QuantMechanica Website Design Integration v1.0

## Source of truth

Use:
- `quantmechanica-design-tokens.css` for CSS variables;
- `quantmechanica-components.css` for the baseline component grammar;
- `quantmechanica-design-tokens.json` for chart libraries and design tooling.

Do not create a second, unrelated “software blue” design for the trading platform. The website and Strategy Console are one brand system.

## Website hierarchy

### Navigation
- maximum content width: 1240 px;
- restrained 64 px navigation;
- QuantMechanica wordmark left;
- 4-6 primary navigation items maximum;
- avoid CTA overload in the top bar.

### Hero
- eyebrow: `SYSTEMATIC · TESTED OPENLY`;
- one large editorial headline;
- one proof-oriented body paragraph;
- one primary green CTA;
- one secondary text link;
- use actual strategy/validation evidence in the supporting area where possible.

`The Quantitative Edge.` is a campaign/hero line, not an EA/product name.

### Evidence sections
Prefer:
- real counts;
- real test-stage outcomes;
- actual Strategy Console screenshots;
- actual backtest/report artifacts;
- methodology and limitations.

Avoid:
- generic trading photography;
- glowing terminals;
- fake institutional dashboards;
- “AI-powered”, “smart money” or “institutional grade” language without real implemented evidence.

## Chart grammar

Website charts should reuse the same semantic grammar as MetaTrader:
- same candle colors;
- same range colors;
- same direct-label approach;
- no decorative indicator overlays;
- illustrative/synthetic charts must be clearly labeled as illustrative;
- real strategy evidence should be visually distinguishable from illustration.

## Responsive behavior

Desktop:
- content max 1240 px;
- editorial whitespace is intentional but should support proof, not emptiness.

Tablet/mobile:
- stack content;
- reduce chart annotations before reducing text below readable sizes;
- minimum interactive target ~44 px;
- no horizontal card grids that require precision swiping to understand core evidence.

## Accessibility

- normal body text should meet WCAG AA contrast;
- status is never communicated by color alone;
- focus states are visible;
- respect `prefers-reduced-motion`;
- avoid text baked into images for essential content.

## Tone

Use:
- mechanical;
- systematic;
- evidence-led;
- precise;
- calm;
- transparent about limitations.

Do not use:
- hype;
- urgency;
- casino vocabulary;
- unexplained “alpha” claims;
- pseudo-institutional jargon.
