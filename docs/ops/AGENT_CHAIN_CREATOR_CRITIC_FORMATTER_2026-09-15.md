# Agent chain: Creator → Critic → Formatter with a cross-vendor critic (OWNER 2026-09-15)

OWNER 2026-09-15 ~06:5xZ: "Ist das bei uns bereits umgesetzt? Wenn nicht, etabliere es! Nutze die
verschiedenen Claude, Codex und Antigravity Modelle dafür!" — the three-stage prompt chain
(Creator = neutral synthesis, Critic = hyper-critical auditor with inverted prompting / pre-mortem,
Formatter = A. Zusammenfassung / B. Lücken & Handlungsbedarf), automated in the background, with the
critic on a **different model vendor** than the creator.

## 1 · What already existed (audit 2026-09-15 06:5xZ)

| Deliverable class | Creator | Automated critic | Cross-vendor? | Formatter |
|---|---|---|---|---|
| EA builds (`build_ea`) | Codex (`codex_build_ea.md`) | Codex mechanical pre-review (`codex_review_ea.md`) → Claude policy review (`claude_review_ea.md`) | yes (2nd stage) | none (verdict JSON) |
| Ops / research / report tickets (`ops_issue`, `research_*`) | Codex or Claude/Sonnet lane | **none** — the orchestrator (Claude) reviews in-session; same vendor whenever the creator was the Sonnet lane | no | none |
| Serious incidents | Claude + Codex independent forensics, then cross-review (OWNER directive 2026-08-05) | manual, ad hoc | yes | none |
| OWNER morning brief (`morning_brief.py`) | deterministic renderer (no LLM) | none | n/a | itself |
| Path-to-25 audit (`path25_red_team.py`) | deterministic read-only audit | n/a | n/a | n/a |
| Ultracode workflows (Review → Verify phases) | in-session only | in-session | same vendor | — |

The pipeline itself (Q02–Q14, DSR/FDR, activity criterion) is the deterministic "math engine": no
LLM computes a metric, and no LLM verdict changes a gate. The gap was the **generic, automated,
cross-vendor critic** for everything that is not an EA build.

## 2 · What is new

`tools/strategy_farm/agent_chain.py` (config `config/agent_chain.v1.json`, prompts
`prompts/chain/{creator,critic,formatter}.md`, tests `tests/test_agent_chain.py`, 15 tests).

| Command | What it does |
|---|---|
| `agent_chain.py run --spec <json> [--apply]` | Full chain over raw inputs: creator (default Claude Sonnet) → critic (cross-vendor) → formatter (Haiku). Optional bounded revision rounds (`max_rounds`): the creator must answer blocking/major findings before the formatter runs. |
| `agent_chain.py critique --task-id <id> [--apply] [--no-agy]` | Chain over an existing lane delivery (`agent_tasks` row): stage 1 = the delivered artifact, stage 2 = a critic from a different vendor than the executing lane, stage 3 = the A/B document the orchestrator reads **before** its own review. |
| `agent_chain.py critique-pending [--apply] [--max N]` | Bounded sweep over REVIEW rows without a receipt (default 2 per run; `review_ea` rows skipped because the build chain already covers them). |
| `agent_chain.py status` | Latest receipts. |

Default invocation is a **dry run**: seats and gates are resolved, the plan is written, no token is
spent. `--apply` spawns.

### Cross-vendor rule (config `roles.critic.by_creator_vendor`)

| Creator lane | Critic candidates, in order |
|---|---|
| claude (Sonnet/Opus lane) | codex `terra` medium → agy → claude `opus` (same vendor, different model, receipt says `cross_vendor=false`) |
| codex | claude `sonnet` → claude `opus` → agy |
| agy | claude `sonnet` → codex `terra` |
| unknown executor | codex `terra` → claude `opus` → agy |

A vendor is skipped when its gate is closed: `CLAUDE_DISABLED.flag`, `CODEX_LOW_TOKENS.flag`,
the Codex weekly budget line (`codex_budget_line.evaluate`, OWNER pacing rule 2026-09-13 — the chain
does not bypass it), `AGY_LOW_QUOTA.flag`, or a missing agy binary. Antigravity is a candidate but
never the sole design authority: its findings are verified like every other critic's (evidence
paths) and the orchestrator can exclude it per run with `--no-agy` (memory: agy hallucinates; use
as the third lens, not the first).

### Safety envelope

- Critic seats are **read-only**: Claude `-p --tools Read Grep Glob --disallowedTools Bash Edit Write …
  --permission-mode dontAsk --max-turns 40 --strict-mcp-config --mcp-config <empty>` (live finding
  07:1xZ: `--allowedTools` alone is NOT a cage when the user settings carry `defaultMode: auto`, and
  without `--strict-mcp-config` the headless run would load the Gmail/Notion/Dropbox connectors),
  Codex `exec --sandbox read-only`, agy confined to the chain directory and the repo via `--add-dir`.
  Timeouts kill the whole process tree (`taskkill /T`), because `proc.kill()` under `shell=True`
  only kills cmd.exe and leaves the CLI alive.
- The chain never writes to `agent_tasks`, verdicts, work items or the repo. Outputs live under
  `D:/QM/strategy_farm/artifacts/agent_chain/<chain_id>/` (prompts, stage outputs, `final.md`,
  `chain_receipt.json`), receipts under `D:/QM/strategy_farm/state/agent_chain/` (+ `tasks/<task_id>.json`).
- Every stage is bound: seat/vendor/model, sha256 of prompt and output, duration, cost (Claude), the
  input files with sha256 and existence, `cross_vendor` flag. Section C of `final.md` is generated by
  the runner, not by a model.
