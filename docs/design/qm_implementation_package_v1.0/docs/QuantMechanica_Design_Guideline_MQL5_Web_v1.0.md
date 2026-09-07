# QuantMechanica Design Guideline
## MQL5 Strategy Console + Website Design System v1.0

**Status:** Implementation baseline  
**Date:** 2026-09-07  
**Master brand:** QuantMechanica

---

# 1. Design objective

QuantMechanica must feel like a disciplined quantitative product, not like a typical retail-trading EA.

The premium impression is created by:
- restraint;
- information hierarchy;
- consistency;
- visible reasons behind states;
- credible evidence;
- excellent chart legibility;
- stable performance;
- precise language.

Premium does **not** mean:
- more indicators;
- more colors;
- more panels;
- glowing effects;
- pseudo-institutional terminology;
- “AI” labels without actual model logic;
- a cockpit full of telemetry.

The default user experience must answer three questions in under three seconds:

1. **What is the system doing now?**
2. **Can it trade now?**
3. **If not, why not / what happens next?**

---

# 2. Brand architecture

## Master brand
`QuantMechanica`

The wordmark can visually separate:
- `Quant` in Carbon/Ink;
- `Mechanica` in Quant Green.

## In-platform functional module
`STRATEGY CONSOLE`

This is a descriptor, not a second brand.

## Strategy title
A strategy carries its own descriptive title, e.g.:

`OHLC Daily Squeeze Reversal · D1`

## Marketing line
`The Quantitative Edge.`

Use as editorial/campaign copy, not as a product name.

## Brand proof line
`Systematic. Tested openly.`

Use selectively in website/console contexts where a short proof-oriented brand sentence is useful.

## Naming rule
Do not add codenames such as AXIOM unless QuantMechanica later operates a real commercial suite that needs multiple named product families.

---

# 3. Brand personality

QuantMechanica is:
- systematic;
- analytical;
- calm;
- technical;
- evidence-led;
- transparent;
- contemporary;
- high-trust.

QuantMechanica is not:
- flashy;
- aggressive;
- casino-like;
- mystical;
- “smart-money” cosplay;
- pseudo-institutional.

---

# 4. Language and microcopy

Product UI is English.

Preferred:
- `WAITING FOR SETUP`
- `TRADE BLOCKED`
- `Range · Valid`
- `Session · Trading open`
- `News · Clear`
- `Next evaluation in 12h 14m`

Avoid:
- `Everything looks good!!!`
- `Mega setup`
- `Smart Money detected`
- emoji in customer-facing status UI;
- long strategy explanations inside the dashboard.

## Reason-first rule

The badge is the conclusion. The useful content is the reason.

Preferred:
`Session · Trading open   PASS`

Less useful:
`Session   PASS`

Preferred:
`Spread · 0.6 pip   PASS`

Less useful:
`Spread   PASS   (0.6 pip <= configured maximum threshold of 2.5 pips)`

---

# 5. Core colors

| Token | Hex | Use |
|---|---|---|
| Carbon | `#171A21` | Primary text |
| Ink | `#0F172A` | Strong headings |
| Quant Green | `#0A8A5B` | Brand accent / primary CTA |
| Quant Green Dark | `#087247` | PASS text / accessible green |
| Slate | `#677185` | Secondary text |
| Muted | `#8B95A7` | Captions / tertiary |
| Cloud | `#F5F7F9` | Soft surface |
| Surface | `#FFFFFF` | Main background |
| Border | `#DCE2E8` | Hairline borders |
| Border Strong | `#C8D0DA` | Stronger panel boundary |
| Signal Blue | `#3B6CF6` | Information/current price |
| Positive | `#0B7A53` | Positive operational/trade state |
| Negative | `#B8454D` | BLOCK/loss/risk |
| Warning | `#996515` | Caution/stale state |
| Candle Up | `#0E9F7A` | Bull candle |
| Candle Down | `#F0545E` | Bear candle |
| Range Border | `#6B8FD8` | Strategy range |
| Range Fill | `#EDF3FF` | Strategy range fill |

Color is semantic. Red and green are not decorative.

---

# 6. Typography

## Website
Primary: `Inter`  
Fallback: `Segoe UI`, `Helvetica Neue`, `Arial`, sans-serif.

