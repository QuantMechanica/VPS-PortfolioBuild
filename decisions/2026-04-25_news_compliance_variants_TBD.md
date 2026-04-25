# Decision: News-rule-set compliance variants — TBD

- Date: 2026-04-25
- Status: open / TBD
- Owner: OWNER + CTO
- Affected docs: `docs/ops/PIPELINE_PHASE_SPEC.md`

## Context

OWNER raised on 2026-04-25 that the V5 pipeline should test each EA against several news-handling rule sets:

- no trading on news days
- news-only trading
- FTMO news rules
- The5ers news rules
- (DarwinexZero rules)

The motivation is that EAs targeting prop-firm capital must be able to prove they pass each firm's news constraints, and that the project's deploy strategy may eventually multi-target several firms.

## Current Canonical State

Per `docs/ops/PIPELINE_PHASE_SPEC.md` and the laptop `doc/pipeline-v2-1-detailed.md`, P8 News Impact is a **mode-selection gate** for live deploy behavior:

- modes: `OFF`, `PAUSE`, `SKIP_DAY`
- output: which mode the sleeve ships with at deploy

The canonical P8 does not currently test against prop-firm-specific rule sets and does not produce per-firm compliance scores.

## Open Question

Where should the prop-firm compliance variants live?

1. **As sub-gates inside P8 News Impact.** P8 expands to also report `FTMO_PASS / 5ers_PASS / no_news_PASS / news_only_PASS` per sleeve. Smallest spec delta, but mixes mode-selection with compliance-labeling.
2. **As a new phase P8b News Compliance** between P8 and P9 Portfolio Construction. Cleanest separation; P9 can then admit only sleeves that meet the firms targeted for the next deploy wave.
3. **As a deploy-target rule-set layer in P9 Portfolio Construction.** Each portfolio admission resolves which rule sets the basket is shipped against; sleeves carry per-firm flags but no separate phase exists.

## What Needs To Happen Before A Decision

- OWNER specifies which firms are first-wave targets (FTMO, The5ers, DarwinexZero, others).
- CTO surveys each firm's published news rule (blackout windows, instrument scope, severity tiers).
- Quality-Tech evaluates whether the existing news calendar seed has the impact-tier metadata required for FTMO/5ers compliance scoring (FTMO classifies by impact level; current seed may need enrichment).
- R-and-D estimates how much of the existing P8 tooling (`run_news_impact_tests.py`) can be reused vs. rewritten.

## Decision

Park as TBD. Pipeline spec stays at the canonical P8 mode-selection definition until OWNER triggers the scoping work above.

## Sources

- OWNER conversation 2026-04-25 (Board Advisor session)
- `docs/ops/PIPELINE_PHASE_SPEC.md`
- `docs/ops/CANONICAL_LAPTOP_STATE_2026-04-25.md`
- Laptop: `Company/Results/SM_221_P8_NEWS_IMPACT_20260418.md`
