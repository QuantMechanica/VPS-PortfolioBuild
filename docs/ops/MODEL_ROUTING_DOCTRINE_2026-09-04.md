# Model Routing Doctrine — 2026-09-04

Status: CEO doctrine under the standing authorization (OWNER 2026-08-20), commissioned by
OWNER 2026-09-04 ~01:10Z ("use every tool we have, correctly, within its weekly and 5h
limits; Codex Astra becomes available in the next hours/days"). Routing is an operating
rule, not a gate criterion: nothing here touches Qxx thresholds, verdicts, T_Live or
money. Those stay ROT.

Authority order for a routing decision: (1) explicit OWNER instruction for the task,
(2) the router payload (`codex_model_tier`, `codex_reasoning_effort`,
`claude_headless_model`), (3) the task class defaults below, (4) the 5h/weekly budget
state (`quota_spawn_gate.py`, `quota_governor.py`, `agy_governor.py`).

## 1. Seats and their limits

### Codex (OpenAI) — message allowance per 5h window (OWNER table 2026-09-04)

| Model            | Plus        | Pro 5x        | Pro 20x         | Tier role in QM |
|------------------|-------------|---------------|-----------------|-----------------|
| GPT-6 Astra      | 3–30        | 15–150        | 60–600          | scalpel: hardest single problems |
| GPT-5.6 Sol      | 10–100      | 50–500        | 200–2,000       | deep implementation, contracts |
| GPT-5.6 Terra    | 25–200      | 125–1,000     | 500–4,000       | standard implementation + tests |
| GPT-5.6 Luna     | 250–2,000   | 1,250–10,000  | 5,000–40,000    | bulk mechanical edits, mirrors |
| GPT-5.5          | 15–80       | 75–400        | 300–1,600       | legacy fallback for Sol |
| GPT-5.4          | 20–100      | 100–500       | 400–2,000       | legacy fallback for Terra |
| GPT-5.4 mini     | 60–350      | 300–1,750     | 1,200–7,000     | legacy fallback for Luna |

Ranges are "messages per 5h"; the low end is the conservative planning figure. The active
plan tier is an OWNER fact that the repo does not know yet: the config field
`codex_plan_tier` defaults to `plus` (most conservative) until OWNER states the plan.
Weekly limits are separate and are steered by the quota governor; Codex weekly quota is
exhausted until the 2026-09-07 reset (OWNER 2026-09-03), so nothing is dispatched to any
Codex model before that reset.

### Claude (Anthropic)

| Model   | Seat                 | Role |
|---------|----------------------|------|
| Fable   | interactive CEO seat | orchestration, deep critique, review closures, OWNER Vorlagen, decisions under the standing authorization |
| Opus    | verified workflows   | counter-relevant implementation with adversarial verification (implement → refute → fix), forensics with two lenses |
| Sonnet  | headless lane        | measurement scripts, templated/spec-driven builds, doc mirroring, cheap bulk reads |

Weekly pacing after the 2026-09-03 20:00Z reset: depth over volume; verified Opus
workflows only where the result moves the counter or closes an OWNER decision.

### Antigravity / Gemini (Google)

Backup only (OWNER 2026-09-03: agy hallucinates). Allowed: cited web reads, source
discovery with mandatory citations, second-opinion summaries. Never: code that reaches the
repo without an Opus/Fable review, sole source of a verdict, video analysis (no video tool;
OWNER lane). Paced by `agy_governor.py` and `AGY_LOW_QUOTA.flag`.

## 2. Task classes → model tier

| Task class | Examples | Default seat | Codex tier when Codex is the seat | Effort |
|------------|----------|--------------|-----------------------------------|--------|
| SCALPEL | strategy mechanization from a vetted source into a Strategy Card with refutation criteria; root-cause diagnosis of a recurring infra class; adversarial verification of a change to claim/dispatch/verdict-adjacent logic; quantified second opinion on an OWNER Vorlage | Fable (own) or Astra | Astra, no automatic downgrade | max |
| DEEP_IMPL | fail-closed contracts, runtime-decision-bound files, adjudication tooling, gate-adjacent refactors | Opus workflow | Sol (fallback GPT-5.5) | max |
| STD_IMPL | ordinary code with tests, EA builds, evidence tooling, dashboards | Opus workflow or Terra | Terra (fallback GPT-5.4) | high |
| BULK | mechanical edits, census/report scripts, doc mirroring, set-file regeneration | Sonnet or Luna | Luna (fallback GPT-5.4 mini) | medium |
| RESEARCH | source discovery, literature sweeps, transcript extraction | Sonnet/Opus by complexity; agy backup | Terra for implementation-aware research | high |
| REVIEW_CLOSE | `review_ea`, `card_review`, `triage_failure` closures | Fable only | — | — |
| OWNER_TEXT | briefings, Vorlagen, decision receipts | Fable only | — | — |

Class resolution in the router: explicit payload field `codex_model_tier` wins; otherwise
the existing effort markers (`runtime_decision_bound`, `fail_closed_logic`,
`root_cause_forensics`, `adjudication`, `mechanical_only`, `doc_mirroring`) map max→Sol,
high→Terra, medium→Luna; `scalpel: true` or task type `strategy_mechanize_source` maps to
Astra. A task that requires Astra is held (routing reason `awaiting_model_window:astra`)
when the Astra 5h budget is spent — it is never silently downgraded, mirroring the
`awaiting_human_lane:owner` pattern.

## 3. Pacing rules (5h and weekly)

1. Per-model rolling 5h ledger of dispatched messages
   (`D:/QM/reports/state/codex_model_window_ledger.jsonl`). A dispatch is refused when the
   tier's planning budget (low end of the plan-tier range) × 0.8 is reached; the remaining
   20% is the interactive reserve for OWNER/CEO use of the same account.
2. Non-scalpel classes fall back one tier down (Sol→Terra→Luna, legacy columns as second
   fallback) when their tier is exhausted; the downgrade is recorded on the task
   (`model_tier_downgraded_from`) so the review knows what produced the artifact.
3. Weekly steering stays with `quota_governor.py`: ahead-of-pace throttles build/research
   lanes, never backtests. The 5h ledger is the fine control, the weekly state the coarse one.
4. Budgets are spent on the counter: an Astra message goes to a fully specified brief
   (inputs, acceptance test, refutation criterion, evidence paths). Astra never "explores";
   exploration is Sonnet/Terra work whose output becomes the Astra brief.
5. Parallelism per seat stays at the router registry values (`codex` max_parallel 5,
   `claude` 3, `gemini` 2); the model tier does not raise them.

## 4. Astra — planned use (first four weeks after availability)

1. **Strategy mechanization from vetted sources.** One Astra message per source from the
   34 ELIGIBLE harvest, SSRN and channel mines: input = source pointer + `strategy_farm`
   card template + hard rules; output = a Strategy Card with entry/exit/risk in V5 terms,
   parameter count, a frequency sanity check and an explicit refutation criterion. Fable
   reviews the card (`card_review` stays a Fable closure). Target: 5 cards/week while the
   ready-card reservoir is below 5.
2. **Second-opinion forensics.** For a recurring infra class after Fable's own forensics
   (drain-window arming, RAM-class misestimates, report-shell races): Astra gets the
   evidence bundle and must either refute the diagnosis or name the missing test.
3. **Adversarial verifier for claim-path merges.** Before Fable merges a worker/farmctl
   change that touches claim order, RAM admission or long-run caps, one Astra refutation
   pass on the patch + tests. Cheap insurance against the 2026-08/09 restart classes.
4. **Quantified Vorlage check.** OWNER Vorlagen with money attached (RAM upgrade, plan-tier
   choice) get one Astra pass on the arithmetic and assumptions before they go to OWNER.

Not for Astra: routine builds, mirrors, census scripts, reviews of ordinary code, anything
already covered by a green verified workflow.

## 5. Implementation contract (router/dispatcher wiring)

- Config: `tools/strategy_farm/config/agent_quota_gate.v1.json` `model_matrix.codex` gains
  `plan_tier`, `tiers` (model id, five-hour budget per plan tier, fallback tier, default
  effort) and `explicit_tier_payload_field: codex_model_tier`; validation in
  `quota_spawn_gate.py` stays fail-closed (`codex_model_matrix_incomplete`).
- Dispatch: `run_agent_orchestration_task.command_for` already emits `-m <model>` from the
  headless model contract; the contract resolves the tier → model id; the farmctl Codex exec
  site that omits `-m` is routed through the same contract.
- Ledger + refusal: spawn gate records each Codex dispatch with model id and refuses when
  the 5h budget is reached; refusal reasons are structured (`codex_tier_window_exhausted`).
- Tests cover: tier resolution precedence, hold-not-downgrade for Astra, fallback chain,
  ledger window arithmetic, config validation, dispatcher argv.
- Rollback: `QM_CODEX_MODEL_TIERS=0` restores the single-model behaviour (`gpt-5.6-sol`).

## 6. Open OWNER inputs

- Which Codex plan tier is active (Plus / Pro 5x / Pro 20x)? Until stated, `plus`.
- Whether Astra may be spent on new-strategy mechanization ahead of forensics when both
  compete in one 5h window (default: mechanization first while the reservoir is below 5).

## 7. Edge-discovery program (OWNER goal, 2026-09-04 ~02:00Z)

OWNER: Fable and Astra are the strongest models available; with the tick and news data
on hand (and more purchasable) they should find edges and design strategies and
frameworks that succeed on FTMO. That is the big goal. Doctrine consequence:

- The models design, the pipeline judges. Every hypothesis enters as a Strategy Card
  with a mechanical rule set, a parameter count, a frequency floor check and a written
  refutation criterion; Q02-Q13 remain the only verdict. No ML libraries in EAs.
- Raw ticks never go into a model context. Sonnet/Terra scripts compute the summary
  statistics a hypothesis needs (conditional returns, event-window behaviour, regime
  tables), written as CSV under `docs/research/`; Fable/Astra reason over those tables.
- Orthogonality over addition (long-term plan 2026-08-03): a new edge must be a new
  return source (sparse-D1 standard V4), not a variant of an existing survivor.
- Program owner: Fable (design, critique, refutation); Astra: one message per fully
  specified hypothesis brief; measurement: Sonnet headless. Commissioned as a router
  task on the Claude lane; the first deliverable is the data inventory plus five
  hypotheses with refutation criteria.

## 8. Implementation status (2026-09-04 07:00Z)

- Merged: b8c62c975a (rounds 1-3) and a769c2f5b8 (round 4) of wf_76cb7101-72e. Tier layer
  ACTIVE in `window_enforcement_mode: observe` (ledger records every Codex dispatch under
  `D:/QM/reports/state/codex_model_window_ledger.jsonl`; no refusals, holds or downgrades;
  effort-class remap opt-in via `effort_class_tier_mapping_enabled`, default false; untiered
  tasks keep `gpt-5.6-sol`). Decision-bound lane pinning (`owner_decision` /
  `decision_bound_agent` -> claude) and the `scalpel_mechanization` capability (codex +
  claude only) are unconditional router behaviour.
- Enforce mode is switched on only after (a) the OWNER states the Codex plan tier and
  (b) router task 453b8edf (enforce-mode preconditions) is APPROVED. Rollback of the whole
  tier layer: machine env `QM_CODEX_MODEL_TIERS=0`.
- CodexOrchestration scheduled task stays disabled until 2026-09-07 (weekly quota 93 %).
