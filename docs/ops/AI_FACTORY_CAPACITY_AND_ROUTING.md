# AI Factory Capacity & Routing

Status: active · Decision basis: `OWNER-DEC-D3-20260915` (third OWNER directive
2026-09-15 — MAXIMUM FACTORY UTILIZATION / DYNAMIC AI ROUTING), §2, §5–§10, §36,
§43A. Verbatim: `docs/ops/evidence/2026-09-15_continuous_book_evolution/owner_directive_3_max_factory_utilization_verbatim.md`.
Decision record: `decisions/2026-09-15_owner_max_factory_utilization_eligibility_v2.md`.

This page has **two parts** the directive requires to stay separate (§36):

- **CONTRACT** — hand-written policy. What each provider *may* do, the risk
  classes, routing/pacing/review policy, and the capability-expansion mechanism
  with its never-granted list. Changes here are deliberate policy edits.
- **CURRENT RUNTIME STATE** — machine-generated from
  `D:/QM/reports/state/ai_capacity.json` (`qm.ai-capacity/v1`) by
  `tools/strategy_farm/ai_capacity_readmodel.py render`. Never hand-edit inside
  the generated markers.

The vault mirror is `02 Org/AI Factory Capacity & Routing.md` — same two-part
structure, same generated runtime block.

---

## CONTRACT

### Providers, lanes and model tiers

Source of truth for capabilities/cost_rank/max_parallel:
`tools/strategy_farm/agent_router.py:DEFAULT_AGENT_REGISTRY`. Model/tier ids:
`config/agent_chain.v1.json` (per-vendor) and `config/agent_quota_gate.v1.json`
(Codex tiers, Claude models). The router lane name for Antigravity is the legacy
`gemini` (it executes via the `agy` CLI — CLAUDE.md).

| Provider | Lane | Model tiers (id) | cost_rank | max_parallel | Governor |
|---|---|---|---|---|---|
| Claude (Fable/Opus/Sonnet/Haiku) | `claude` | opus, sonnet, haiku | 30 | 3 | `quota_governor.py` → `CLAUDE_DISABLED.flag` |
| Codex (Astra/Sol/Terra/Luna) | `codex` | gpt-6-astra (scalpel), gpt-5.6-sol (deep), gpt-5.6-terra (standard), gpt-5.6-luna (bulk) + legacy gpt-5.5/5.4/5.4-mini | 20 | 5 | `quota_governor.py` + `codex_budget_line.py`/`codex_fleet_pacer.py` → `CODEX_LOW_TOKENS.flag` |
| Antigravity (agy) | `gemini` | default (Gemini Code Assist) | 10 | 2 | `agy_governor.py` → `AGY_LOW_QUOTA.flag` |
| Kimi | `kimi` | kimi-for-coding, k3, k3-256k | 12 | 1 | `kimi_governor.py` → `KIMI_LOW_QUOTA.flag` |
| OWNER (human) | `owner` | — | 99 | 0 | declared-but-disabled; holds `video_analysis` |

Note (§2): provider aliases and model mappings are **not permanent** — the
runtime read-model always reflects the live registry/config, not this table.

### Allowed capabilities (current contract)

- **Claude / Codex** — full software-engineering set: `code`, `tests`,
  `repo_edit`, `repo` (claude), `ops`, `review`, `research`, `strategy`,
  `summary`, `scalpel_mechanization`. Codex is the default execution worker;
  Claude/Fable is premium reasoning + the orchestrator.
- **Antigravity (agy)** — `research`, `strategy`, `source_discovery` (primary);
  `code`/`tests`/`repo_edit` are *declared* on the lane but treated as
  unproven (49/50 negative build wave 2026-08-21) — an expansion decision, not a
  default. Broad research, source discovery, strategy-idea mechanization; a
  valuable independent cross-vendor critic when it has spare capacity (§10).
- **Kimi** — research-only by `OWNER-DEC-KIMI-INTEGRATION-20260915`:
  `research`, `strategy`, `summary`, `source_discovery`, `deep_research`,
  `long_context_synthesis`, `edge_discovery`, `cross_experiment_analysis`,
  `research_review`, `research_critic`, `hypothesis_authoring`, `ml_research`.
  **No** `code`/`tests`/`repo_edit`/`ops` capability and no verdict-write path.
  A Kimi-authored hypothesis always gets a non-Kimi critic; Kimi is never a
  formatter and never critiques Kimi.
