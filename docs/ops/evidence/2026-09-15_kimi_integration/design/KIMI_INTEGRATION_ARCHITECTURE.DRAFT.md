# KIMI_INTEGRATION_ARCHITECTURE.md

**Status:** DESIGN DRAFT (for OWNER-authorized implementation). Read-only research produced this document; no repo/runtime file was modified.
**Authority:** `decisions/2026-09-15_owner_kimi_integration_ml_research_r1_internal.md` (OWNER-DEC-KIMI-INTEGRATION-20260915, BINDING); directive verbatim in `docs/ops/evidence/2026-09-15_kimi_integration/owner_directive_verbatim.md`.
**Companion docs:** `KIMI_EDGE_DISCOVERY_DESIGN.md` (research layer), `INTERNAL_RESEARCH_SOURCE_CONTRACT.md` (R1 / QM-RESEARCH). This file is the *integration* spec: CLI facts, adapter, router, chain, quota, tests, rollback.
**Evidence base:** Phase A audit under `docs/ops/evidence/2026-09-15_kimi_integration/audit/` (kimi_cli, router_providers, cards_r1_research, data_memory, vault_contracts, drift, critic). Every current-system claim below cites a `file:line`, an audit finding, or a live command output; anything unconfirmed is marked **UNVERIFIED**.

Fable is the orchestrator and the *only* actor that chooses Kimi for a task. Kimi is a capability provider inside the existing Strategy Farm, never a second orchestration system (directive §1.1, §3). The deterministic pipeline remains the sole judge; an LLM "PASS" is never a pipeline PASS (directive §3, §17).

---

## 1. The installed Kimi CLI (facts, with evidence)

Source: `audit/kimi_cli.md` (read-only, one live probe call).

| Fact | Value | Evidence |
|---|---|---|
| Product / version | Kimi Code CLI **0.43.1** | `kimi.exe --version` → `0.43.1`; `updates/latest.json latest:"0.43.1"` |
| Executable | `C:\Users\Administrator\.kimi-code\bin\kimi.exe` (151 MB, mtime 2026-09-15 08:53) | `Get-ChildItem` |
| On PATH? | **No** — full path required | `where.exe kimi` not found; `Get-Command kimi` not recognized |
| Auth | **Device-code OAuth (Bearer)**, not an API key | `provider list` → `source=oauth`; `config.toml api_key=""` |
| Credential file | `C:\Users\Administrator\.kimi-code\credentials\kimi-code.json` (qm-admin-owned plain JSON) | `Get-ChildItem` |
| Token lifetime | `expires_in=900` (**15 min rolling**), auto-refreshed via refresh_token | field read; critic §4 re-verified it expired ~14 s before read |
| Endpoint / plan | `https://api.kimi.com/coding/v1` — **coding subscription** (not pay-per-token) | `config.toml base_url` |
| Default model | `kimi-code/kimi-for-coding` (K2.8 Preview), **1,048,576-tok** ctx, thinking on by default | `config.toml [models.*]` |
| Cheaper models | `kimi-code/kimi-for-coding-highspeed` (262 k), `kimi-code/k3` (1 M), `kimi-code/k3-256k` (262 k) | `config.toml` |
| One-shot prompt | `-p, --prompt <prompt>` "run one prompt non-interactively" | `kimi --help` |
| Output format | `--output-format {text,stream-json}` (default text) | `kimi --help` |
| Never-hang automation | `--auto` (no interactive prompt); malformed argv drops into the **TUI** (hang risk) | `kimi --help`; audit §4 |
| Extra workspace dir | `--add-dir <dir>` (repeatable) | `kimi --help` |
| Timeout flag | **none** — must be bounded by an external watchdog | `kimi --help` (absent) |
| stdin prompt | **UNVERIFIED** (only `-p <arg>` tested) | audit §4 |
| Usage / quota subcommand | **none** — spend is NOT CLI-queryable; only a `status_line` hook receives a JSON `usage` field | `kimi --help`; `tui.toml [status_line]` |
| Exit-code taxonomy | only `0` observed; non-zero classes **UNVERIFIED** | audit §6 |
| Concurrency / rate limits | **UNVERIFIED** | audit §6 |
| Auto-updater | `updates auto_install=true` — **CLI self-updates** | `updates/latest.json` |
| Existing repo integration | **none** (greenfield); grep `kimi\|moonshot` over `tools/` = 0 | audit §8, router_providers baseline |