- Codex spawns go through `managed_codex.spawn_managed_codex` (ownership lease, dedupe key
  `agent_chain:codex`) like every other Codex process.
- Kill switch `QM_AGENT_CHAIN=0` (all seats gated, receipts say so). Timeouts per stage
  (`limits.stage_timeout_seconds`, 900 s).

### Critic contract

`prompts/chain/critic.md`: invert (assume wrong/incomplete, keep only evidenced arguments), pre-mortem,
verify every path/test/commit/count claim against files, hard-rule check, scope-drift check, logic
check. Output = short audit notes + one fenced JSON block (`qm.agent-chain.critic.v1`: verdict
PASS/GAPS/REJECT, findings with severity/claim/problem/evidence/check_performed/action,
unverifiable_claims, open_questions, scope_drift). The runner derives the verdict from the
severities (blocking → REJECT, major → GAPS) so a declared PASS cannot hide a blocking finding.

## 3 · How it is used from now on

1. **Every REVIEW delivery** of the Codex / Claude lanes gets a critique receipt before the
   orchestrator's review (`critique-pending`, scheduled every 15 min via
   `install_agent_chain_critique_scheduled_task.ps1`, SYSTEM → console session like the lanes). The
   orchestrator's review starts from `final.md` §B and the receipt's `cross_vendor` flag. The chain
   is an input to the review, never a verdict: closing a task stays the orchestrator's act.
2. **OWNER-facing documents** (sprint daily check, decision cards, audits): `run --spec` with the
   raw inputs; the OWNER receives A/B. First use: the book-sprint daily check of 2026-09-15.
3. **Serious incidents** keep the 2026-08-05 dual-forensics protocol; the chain adds the formatter
   and the receipt, it does not replace the independent second investigation.

## 4 · Honest state of the seats on 2026-09-15

| Seat | State at 07:0xZ | Consequence |
|---|---|---|
| Codex | `CODEX_LOW_TOKENS.flag` (governor throttle since 09-12) and weekly budget line exceeded (80.0 % vs 73.2 %); reset Fri 2026-09-19 08:29Z | no Codex critic until the line is back under the pace; Claude-lane deliveries fall to the same-vendor Opus critic (`cross_vendor=false`, visible in every receipt) |
| Antigravity | `AGY_LOW_QUOTA.flag` with `failure_class: token_expired` since 2026-09-15 05:40Z | **OWNER action:** re-authenticate agy once interactively (Windows Credential Manager `gemini:antigravity`); the governor releases the flag on the next successful quota pull ≥ 20 % |
| Claude | Sonnet/Opus/Haiku available (weekly 64 %) | creator + formatter + critic-of-Codex work now |

Decision the OWNER may want to take: exempt the critic's Codex calls (medium effort, a few thousand
tokens) from the weekly budget line (`codex_budget_line_exempt`) so the cross-vendor critic for
Claude-lane deliveries exists even in throttle weeks. Not done autonomously — the pacing rule is
OWNER-set (2026-09-13).

## 5 · Evidence

- Fake-mode proof (no tokens): `tests/test_agent_chain.py` — seat resolution, gates, receipts,
  revision bound, critique sweep selection, `agent_tasks` untouched.
- Live proof: see the "Live runs" addendum below (filled by the orchestrator after the first
  `critique --apply` and the first OWNER report chain).

## 6 · Live runs (addendum 2026-09-15 07:3xZ)

| Run | Seats | Result | Cost | Evidence |
|---|---|---|---|---|
| critique of dc7f0545 (Sonnet-lane export fix), attempt 1, 07:03Z | critic claude:opus (Codex/agy gated), formatter haiku | **aborted by the orchestrator**: the critic ran 27 tool calls incl. Bash (user settings `defaultMode: auto` overrode `--allowedTools`), then stalled 15 min without a tool call; the runner's 900 s cap never returned (`proc.kill()` under `shell=True` killed only cmd.exe) | ~2 USD | transcript session 393a0e6a; fix commit 2d1a98d485 |
| critique of dc7f0545, attempt 2, 07:16Z (hardened runner) | creator = delivered artifact (claude sonnet lane), critic claude:opus (`cross_vendor=false`, Codex over budget line, agy token expired), formatter claude:haiku | **ok**, verdict GAPS: 5 major + 5 minor; critic used only Read 11 / Grep 5 / Glob 3 in 20 turns, one Read outside the add-dirs denied by `dontAsk` (envelope verified) | critic 2.53 USD / 357 s, formatter 0.10 USD / 74 s | `docs/ops/evidence/2026-09-15_agent_chain/critique_dc7f0545_{final.md,receipt.json}`; runtime dir `D:/QM/strategy_farm/artifacts/agent_chain/critique_dc7f0545_20260915T071621Z/` |

Value of the second run: finding F1 (the FX completeness floor 0.20 lets the known-defective AUDCAD export classify COMPLETE: 155,802 bars vs floor 147,936) was missed by the orchestrator's own review two hours earlier; F3/F4/F5 (receipt does not carry the chunk journal, no per-chunk bar, sparse-10 relabeled SHORT_READ_GAP) are real contract gaps. All seven actionable findings went to Sonnet-lane ticket **9e0fb916** (round 2) before the T1 rerun receipt is trusted.

Operational consequence: the sweep task `QM_StrategyFarm_AgentChain_Critique_15min` is installed (max 2 critiques per run); receipts land under `D:/QM/strategy_farm/state/agent_chain/tasks/<task_id>.json` and the orchestrator reads `final.md` §B before closing any REVIEW row.