- **OWNER** — `video_analysis` (held as `awaiting_human_lane:owner`) plus
  research/strategy/review/summary so a video-tagged research ticket resolves to
  the human lane rather than the unroutable path.

### Task-risk classes (§6)

- **LOW** — docs, deterministic data transforms, small isolated functions,
  simple tests, generated read-models, obvious bugs with a regression test.
  Route to **any** provider/model with proven capability and spare capacity.
- **MEDIUM** — strategy implementation, larger Python modules, MQL5 strategy
  logic, DB migrations, portfolio tooling. Use a provider with strong measured
  performance; require tests and suitable review.
- **HIGH** — gate semantics, evidence contracts, portfolio risk engine,
  execution framework, live-readiness logic. Use the strongest suitable
  provider/model + independent cross-provider review.
- **OWNER / LIVE** — remains OWNER-controlled where existing authority requires
  it (T_Live, AutoTrading, purchases, deployment, gate thresholds, book build).

### Routing policy (§7, §8)

- **Model tier matches task difficulty** (§7): do not spend the most capable
  model on mechanical work another model reliably solves; do not put genuinely
  hard architecture/research on a small model just because quota is free.
- **Shadow price** (§8): remaining quota has changing opportunity cost. The
  read-model computes a **shadow price** per provider =
  `fleet_median_sustainable_burn / provider_sustainable_burn`, where
  `sustainable_burn = remaining_pct / hours_to_reset`. Shadow price **> 1** =
  scarcer than the fleet (offload its work away); **< 1** = spare (a good
  offload target). Do not let a preferred provider consume scarce quota on work
  a qualified spare provider can do; conversely do not burn Kimi/agy calls on
  filler just to reach "100% usage" — the target is **maximum useful value
  before each reset**, never vanity utilization.

### Pacing policy (§9)

- Re-measure through the authoritative governors **only** (`quota_governor.py`,
  `codex_budget_line.py`, `agy_governor.py`, `kimi_governor.py evaluate`) — never
  a stale snapshot, never a hand-edited flag. A flag is cleared **only by the
  governor that owns it**; the read-model reports, it does not reconcile.
- Optimize expected useful throughput across the reset period — neither hoard
  quota nor consume everything immediately and starve later critical work.
- **Backtests are never throttled** (they cost $0 agent tokens).
- Fable may adjust provider pacing within these rules without routine OWNER
  approval; versioned + reversible changes only.

### Review-independence policy (§10)

- Underused providers are most valuable as **independent critics**. Prefer true
  cross-vendor diversity; a same-vendor critic (`cross_vendor=false`) is a
  quota-gated last resort and *reduces* independence.
- The critic for a deliverable is resolved from a **different vendor** than the
  creator (`config/agent_chain.v1.json:roles.critic.by_creator_vendor`); Kimi is
  never the critic of a Kimi creator and never a formatter.
- Track creator vendor, critic vendor, same-vendor share, critic quality and
  correction yield. Independence is useful only if critique quality is real.

### Capability-expansion mechanism (§5) — evidence-gated, reversible

A currently research-restricted provider (Kimi) or an unproven lane (agy code)
may be granted additional **scoped** capabilities — `code_small`, `tests_small`,
`repo_edit_scoped`, `documentation`, `readmodel`, `review` — **only** after the
AI capability benchmark (slice b1, `AI_CAPABILITY_BENCHMARK_2026-09.md` →
`AI_CAPABILITY_SCORECARD`) demonstrates reliable performance for that task class.
Every such grant stays **reversible, branch/worktree-isolated, path-scoped,
test-gated, and independently reviewed when material**, recorded as a versioned
decision.

**NEVER granted through this mechanism (unchanged boundaries):**

- T_Live authority · AutoTrading authority · financial purchase authority ·
  unrestricted production ops · verdict manipulation/write path · evidence
  deletion · gate-threshold or book-construction authority · live deployment.

These remain OWNER-only (ROT) regardless of any benchmark result.

---

## CURRENT RUNTIME STATE