Text-mode output is dirty: a `kimi version …` banner, `• ` thinking bullets, then a `To resume this session: kimi -r …` trailer wrap the answer (audit §5). The adapter therefore parses **stream-json**, not text (D1).

---

## 2. Integration points (two planes — do not conflate)

`audit/router_providers.md §1` establishes two disjoint planes; Kimi must be wired into BOTH:

- **Plane A — deterministic router:** `agent_router.py` + `farm_state.sqlite`. Selection = capability-subset filter then `ORDER BY cost_rank ASC` (`agent_router.py:1668-1686`). A lane *is* its `agent_registry` row, synced from `DEFAULT_AGENT_REGISTRY` (`agent_router.py:542-614`) by `sync_default_registry` (`:1065`), which is DB-trigger-gated to the canonical checkout `C:/QM/repo` and runs on the 5-min `QM_StrategyFarm_AgentRouter_5min` task.
- **Plane B — execution:** two independent spawners that share no code or pacing state — the scheduled orchestration lane (`run_agent_orchestration_task.py`, per-agent hardcoded branches) and the Creator→Critic→Formatter chain (`agent_chain.py` + `config/agent_chain.v1.json`).

Integration surfaces (all must move together, or "code wins and Kimi does not exist" — vault_contracts note):

1. Router lane row + task types + cost_rank (§6)
2. Orchestration lane branch (§7)
3. agent_chain vendor + critic tables (§8)
4. Quota governor + `KIMI_LOW_QUOTA.flag`, read by both planes (§9)
5. Scheduled tasks (§10)
6. Observability / routing receipts (§11)
7. R1 `internal_research` source class (§12 — detailed in `INTERNAL_RESEARCH_SOURCE_CONTRACT.md`)
8. Vault/CLAUDE.md roster + Hard-Rule annexes (§16, drift)

---

## 3. Provider adapter contract — `tools/strategy_farm/kimi_adapter.py` (D1)

New module wrapping the pinned executable. It is the single choke point; both planes call it.

### 3.1 Invocation

```
C:\Users\Administrator\.kimi-code\bin\kimi.exe \
  -p @<prompt_file_pointer> \
  --output-format stream-json \
  -m <model> \
  --auto \
  --add-dir <scoped_dir>
```

- **CLI path pinned** as a module constant `KIMI_BIN` (not on PATH — audit §1). Record `kimi.exe --version` per run into the ledger (§9) because the auto-updater is on (audit §1; version pinning defence).
- **Prompt delivery = prompt FILE + short argv pointer** (D1), mirroring the agy pattern: the Windows argv path risks the ~32 KB cmdline cap for large prompts (audit §4). Because a dedicated `--prompt-file` flag does **not** exist, the probe (§15) must settle whether `-p` accepts a file pointer, stdin, or whether large prompts require the `kimi acp` stdio server (the kimi_cli-vs-router_providers contradiction, critic §8.1). Default assumption: write the prompt to `D:/QM/strategy_farm/logs/<task>/prompt.md`, keep argv small.
- **`--auto`** guarantees no interactive prompt hangs a headless run; the adapter validates argv and runs under a watchdog because a malformed argv drops into the TUI (audit §4).

### 3.2 Output parsing

- Parse `--output-format stream-json` to the **final assistant text** (D1). Text mode is a fallback only: strip leading `^kimi version `, `• ` thinking bullets, and the trailing `To resume this session: kimi -r …` line (audit §5, §9-recommended-contract).
- The stream-json event schema is **UNVERIFIED** and is settled by one probe (§15).

### 3.3 Models per capability (D1)

| Role / capability | Model (`-m`) | Rationale |
|---|---|---|
| edge_discovery, hypothesis_authoring, cross_experiment_analysis, long_context_synthesis, deep_research | `kimi-code/kimi-for-coding` (K2.8, 1 M ctx) | default; needs reasoning + full context |
| research_critic / research_review (Kimi-as-critic) | `kimi-code/k3` or `k3-256k` | cheaper critic role |
| summary / short roles | `kimi-code/kimi-for-coding-highspeed` (262 k) | cheapest, sufficient |

Model per capability is a config lookup in `config/kimi_adapter.v1.json`, not hardcoded.

### 3.4 Timeouts, retries, error classes (D1)

