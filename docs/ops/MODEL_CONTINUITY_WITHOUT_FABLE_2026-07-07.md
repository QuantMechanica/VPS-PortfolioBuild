# Model Continuity — Running QuantMechanica Without the Fable Model

**Date:** 2026-07-07 · **Author:** Claude · **Trigger:** OWNER order 2026-07-07
("bereite alle Prozesse so auf, dass sie auch ohne das Fable Modell funktionieren")

## 1. Principle

The company is designed so that **model quality never decides strategy outcomes**.
The deterministic Q00–Q14 gate pipeline, the capability router, and the scheduled
automations judge EAs on evidence (CSV / report / log paths). LLMs supply
*judgment work* — reviews, synthesis, cards, ops decisions — and every judgment
that touches money is already double-gated (codex adversarial review per R21;
OWNER written approval for admissions and T_Live). Losing the premium model
therefore degrades **speed and depth of synthesis**, never gate integrity.

## 2. Verified inventory (2026-07-07)

Grep evidence: zero `fable` strings in executable code or configs anywhere in
the repo (only prose mentions in docs/cards). Model consumers:

| Consumer | Model source | Fable dependency |
|---|---|---|
| All `QM_StrategyFarm_*` scheduled tasks (pump, tick, health, cockpit, watchdog, quota governor, pulses, purges, router) | Pure Python/PowerShell | **None** — no LLM at all |
| Headless Claude lane (`run_agent_orchestration_task.py`) | `QM_CLAUDE_HEADLESS_MODEL` env, default `"sonnet"` (line ~61) | **None** (Sonnet 5 since 2026-07-03, Rule 24) |
| farmctl build/review/research spawns (`_claude_env`) | `QM_CLAUDE_HEADLESS_MODEL` env, default `"claude-sonnet-5"` (farmctl.py ~449) | **None** |
| `r_eval_drain.py` (R-field evaluation) | Sonnet, quota-guarded ≤85% | **None** |
| Codex lane (builds spot-checks, FTMO screens) | `gpt-5.5` (ChatGPT account) | **None** — different vendor |
| agy lane (video mining, legacy "gemini" lane name) | agy CLI, Gemini-family | **None** — different vendor |
| `prompts/autonomous_loop.md` + `autonomous_wake.ps1` | Dormant (no installed scheduled task); prompt text made model-neutral 2026-07-07 | **None** |
| **Interactive premium session** (reviews, synthesis, cards, OWNER reports, orchestration decisions) | Fable 5 today | **The only Fable consumer** |

Conclusion: infrastructure and lanes are already Fable-free. Continuity work =
making the *interactive session's duties* executable by any capable model.

## 3. Duty catalog of the interactive session — and the Fable-free procedure

| Duty | Procedure without Fable | Guardrail that keeps quality |
|---|---|---|
| Review close-outs (`agent_router.py list-tasks --agent claude` → `close-review`) | Same CLI flow on a Sonnet session. Checklists in `skills/`; verdicts must cite artifact paths. | R21 SELF_REVIEW: anything self-built gets a codex adversarial review before reliance. |
| Strategy-card synthesis (charter → synthesis doc → card) | Follow the existing chain: agy/codex extraction dossier (with timestamped citations) → card template in `artifacts/cards_approved/`. Prebuild validation + Q02 are the real acceptance. | Cards are cheap, backtests are free — a weaker synthesis model produces more Q02 FAILs, not bad live EAs. Honesty rules for video mining are in every ticket brief. |
| OWNER decision surface | Maintain `D:\QM\reports\state\owner_decisions.json` (contract documented in cockpit v6, commit b9548d7f0): new OWNER decision → add item; decided → remove. Cockpit renders it deterministically. | Schema is trivial; any model or even manual edit works. |
| Weekly admission sessions (Q12) | Ratified process docs + evidence chain (weights recomputed in-session, recompile-before-session, KS_BOOK_TAG_SET proof per rebuilt book EA — see week-28 checklist). | OWNER approves in writing regardless of model (Hard Rule). |
| T_Live verification | Deterministic checklist: SHA256 match, magic registry (`ea_id*10000+slot`), set ENV/risk-mode, news calendar fresh. | "OWNER + Claude only" is an **authority** rule, not a model-tier rule; any Claude session can execute the checklist. |
| Deep multi-lane audits (Fable-tag class, 2026-07-06) | Decompose into lane charters routed as `agent_tasks` (the 07-06 audit ran as 7 parallel lanes + verify + register — the pattern is the process, not the model). | Adversarial verify stage is mandatory for CRITICAL findings. |
| OWNER "Update?" reports | `quota_pull.py` + cockpit + standard format (memory: feedback_owner_update_format). | Format is documented; content is mechanical reads. |

## 4. Failure modes and what actually happens

- **Fable unavailable, Sonnet available:** run the same duties on Sonnet
  (interactive or headless). Expect smaller work chunks and more conservative
  judgment calls. Mandatory codex spot-check on anything touching live/money
  (already the R21 rule — no new process needed).
- **All Anthropic models unavailable:** factory, backtests, router, pulses,
  cockpit keep running (no LLM involved). Claude-lane tasks queue in
  TODO/REVIEW — safe by design: **nothing auto-approves**; the pipeline never
  promotes on a missing review. Codex can take `code`/`review` capability
  tasks; agy keeps research/video. T_Live stays untouched (AutoTrading changes
  need OWNER anyway).
- **Model switch (new Anthropic tier):** set `QM_CLAUDE_HEADLESS_MODEL`
  (machine env) — the only two defaults live in
  `run_agent_orchestration_task.py` (~line 61) and `farmctl.py` `_claude_env`
  (~line 449). Verify with one headless spawn
  (`farmctl.py` build lane or a 15-min `QM_StrategyFarm_ClaudeOrchestration_15min`
  slot) before relying on it.

## 5. Standing rules that make this safe (no change needed)

1. Gates are conservative and may never be loosened toward "accuracy"
   (OWNER, DL-071/072/073) — a weaker model inherits strict gates.
2. Evidence over claims binds every actor — verdicts without artifact paths
   are invalid regardless of which model wrote them.
3. Money gates (challenge purchase, admissions, T_Live AutoTrading) = OWNER
   in writing. Model changes cannot leak into live risk.
4. Research honesty rules (transcript-cited timestamps, GAP marking,
   BLOCKED_SOURCE_ACCESS) live in the ticket briefs, not in the model.

## 6. Open items

- Vault (`G:\My Drive\...`) operator-runbook sweep for stale `D:\QM\data\halt`
  references — needs a qm-admin session (G: is a per-user mount); folded into
  the week-28 checklist.
- `prompts/autonomous_loop.md` identity line neutralized in this commit; the
  autonomous-wake task itself remains decommissioned.
