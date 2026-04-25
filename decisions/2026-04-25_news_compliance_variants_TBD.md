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

## Recommended Resolution (Board Advisor, 2026-04-26)

**Hybrid A + C: expand P8, gate at P9.**

Rationale:

- P8 is already a per-EA mode-selection harness. PAUSE / SKIP_DAY are conceptually the same shape as a prop-firm news blackout — same EA, same data, different rule set. Building a parallel P8b just to relabel them duplicates infrastructure.
- But filtering decisions are portfolio-level, not per-EA-level. A sleeve that fails FTMO news rules is still valid for a non-FTMO target. So the *gating* belongs in P9 Portfolio Construction where the deploy-target is known.

Concrete shape:

1. **P8 expands** the mode set:
   - existing: `OFF`, `PAUSE`, `SKIP_DAY`
   - additive: `FTMO_PAUSE`, `5ers_PAUSE`, `no_news_only`, `news_only`
2. **P8 output per sleeve**: per-mode performance row + per-firm pass/fail compliance flag.
3. **P9 admission rule**: portfolio admission is per-deploy-target. A basket targeted at FTMO admits only sleeves with `FTMO_PASS = true` at the chosen mode. The mode itself is part of the deploy manifest.
4. **No P8b phase**, no P9 schema change beyond the admission filter.

Sub-decisions still required from OWNER before this can ship:

1. First-wave deploy targets (FTMO? The5ers? DarwinexZero only?). Drives which `*_PAUSE` modes are mandatory in P8.
2. Whether news-impact tier metadata in `D:\QM\data\news_calendar\` is sufficient for FTMO/5ers tiering. CTO + Quality-Tech sign-off.
3. ~~Whether existing `run_news_impact_tests.py` can ingest a per-firm rule-set config, or needs extension.~~ **RESOLVED 2026-04-26**: Codex confirmed the runner does not exist; V4 P8 was hand-orchestrated from raw MT5 CSV output. V5 builds news-impact tooling from scratch as part of the V5 EA framework (see `framework/V5_FRAMEWORK_DESIGN.md` § QM_NewsFilter.mqh and the `framework/include/news_rules/{ftmo,5ers}.mqh` files). The Hybrid A+C architecture is therefore implemented natively — no porting effort, no constraint from a legacy runner.

## Decision

Status remains **open / TBD**. Recommended resolution recorded above. Pipeline spec stays at the canonical P8 mode-selection definition until OWNER confirms the recommended resolution and the three sub-decisions are answered.

## Sources

- OWNER conversation 2026-04-25 (Board Advisor session)
- `docs/ops/PIPELINE_PHASE_SPEC.md`
- `docs/ops/CANONICAL_LAPTOP_STATE_2026-04-25.md`
- Laptop: `Company/Results/SM_221_P8_NEWS_IMPACT_20260418.md`