- **External watchdog**, default **600 s**, max **1800 s** (no CLI timeout flag — audit §6).
- **Bounded retries: max 2** with backoff.
- **Error classes** (the taxonomy the ledger and governor consume): `auth_expired`, `rate_limited` / `quota`, `timeout`, `malformed_output`, `cli_missing`, `unknown`. Only exit `0` is observed today, so classification is heuristic (non-zero/empty stdout → classify by stderr + cheap health checks `kimi provider list` (source=oauth) and `kimi doctor` before a batch — audit §9). `auth_expired` is **not silently automatable** (needs a device-code `kimi login`) — it raises to a governor state, never a silent retry loop.

### 3.5 Tool posture per role (D1)

| Role | Working dir | `--add-dir` | Write path | Post-run guard |
|---|---|---|---|---|
| research **creator** | isolated git worktree or scratch dir | limited to that dir | that dir only | worktree isolation (like codex/claude, `run_agent_orchestration_task.py:718`, `worktree_path :547`) |
| research **critic** | scratch dir | **repo root, read access only** | **none** | adapter computes `git status`/tree hash of `C:/QM/repo` **before and after**; any change = **failed run** (mirrors directive §8.4-5 "critics are read-only, do not mutate repo code") |

The repo-mutation guard is the hard mechanical enforcement of "a critic that wrote is a failed run" (D1). It complements — does not replace — the chain-level read-only tool envelope (`agent_chain.v1.json vendors.claude.disallowed_tools`, the 2026-09-15 defaultMode=auto finding).

### 3.6 Credential handling — SYSTEM vs console session

- The credential is a plain-JSON, qm-admin-owned file with a **15-min rolling token** auto-refreshed via refresh_token (audit §1; critic §4). A SYSTEM (session-0) scheduled task may **read** it but a token **refresh write** can fail without operator context.
- Adapter passes `USERPROFILE`/`HOME` env so the credential resolves under SYSTEM (D3, mirroring the claude lane `agent_env :198`). **If the probe (§15) shows refresh fails under SYSTEM**, the orchestration task hops to the qm-admin console session via `run_in_console_session.ps1` (the branch agy/gemini use, install ps1 :68-82; router_providers §8).
- **max_parallel = 1** for the kimi lane (D3): a shared credential across concurrent processes is a Codex-class refresh race (critic §4; router_providers risk 1).
- No secret values are ever logged — field names and non-secret expiry epoch only (audit read-only discipline).

---

## 4. Capabilities and what Kimi is NOT allowed to do

### 4.1 Granted capabilities (directive §5)

`research`, `strategy`, `summary`, `source_discovery` (classic, to make it routable on existing task types) **plus** `deep_research`, `long_context_synthesis`, `edge_discovery`, `cross_experiment_analysis`, `research_review`, `research_critic`, `hypothesis_authoring`, `ml_research` (D3).

### 4.2 Denied authority — the exact code guards (directive §5, §23; router_providers §2)

Kimi gets NO gate / live / deployment / verdict-write / T_Live / unrestricted-queue authority. Enforced **by omission and by existing structure**, not by a new gate:

| Denied | Guard (cite) |
|---|---|
| code / tests / repo edits / ops / builds | **Do NOT** declare `code`, `tests`, `repo_edit`, `repo`, `ops`, `scalpel_mechanization` on the kimi registry row (`DEFAULT_AGENT_REGISTRY`); a lane is eligible only if `required ⊆ caps` (`agent_router.py:1678-1680`). `build_ea` requires `code` (`TASK_TYPE_CAPABILITIES:109`) → unreachable for kimi. |
| ops_issue / triage_failure lane pin | **Do NOT** add `kimi` to `AGENT_TASK_TYPE_LANES` (`agent_router.py:215-220`). |
| scalpel/Astra capture | Omit `scalpel_mechanization`; that cap is declared by codex/claude only (D10, `:127`, `:556`, `:579`). |
| verdict write / APPROVED | Verdicts and `APPROVED` are the orchestrator's manual `close-review` (`agent_router.py` CLI). A kimi task terminates in **REVIEW**, never self-approves, never advances main — mirror the gemini rule (`run_agent_orchestration_task.py:273-274,292-294`; router_providers §2). |
| generic critic of EA builds | `agent_chain.v1.json critique.skip_task_types = ["review_ea"]`. |
| gate thresholds / T_Live / AutoTrading / live book | ROT zone (CLAUDE.md; directive §23) — no code path grants it; nothing in this integration touches the gate manifest, T_Live isolation, or `terminal_worker`. |
| queue control | No `code`/`ops` caps → cannot claim ops/build rows; router selection is capability-gated. |