Hero display:
- 48-82 px responsive;
- bold;
- tight tracking;
- short line length.

Body:
- approximately 17-20 px for lead copy;
- around 16 px for standard body;
- 1.5-1.65 line height.

Eyebrow:
- 11-12 px;
- semibold;
- uppercase;
- letter-spaced.

## MetaTrader 5
Primary: `Segoe UI`  
Fallback: `Arial`

Use small, controlled differences in weight instead of too many font sizes.

---

# 7. Spacing and shape system

Base rhythm:
`4, 8, 12, 16, 24, 32, 48, 64, 96, 128 px`

Website:
- control radius: 8 px;
- card radius: 16 px;
- larger editorial surfaces: 24 px maximum;
- primary CTA can use pill radius.

MetaTrader:
- visually tighter;
- avoid excessive card nesting;
- 1 px separators are preferred over shadows;
- renderer remains realistic for MT5 object capabilities.

---

# 8. Strategy Console principles

## 8.1 Status first
The first major element is always the system state.

## 8.2 No duplicate strategy explanation
Do not create a permanent SETUP block if the primary state already communicates the current setup context.

## 8.3 State-adaptive content
Empty content does not reserve permanent space.

## 8.4 No fake controls
If a risk governor/filter does not actually exist in the EA, do not show it as if it were enforced.

## 8.5 Visibility != Logic
Display controls never change trading rules.

---

# 9. Strategy Console hierarchy

Default FULL mode:

1. QuantMechanica wordmark
2. `STRATEGY CONSOLE`
3. Strategy title + timeframe
4. Primary state card
5. Two-column Filter Gate
6. Risk
7. LIVE only when relevant
8. Today / Week strip
9. `© QuantMechanica` + version

No:
- license hash;
- login number;
- support instructions;
- fixed empty position/order slots;
- large technical heartbeat area;
- debug mode.

---

# 10. Dashboard modes

## FULL
Default customer monitoring view.

## COMPACT
Reduced panel for more chart space.

## MINIMAL
Brand + state + next meaningful event.

Switching modes affects presentation only.

---

# 11. Filter Gate

Two columns.

Structure:
`Label · concise context   STATE`

Use:
- PASS
- BLOCK
- WARN
- OFF
- N/A
- WAIT
- ERROR
- STALE

OFF is not PASS. N/A is not OFF.

For the exact OHLC Daily Squeeze Reversal EA, the gate contains only:
- News
- Pattern
- Session
- Range

No decorative HMM, Context or Spread gate is added unless actual logic exists.

---

# 12. Risk presentation

Generic design rule:
Only display risk data that is actually enforced or accurately derived.

For the exact EA v1.0:
- Next trade;
- Open exposure;
- Stop basis.

Open exposure is calculated to the actual SL using broker-aware profit calculation.

A Daily DD limit is not shown until a real daily-drawdown governor participates in trade admission.

---

# 13. Chart system

Default:
- white background;
- grid off;
- volumes off unless used;
- no decorative indicators;
- current price in Signal Blue;
- clean green/red candles.

Active strategy overlay:
- very soft active range;
- Range High / Low;
- Buy / Sell Trigger;
- Entry / SL / TP only when live;
- direct labels.

Historical setups:
- off by default;
- if enabled, visually de-emphasized.

---

# 14. ICT / SMC / SMT / indicators

Never add concepts simply because they look sophisticated.

Show only when an explicit tested component consumes the information:
- session boxes;
- PDH/PDL;
- liquidity sweeps;
- FVG;
- BOS/CHOCH;
- premium/discount;
- SMT divergence;
- EMA;
- Bollinger Bands;
- volume.

A marketing screenshot must not imply trading logic that the EA does not have.

---

# 15. MQL5 implementation architecture

Target architecture:

`Strategy / Filters / Risk -> structured QMDashboardSnapshot -> QMStrategyConsole renderer`

The renderer:
- does not parse strategy decisions from human-readable strings;
- does not call filters for display;
- does not change trade logic;
- does not perform expensive history traversal on every tick.

Reusable files:
- `QMDesignTokens.mqh`
- `QMDashboardModel.mqh`
- `QMStrategyConsole.mqh`

Compatibility:
- `StandardVisualization.mqh` remains as a thin adapter to avoid breaking the existing strategy dependency.

