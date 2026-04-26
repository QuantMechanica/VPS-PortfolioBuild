# Decision: News-rule-set compliance variants — ACCEPTED (Option A) 2026-04-26

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

## Decision (OWNER 2026-04-26)

**Option A pure: P8 expanded; P9 NOT compliance-gated.**

OWNER chose Option A over the Hybrid A+C recommendation. P8 carries the full mode set and produces compliance flags; P9 stays as designed (family cap 3, symbol cap 2, ENB + marginal Sharpe) and does NOT add a compliance pre-filter. Compliance information from P8 is consumed by humans / CEO when manifest decisions are made, not by P9 logic.

**Why this matters in practice:**

- The intelligence (per-mode performance + per-firm compliance flags) lives in P8 output where Quality-Tech and the manifest reviewer can see it.
- P9 stays simple — no per-deploy-target admission logic to maintain.
- A FTMO-target deploy is a manifest decision: CEO + LiveOps + OWNER read the EA's P8 output, choose the right mode, and stamp the manifest. Compliance is enforcement-by-manifest, not enforcement-by-pipeline.

**Sub-decisions still open** (non-blocking for the framework, blocking only for first FTMO/5ers manifest):

1. First-wave deploy targets — pending OWNER (likely DXZ-only first per the DXZ-live-only architecture)
2. News-impact tier metadata sufficiency for FTMO/5ers tiering — Quality-Tech sign-off when first FTMO manifest is drafted
3. ~~Whether existing `run_news_impact_tests.py` can be extended~~ — **resolved 2026-04-26**: V5 builds news-impact tooling natively in `framework/include/QM_NewsFilter.mqh`

## Implementation Implications

- `framework/V5_FRAMEWORK_DESIGN.md` § QM_NewsFilter.mqh already lists all 7 modes (`QM_NEWS_OFF`, `QM_NEWS_PAUSE`, `QM_NEWS_SKIP_DAY`, `QM_NEWS_FTMO_PAUSE`, `QM_NEWS_5ERS_PAUSE`, `QM_NEWS_NO_NEWS`, `QM_NEWS_NEWS_ONLY`) — **no change needed**.
- `framework/include/news_rules/{ftmo,5ers}.mqh` blackout-window definitions still TBD until first deploy target picked.
- `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md` § P8 stays as-is (mode-selection per sleeve). No P9 compliance-gating logic added.
- `docs/ops/PIPELINE_PHASE_SPEC.md` § P8 description stays "OFF/PAUSE/SKIP_DAY mode selection for deploy behavior" with a footnote that the V5 framework extends this to 7 modes covering prop-firm compliance.

## Sources

- OWNER conversation 2026-04-25 (Board Advisor session)
- `docs/ops/PIPELINE_PHASE_SPEC.md`
- `docs/ops/CANONICAL_LAPTOP_STATE_2026-04-25.md`
- Laptop: `Company/Results/SM_221_P8_NEWS_IMPACT_20260418.md`