---

## 5. Router integration (Plane A, D3)

### 5.1 New registry lane

Add to `DEFAULT_AGENT_REGISTRY` (`agent_router.py:542-614`):

```python
"kimi": {
    "enabled": True,
    "capabilities": [
        "research", "strategy", "summary", "source_discovery",
        "deep_research", "long_context_synthesis", "edge_discovery",
        "cross_experiment_analysis", "research_review", "research_critic",
        "hypothesis_authoring", "ml_research",
    ],
    "max_parallel": 1,   # OAuth 15-min-token refresh race (Codex class)
    "cost_rank": 12,     # after gemini(10), before codex(20)/claude(30)
},
```

The row lands in the DB only after `sync_default_registry` runs from the canonical checkout (5-min task; `agent_router.py:1065`, trigger gate `:826-833,936-964`). **cost_rank = 12 is load-bearing** (critic §2): gemini's cost_rank 10 historically captured every `[research,strategy]` row (the D10 comment at `:118-127`). Placing kimi at 12 keeps it *behind* gemini for cheap generic research but ahead of codex/claude — so kimi is preferred for the new research task types (which gemini/codex/claude do not declare) without capturing the whole `[research,strategy]` funnel from the cheaper gemini lane. **Kimi must never be given a cost_rank < 10** or it repeats the capture defect.

### 5.2 New task types → routability (the unroutable-capability trap)

The 8 new caps map to no `TASK_TYPE_CAPABILITIES` entry, so a lane declaring only them is idle (`agent_router.py:106-128`; critic §2, router_providers §2). Add:

```python
"research_edge_discovery":  ["research", "edge_discovery"],
"research_hypothesis":      ["research", "strategy", "hypothesis_authoring"],
"research_critique":        ["research_critic"],
```

Existing `research_strategy: ["research","strategy"]` stays routable to gemini/kimi/codex/claude by cost rank. High-value tasks may also pin caps via payload `required_capabilities` / `required_skills` (they gate only because kimi *declares* them, `agent_router.py:1217-1235,1770-1800`), or pin the lane durably via `payload.decision_bound_agent` (`:497,1128-1175`) — kimi is a valid pin target once registered.

### 5.3 Orchestration lane branch (Plane B, D3)

Add a `kimi` branch to each per-agent function in `run_agent_orchestration_task.py`: `resolve_cli` (`:155`), `agent_env` (`:182` — set `USERPROFILE`/`HOME` like claude `:198` so the credential resolves under SYSTEM), `build_prompt` (`:206`), `command_for` (`:408` — prompt file + pointer argv, `--auto`, stream-json), `headless_model_contract` (`:501`), `run_agent_slot` (worktree via `worktree_path :547`), and the `--agent` `choices` tuple (`:1906`). Add `KIMI_BIN` and `KIMI_HEADLESS_MODEL` constants (mirror `CLAUDE_HEADLESS_MODEL :141`). The stdin/TTY choice is load-bearing (wrong choice hangs to timeout — router_providers risk 3); the probe (§15) settles ConPTY-vs-stdin. Install the scheduled task `QM_StrategyFarm_KimiOrchestration_15min` **only after** the smoke receipt (D3, §10).

---

## 6. agent_chain vendor (Plane B critic chain, D4)

Config (`config/agent_chain.v1.json`) and code (`agent_chain.py`) changes:

**Config:**
- `vendors.kimi`: `{ "models": {"default":"kimi-code/kimi-for-coding","k3":"kimi-code/k3"}, read_only_tools/disallowed_tools as claude }`.
- `gates.kimi_low_quota_flag: "D:/QM/strategy_farm/KIMI_LOW_QUOTA.flag"` (extend `gates :60-65`).
- `by_creator_vendor.kimi` = **only non-kimi seats** `[claude sonnet, codex terra, agy]` (satisfies directive §8.2 "a Kimi-authored hypothesis must receive a non-Kimi critic"). **Never list a kimi seat inside `by_creator_vendor.kimi`** (router_providers risk 7).
- Insert `kimi` into the `claude`, `codex`, `agy`, and `unknown` creator tables so kimi can critique others (D4): claude creator → `[codex terra, kimi, claude opus, agy]`; codex creator → `[claude sonnet, kimi, claude opus]`.
- **Kimi as formatter: never** — Haiku stays the formatter (D4; `roles.formatter :48-51`).