<!-- BEGIN GENERATED ai-capacity (qm.ai-capacity/v1) -->

_Generated `2026-09-15T17:51:21Z` from `D:/QM/reports/state/ai_capacity.json` (schema `qm.ai-capacity/v1`). Regenerated by `tools/strategy_farm/ai_capacity_readmodel.py render`; do not hand-edit inside the markers._

| Provider | Lane | Enabled | Auth | Routable | Window | Used | Remaining | h→reset | Pacing | Shadow price | Indep. review |
|---|---|---|---|---|---|---|---|---|---|---|---|
| claude | claude | True | True | False | weekly | 100% | 0% | 52.14 | THROTTLED_HEADLESS_LANE | 9999.0 | False |
| codex | codex | True | True | False | weekly | 80% | 20% | 86.63 | THROTTLED | 1.856 | False |
| agy | gemini | True | True | True | rolling_binding | 14.5% | 85.5% | 3.58 | NORMAL | 0.018 | True |
| kimi | kimi | True | True | True | rolling_7d | 0% | 100% | 159.68 | NORMAL | 0.684 | True |
| owner | owner | False | N/A | False | — | None | None | — | HUMAN_LANE_DISABLED | NOT_EVALUATED | False |

Fleet median sustainable burn: `0.4286` %/h. Shadow-price formula: sustainable_burn_pct_per_hour = remaining_pct / max(hours_to_reset, eps); fleet_median = median over auth_ok providers with a measurable quota; shadow_price = fleet_median / max(sustainable_burn_pct_per_hour, eps). >1 scarce (offload its work away), <1 spare (good offload target).

**Offload opportunities (16):**
- `code`: saturated **claude** → spare ['agy'] — AWAITING_BENCHMARK (slice b1 AI_CAPABILITY_SCORECARD)
- `ops`: saturated **claude** → spare ['agy', 'kimi'] — AWAITING_BENCHMARK (slice b1 AI_CAPABILITY_SCORECARD)
- `repo`: saturated **claude** → spare ['agy', 'kimi'] — AWAITING_BENCHMARK (slice b1 AI_CAPABILITY_SCORECARD)
- `repo_edit`: saturated **claude** → spare ['agy'] — AWAITING_BENCHMARK (slice b1 AI_CAPABILITY_SCORECARD)
- `research`: saturated **claude** → spare ['agy', 'kimi'] — ACTIONABLE (spare provider already holds this capability in-contract)
- `scalpel_mechanization`: saturated **claude** → spare ['agy', 'kimi'] — AWAITING_BENCHMARK (slice b1 AI_CAPABILITY_SCORECARD)
- `strategy`: saturated **claude** → spare ['agy', 'kimi'] — ACTIONABLE (spare provider already holds this capability in-contract)
- `summary`: saturated **claude** → spare ['kimi'] — ACTIONABLE (spare provider already holds this capability in-contract)
- `tests`: saturated **claude** → spare ['agy'] — AWAITING_BENCHMARK (slice b1 AI_CAPABILITY_SCORECARD)
- `code`: saturated **codex** → spare ['agy'] — AWAITING_BENCHMARK (slice b1 AI_CAPABILITY_SCORECARD)
- `ops`: saturated **codex** → spare ['agy', 'kimi'] — AWAITING_BENCHMARK (slice b1 AI_CAPABILITY_SCORECARD)
- `repo_edit`: saturated **codex** → spare ['agy'] — AWAITING_BENCHMARK (slice b1 AI_CAPABILITY_SCORECARD)
- `research`: saturated **codex** → spare ['agy', 'kimi'] — ACTIONABLE (spare provider already holds this capability in-contract)
- `scalpel_mechanization`: saturated **codex** → spare ['agy', 'kimi'] — AWAITING_BENCHMARK (slice b1 AI_CAPABILITY_SCORECARD)
- `strategy`: saturated **codex** → spare ['agy', 'kimi'] — ACTIONABLE (spare provider already holds this capability in-contract)
- `tests`: saturated **codex** → spare ['agy'] — AWAITING_BENCHMARK (slice b1 AI_CAPABILITY_SCORECARD)

Review independence: 5 completed chains, same_vendor_share=`0.8`, degraded=`True`.

<!-- END GENERATED ai-capacity -->