EA-specific identity and content:
- `QM_OHLCDailySqueezeReversal_Config.mqh`

---

# 16. MQL5 performance rules

- Completely bypass visualization in optimization.
- Update dashboard on timer and meaningful state/trade events.
- Do not run chart-history cleanup on every tick.
- Do not scan deal history on every tick.
- Cache Today/Week performance.
- Maintain visual range preview incrementally.
- Update existing objects instead of delete/recreate where possible.
- Group changes and redraw once.
- Keep all trading calculations independent of UI mode.
- Use tick-size/tick-value/broker-contract aware monetary calculations.

---

# 17. Website system

The website and EA are one brand, not two themes.

The current green editorial direction is the correct anchor. The Strategy Console should inherit its restraint rather than introduce a separate blue “software” brand.

## Header
- restrained navigation;
- max content width approximately 1240 px;
- QuantMechanica left;
- 4-6 primary nav items;
- no crowded button stack.

## Hero
- eyebrow: `SYSTEMATIC · TESTED OPENLY`;
- one strong headline;
- one proof-oriented paragraph;
- one primary green CTA;
- one secondary text link.

Use whitespace intentionally. Empty space should create hierarchy, not hide a lack of evidence.

---

# 18. Website evidence design

QuantMechanica should sell through proof.

Preferred:
- public strategy archive;
- real evaluation counts;
- gate reached / pass-fail;
- actual strategy pages;
- actual backtests;
- actual Strategy Console screenshots;
- methodology;
- costs/slippage assumptions;
- out-of-sample evidence;
- limitations.

Avoid:
- lifestyle finance imagery;
- laptop-on-desk stock photography;
- neon trading visuals;
- generic “institutional” claims;
- enormous equity curves without methodology.

---

# 19. Website charts

Website and MT5 chart semantics must match:
- same candle colors;
- same range colors;
- same direct labels;
- same positive/negative semantics.

Illustrative charts:
- explicitly label as illustrative/synthetic.

Real charts:
- present as evidence and include enough context to interpret them.

Do not make illustrative charts look more authoritative than real test evidence.

---

# 20. Website responsive rules

Desktop:
- 1240 px max content;
- generous but purposeful whitespace;
- 12-column thinking is acceptable, but content hierarchy is more important than a visible grid.

Tablet/mobile:
- stack;
- remove secondary chart labels before making core text tiny;
- 44 px approximate interactive target;
- avoid horizontally compressed multi-card evidence tables;
- core claims and proof must remain readable without hover.

---

# 21. Accessibility

- WCAG AA contrast for normal text.
- Status is never color-only: always include PASS/BLOCK/etc.
- Visible keyboard focus.
- Respect reduced motion.
- Avoid essential copy baked into screenshots.
- Provide text alternatives/captions for platform screenshots on the website.

---

# 22. Premium quality gate

A release is not premium because it has more features. It is premium when:

- the current state is obvious;
- blocking reasons are clear;
- every displayed metric is truthful;
- the chart is calm;
- no empty telemetry slots exist;
- the UI does not slow the EA;
- the website uses the same visual grammar;
- test evidence is reproducible;
- naming is consistent;
- customer-facing language is precise.

---

# 23. Source of truth

Cross-platform:
- `website/quantmechanica-design-tokens.json`

Website:
- `website/quantmechanica-design-tokens.css`
- `website/quantmechanica-components.css`

MQL5:
- `mql5/Include/QMDesignTokens.mqh`
- `mql5/Include/QMDashboardModel.mqh`
- `mql5/Include/QMStrategyConsole.mqh`

Exact EA:
- `mql5/Include/QM_OHLCDailySqueezeReversal_Config.mqh`
- `docs/QuantMechanica_OHLC_Daily_Squeeze_Reversal_EA_Spec_v1.0.md`

---

# 24. Governance

Treat design tokens like code.

Before adding a new color, state, card, chart marker or name:
1. check whether an existing token/component already solves it;
2. identify the actual product meaning;
3. verify it exists in trading logic if it appears on a strategy chart;
4. update MQL and web tokens together if semantic color meaning changes;
5. document the change.

Visual-only changes must be identified as visual-only in release notes and must not be mixed with strategy-performance claims.