**Code:** `VENDOR_ALIASES` add `moonshot/k2 → kimi` (`:68`); `vendor_gate` branch reading `KIMI_LOW_QUOTA.flag` (`:172`, unknown-vendor fails closed); `resolve_cli`/`seat_env`/`_model_id` kimi cases (`:352,362,385`); `run_seat` elif → `run_kimi` (`:617`); implement `run_kimi` (mirror `_run_agy :552` if ConPTY/no-stdin, else `_run_claude :421`). `open_critic_seats` already enforces cross = `seat.vendor != creator_vendor` (`:267`). Critic prompts unchanged; the kimi critic gets the same read-only envelope plus the §3.5 repo-mutation guard.

---

## 7. Subscription / quota management (D2)

No programmatic usage endpoint exists (audit §6), so governance is a **local ledger + a governor deriving states**, with honest uncertainty surfaced (directive §6, §21).

### 7.1 Append-only usage ledger

`D:/QM/reports/state/kimi_usage_ledger.jsonl`, schema `qm.kimi-usage/v1`, one line per call: `ts, task_id, role, capability, model, prompt_sha256, output_sha256, latency_s, exit_class, retries, cli_version, usage_snapshot` (the last only if the `status_line` hook captured one — whether it is subscription-remaining vs per-session is **UNVERIFIED**, critic §3). Written by `kimi_adapter.py` on every call. Mirrors the proven `tester_memory_ledger.jsonl` convention (data_memory §2).

### 7.2 Governor `tools/strategy_farm/kimi_governor.py`

Mirrors `agy_governor.py`. Derives NORMAL / CONSERVE / EXHAUSTED from: rolling call counts vs configurable **daily/weekly call caps** (config, OWNER-adjustable), consecutive `rate_limited`/`quota` error classes, `auth_expired`, `cli_missing`. Ownership-tracked state `D:/QM/reports/state/kimi_governor_state.json`; flag helpers mirror `agy_governor._set_flag/_clear_flag` (`:79-102`) with a `MANAGED_BY` marker (only clears a flag it set). Subscription period (**start 2026-09-15, one month**) recorded in `config/kimi_governor.v1.json` (directive §1.1, §6).

| State | Meaning | Effect |
|---|---|---|
| NORMAL | within caps | flag absent; kimi routable for all its capabilities |
| CONSERVE | approaching caps / soft error streak | only `edge_discovery` / `hypothesis_authoring` / `cross_experiment_analysis` / `research_critic`-for-Kimi-authored stay allowed (directive §6); other kimi routes fall back |
| EXHAUSTED | caps hit / auth failure / CLI missing | `KIMI_LOW_QUOTA.flag` written → **lane disabled**; fallbacks per the existing candidate tables (§6) |

### 7.3 The flag is consumed by BOTH planes (closes the pacing gap)

The router-vs-execution pacing gap (`GATED_AGENTS={codex,claude}`, `quota_spawn_gate.py:36`; a chain-only flag never stops `route_once` — router_providers §3, critic §2) is closed by wiring the flag into **both**:
- **Plane A:** `sync_default_registry` disables/limits the kimi lane when `KIMI_LOW_QUOTA.flag` exists — the exact pattern used for `CLAUDE_DISABLED.flag` (`agent_router.py:1072-1074`).
- **Plane B:** `agent_chain.vendor_gate` reads `gates.kimi_low_quota_flag` (§6).

**Backtests are never affected** (directive §6; `quota_spawn_gate._intrinsic_deterministic`; data_memory §5 — MT5 workers self-throttle independently and win contention). No auto-purchase / renewal — OWNER-only (directive §1.1).

---

## 8. Scheduled tasks (§10 of directive scope)

Add to `install_agent_orchestration_scheduled_tasks.ps1` (definitions `:42-46`; router_providers §8):
- `QM_StrategyFarm_KimiOrchestration_15min` — runs the kimi orchestration branch. **Installed only after the smoke receipt.** Use the plain SYSTEM branch (install ps1 `:83-91`) unless the probe shows the credential refresh needs the console-session hop (`:68-82`). `MaxSessions=1` (auth race, `:31-41`).
- `QM_StrategyFarm_KimiGovernor_15min` — mirrors `QM_StrategyFarm_AgyGovernor`, runs `kimi_governor.py`.

Existing critique sweep `QM_StrategyFarm_AgentChain_Critique_15min` (`agent_chain.py critique-pending --apply --max 2`) picks up kimi vendors automatically once §6 lands (drift §undocumented-mechanisms 1).

