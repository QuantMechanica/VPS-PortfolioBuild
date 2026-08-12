# Effort/Model Matrix — 5×-Plan Era (OWNER-approved 2026-08-03, "passt")

Binding configuration input for router ticket `9dd1f1f8` (pre-spawn quota gate).
Supersedes the blanket "Sol max, never revert" directive of 2026-07-28 — that
directive was correct for the large-plan era; this matrix is its 5×-plan form.
Effective: Codex 5× from 2026-08-08, Claude 5× from ~2026-08-15.

## Codex (gpt-5.6-sol) — `model_reasoning_effort` by task class

| Effort | Task class |
|---|---|
| `max` | contracts / fail-closed logic, ANY change to runtime-decision-bound files, root-cause forensics, adjudications. NON-NEGOTIABLE — a first-pass max run here is cheaper than two lower runs plus double review. |
| `high` | ordinary code with tests, EA builds (guardrails + compiler catch defects), evidence tooling |
| `medium` | mechanical edits, census/report scripts, doc mirroring |

## Claude headless — `QM_CLAUDE_HEADLESS_MODEL`

| Model | Task class |
|---|---|
| `sonnet` (default) | build lane, templated/spec-driven work, small fully-specified tasks |
| `opus` | genuine weighing headless: strategy critique, synthesis, gate-design prework — deliberate per-task choice, never a default (draws the same weekly window ~5× faster) |

Hardest reasoning stays in the interactive premium session (Claude).

## Principles (rank above the tables)

1. **Escalate-on-failure beats default-high**: first attempt at the cheapest
   plausible tier; if the ≥90% review loop rejects, retry exactly one tier
   higher. The review loop (builder ≠ approver) is the quality net that makes
   this safe.
2. **Volume is paced, depth is not**: the quota gate defers/queues tasks — it
   never lowers the effort tier below this matrix for the task's class.
3. Backtests and deterministic no-LLM work are never gated (standing invariant).

Config consumers: the pre-spawn gate's JSON config (ticket 9dd1f1f8) must encode
these classes/tiers verbatim; router dispatch composes the invocation from it.