---

## 9. Observability / routing receipts (D3, directive §21)

- **Orchestration result JSON** under `D:/QM/strategy_farm/logs/` (`run_agent_orchestration_task.py:987`): `agent, execution_backend, model_contract, slot, prompt_path, live_log, command, cwd, worktree, started_at, pid, returncode, ok, finished_at`. The kimi lane uses the plain file lock (`acquire_lock`), not the codex-only managed lease (router_providers §6).
- **Chain receipt** `qm.agent-chain.receipt.v1` under `D:/QM/strategy_farm/state/agent_chain/<chain_id>.json`: `stages`, `seat_trace` (creator/critic/formatter), `critic_verdict`, `cross_vendor`, `scope_drift`, per-stage `prompt.md` + vendor log + `answer.md` (router_providers §6).
- **Routing receipt per high-value task** (D3): JSON under `D:/QM/strategy_farm/logs/routing_receipts/` — `task_id, capability, candidates_considered, chosen_provider, reason, quota_states`. This is the "compact routing receipt" the directive §7 requires and is written by Fable/the router when it selects a non-deterministic seat.
- **Usage ledger** (§7.1) is the Kimi-specific spend telemetry; subscription period + whatever usage indicators exist are recorded, and **no token/USD values are invented** (directive §21).

---

## 10. R1 internal source class (integration hook; detail in the source-contract doc, D5)

Full contract is `INTERNAL_RESEARCH_SOURCE_CONTRACT.md`. Integration-relevant facts (cards_r1_research audit):
- R1 is **already source-agnostic**: `_card_r1_build_ready` returns `bool(source_id non-empty)` (`farmctl.py:4229-4237`); `R_STRICT_PASS_FIELDS = (r2_mechanical, r3_data_available, r4_ml_forbidden)` excludes R1 (`:4219,4467-4471`). A Kimi-authored `source_id` passes as written.
- **One required code change:** scope `card_intake_prescreen._affirmative_prohibited_mechanics` (`:464-489`, trips `PROHIBITED_MECHANICS:ML` at `:541-543`) to the mechanics sections, exempting a `## Research provenance` section, so ML-provenance prose is not auto-rejected (critic §5; cards_r1_research §2b). The runtime R4 ML scan is **untouched** — it scans only `.mq5/.mqh` with comments/strings blanked (`build_check.ps1 Invoke-ForbiddenScan :888-960`), so an ML-authored *research* provenance never trips *runtime* R4.
- `farmctl.VALID_SOURCE_TYPES` (`:33580-33583`) += `internal_research` (needed only if a routable DB `sources` row via `add-source` is wanted; AI cards today are card+decisions-only).
- Durable store `strategy-seeds/sources/QM-RESEARCH-YYYY-NNNN/` (`source.md`, `research.json` with sha256, `critic_receipt.json`, `lineage.json`); append-only registry `D:/QM/reports/state/research_source_ledger.jsonl`; resolver `tools/strategy_farm/research_source.py` (`mint`/`resolve`/`verify`: `QM-RESEARCH://id → path + sha check`). External attribution rules unchanged.

---

## 11. Routing policy — how Fable chooses (directive §4, §7)

For every non-deterministic task Fable estimates reasoning depth, context requirement, novelty, value of an independent lens, semantic complexity, expected information gain, current provider quota, historical quality, and latency (directive §7). Then:
- **Deterministic task** (metric a script can compute) → Python/SQL/tooling, never an LLM (directive §4, §6 "LLMs never compute metrics a script can compute").
- **Large-scale cross-experiment synthesis / novel-edge hypothesis / ML-assisted discovery** → **Kimi preferred** when quota is NORMAL (directive §7).
- **MQL5/Python implementation** → Codex. **Architecture synthesis / OWNER-facing writing** → Fable/Claude. **Source discovery** → Antigravity or Kimi. **Independent critique** → a provider *different from the creator* (cross-vendor, §6).
- Mechanically, once task types + cost_rank land (§5), the deterministic router selects by `required ⊆ caps` then `cost_rank ASC`; Fable overrides via payload capability pins or `decision_bound_agent` for high-value work and records the routing receipt (§9).
- **CONSERVE** narrows kimi to high-value research only; **EXHAUSTED** falls back to the candidate tables (§7).

---

## 12. Failure handling — a Kimi failure never corrupts a task

The directive requires "a Kimi failure must never corrupt an existing task" (§5). Existing mechanisms deliver this:
- **Bounded retries (max 2) + error classes** in the adapter (§3.4); `auth_expired`/`cli_missing` raise to governor state, never a silent loop.
- **Router idempotency:** a lane that cannot execute leaves the row claimable; the `spawn_leases`/`LEASE_TTL_MINUTES=30` release path (`agent_router.py:103-104`) and lane-heartbeat staleness de-list (`:617`, `_lane_heartbeat_stale`) return an abandoned kimi claim without a verdict — re-routed on the next cycle.
- **Chain fallback:** `vendor_gate` fails closed on unknown/gated vendors and `open_critic_seats` walks the candidate table, so a gated/broken kimi seat falls to the next seat with `cross_vendor=false` recorded, never a corrupted receipt (§6).
- **REVIEW-terminal + no self-approve** (§4.2): a kimi task can never write a verdict, so a failed kimi run cannot poison gate/verdict state.
- **Backtests / MT5 workers untouched** regardless of kimi state (§7.3; directive §5, §22 "no effect on MT5 workers if Kimi is unavailable").

---

## 13. Probe battery — one-time in implementation (D1)

Run **at most 6 tiny calls** LATER in implementation (not in this design pass), to settle the UNVERIFIED items:

1. **Prompt delivery** — `-p` argv vs `-p @file` pointer vs stdin (32 KB cmdline limit; whether `acp` is needed for large prompts).
2. **stream-json event schema** — the framing the adapter parses to final assistant text.
3. **Exit codes on auth failure** — simulated by a bogus provider config in a temp `HOME` (no real quota burned).
4. **Plan-mode behaviour** — `--plan` output shape (whether it is safe/useful for a critic dry pass).
5. **stdin-vs-TTY/ConPTY** — does a SYSTEM/pipe invocation run headless or hang (agy-class)?
6. **Credential refresh under SYSTEM** — does the 15-min token refresh succeed session-0, or is the console-session hop required (§3.6, §8)?

Do not burn meaningful subscription capacity on retry tests — use mocks (directive §22).

---

## 14. Test matrix (directive §22 → concrete test files)

| Directive §22 requirement | Test file · case |
|---|---|
| basic Kimi CLI invocation | `tests/test_kimi_adapter.py::test_invoke_stream_json_parses_final_text` (mock subprocess) |
| authentication failure | `test_kimi_adapter.py::test_auth_expired_classified_no_silent_retry` |
| timeout | `test_kimi_adapter.py::test_watchdog_timeout_classified` |
| rate/quota failure | `test_kimi_adapter.py::test_rate_limited_class` + `test_kimi_governor.py::test_conserve_on_quota_streak` |
| malformed output / schema failure | `test_kimi_adapter.py::test_malformed_stream_json_class` |
| retry exhaustion | `test_kimi_adapter.py::test_retry_exhaustion_max2` |
| unavailable CLI | `test_kimi_adapter.py::test_cli_missing_class` |
| fallback provider | `test_agent_chain.py::test_kimi_gated_falls_to_next_critic_seat` |
| quota-conservation mode | `test_kimi_governor.py::test_states_normal_conserve_exhausted` + flag read `test_agent_router.py::test_kimi_low_quota_disables_lane` |
| Kimi Creator → non-Kimi Critic | `test_agent_chain.py::test_kimi_creator_critic_is_non_kimi` (invariant: no kimi in `by_creator_vendor.kimi`) |
| non-Kimi Creator → Kimi Critic | `test_agent_chain.py::test_kimi_eligible_as_critic_for_claude_codex` |
| Kimi internal source → R1 PASS | `tests/test_internal_research_source.py::test_valid_kimi_source_passes` |
| Kimi name without artifact → R1 FAIL | `test_internal_research_source.py::test_author_kimi_without_artifact_fails` + `test_missing_hash_fails_closed` |
| external unattributed FAILS / external valid PASSES | `test_internal_research_source.py::test_external_unattributed_fails` / `test_external_valid_passes` |
| ML research → mechanical Strategy Card conversion | `test_card_intake_prescreen.py::test_ml_provenance_section_not_rejected` + `test_mechanization_check.py::test_finite_params_no_ml_terms` |
| rejection of an EA requiring runtime ML | `test_mechanization_check.py::test_runtime_ml_ea_rejected` (and existing `build_check` scan) |
| restart/recovery | `test_agent_orchestration_lock.py` (kimi lock/lease release) |
| secret leakage | `test_kimi_adapter.py::test_no_secret_fields_logged` |
| concurrency | `test_kimi_adapter.py::test_max_parallel_1_enforced` |
| no effect on MT5 workers if Kimi unavailable | `test_kimi_governor.py::test_flag_never_gates_backtests` |
| router selection / cost_rank / routability | `test_agent_router.py::test_kimi_routable_new_task_types` + `test_cost_rank_12_no_research_strategy_capture` |
| backend contract | `tests/test_kimi_backend_contract.py` (mirror `test_antigravity_backend_contract.py`) |

Use mocks for all failure cases (directive §22).

---

## 15. Rollback

Every switch is reversible (directive §25 "everything reversible"):

| Switch | Effect |
|---|---|
| `KIMI_LOW_QUOTA.flag` (write) | EXHAUSTED — kimi lane disabled in both planes; no code change needed |
| kimi registry row `enabled: False` + `max_parallel: 0` in `DEFAULT_AGENT_REGISTRY`, then `sync_default_registry` | lane de-registered (Plane A) |
| remove `kimi` from `agent_chain.v1.json` vendors + creator tables | chain reverts to claude/codex/agy |
| disable/delete `QM_StrategyFarm_KimiOrchestration_15min` + `QM_StrategyFarm_KimiGovernor_15min` | stops both scheduled spawners |
| env kill switch on the chain | `QM_AGENT_CHAIN=0` (existing, `agent_chain.v1.json _doc`) |
| revert the three new `TASK_TYPE_CAPABILITIES` entries | new research task types become unroutable |

A partial add is the danger (vault_contracts note, critic §2): all router surfaces must move in one path-scoped commit, or the code wins and kimi is either non-existent or unthrottled.

---

## 16. Drift items this integration must not worsen

From `audit/drift.md`. This integration adds control-plane surfaces, so it must not repeat the "live mechanism never documented in CLAUDE.md" pattern:

1. **CLAUDE.md roster + quota section must be updated in the same change** (drift 3,4,5; vault_contracts consolidated list) — add the kimi lane, `kimi_governor.py`, `KIMI_LOW_QUOTA.flag`, and the `QM_StrategyFarm_Kimi*` tasks, or this becomes another undocumented-but-live mechanism (drift §undocumented 1-5).
2. **Company Structure "drei AIs" → four** (vault_contracts §a; critic §1) — Vault `02 Org/Company Structure.md:12-14` and the routing-contract table need the annex, else the code registry and Vault disagree.
3. **HR14/R4 ML annex is a DL + OWNER signature** (vault_contracts §b; critic §6) — the offline-ML-in-research permission (directive §3) crosses a Hard Rule; the annex must preserve R4's in-EA reject list verbatim. That annex is a companion deliverable, not part of this integration code, but the integration must not ship the prescreen scoping change (§10) *ahead* of the signed annex.
4. **Do not rely on the retired reboot task** (drift 1) or stale purge threshold (drift 2) in any kimi runbook — workers come up via `QM_StrategyFarm_FactoryON_AtLogon`; purge LowWater is live at 60 GB.
5. **The gemini lane still carries `code/tests/repo_edit`** (drift 3) — do NOT copy that ambiguity onto the kimi lane; kimi is research-only by capability set (§4).
6. **Do not connect Kimi's hypothesis volume to DSR without counting trials** (critic §7): uncounted kimi trials silently inflate survivorship. `dsr_cohort.py` already carries `search_history` / `research_trial_count` / `effective_trial_count` (`:753-758`); the edge-discovery search-history ledger must feed those (detailed in `KIMI_EDGE_DISCOVERY_DESIGN.md`).
7. **Research intermediates off D:** D: was ~65 GB free at audit (below purge lines); kimi/research outputs stay small and on C:/G:, gated on worker CPU/RAM latches (data_memory §5,§7) so backtests keep winning contention.

---

## Appendix — UNVERIFIED items to resolve in implementation

- stream-json event schema; `-p` file-pointer vs stdin vs `acp` for large prompts; non-zero exit-code taxonomy; concurrency/rate-limit behaviour; whether `status_line usage` is subscription-remaining or per-session; credential refresh success under SYSTEM (session-0); plan-mode output shape. All are settled by the §13 probe battery before `QM_StrategyFarm_KimiOrchestration_15min` is installed.
