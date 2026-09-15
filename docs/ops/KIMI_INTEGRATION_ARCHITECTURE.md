# KIMI_INTEGRATION_ARCHITECTURE.md

**Status:** FINAL v1 (2026-09-15) — for OWNER-authorized implementation. Read-only research produced this document; no repo/runtime file was modified except this file.
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
| Automation flags | `--auto` (**everything runs, no interruption** — full tool execution incl. shell/file writes), `-y/--yolo` (risky actions still ask), `--plan` (plan-only, behaviour UNVERIFIED) | `kimi --help`; audit §4 |
| Never-hang automation | malformed argv drops into the **TUI** (hang risk) | `kimi --help`; audit §4 |
| Extra workspace dir | `--add-dir <dir>` (repeatable); whether it grants **write** access is **UNVERIFIED** | `kimi --help`; audit §4 |
| Tool-restriction flag | **none** equivalent to the claude chain envelope (`--tools/--disallowedTools/--permission-mode`); posture is set only via `--agent-file`/`--skills-dir`/`--plan` | `kimi --help` (absent); critic F1 |
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
- **Plane B — execution:** two independent spawners that share no code or pacing state — the scheduled orchestration lane (`run_agent_orchestration_task.py`, per-agent hardcoded branches) and the Creator→Critic→Formatter chain (`agent_chain.py` + `config/agent_chain.v1.json`, swept by `QM_StrategyFarm_AgentChain_Critique_15min`).

**Neither Plane-B spawner consults the registry** (`router_providers.md §1,§11`). This is load-bearing for concurrency: `max_parallel` on the registry row constrains only Plane A, so cross-plane serialization is enforced in the adapter, not the registry (see §3.6, F2).

Integration surfaces (all must move together, or "code wins and Kimi does not exist" — vault_contracts note):

1. Router lane row + task types + cost_rank (§5)
2. Orchestration lane branch (§5.3)
3. agent_chain vendor + critic tables (§6)
4. Quota governor + `KIMI_LOW_QUOTA.flag`, read by both planes (§7)
5. Scheduled tasks (§8)
6. Observability / routing receipts (§9)
7. R1 `internal_research` source class (§10 — detailed in `INTERNAL_RESEARCH_SOURCE_CONTRACT.md`)
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

- **CLI path pinned** as a module constant `KIMI_BIN` (not on PATH — audit §1). Record `kimi.exe --version` per run into the ledger (§7) because the auto-updater is on (audit §1; version pinning defence).
- **Prompt delivery = prompt FILE + short argv pointer** (D1), mirroring the agy pattern: the Windows argv path risks the ~32 KB cmdline cap for large prompts (audit §4). Because a dedicated `--prompt-file` flag does **not** exist, the probe (§13) must settle whether `-p` accepts a file pointer, stdin, or whether large prompts require the `kimi acp` stdio server (the kimi_cli-vs-router_providers contradiction, critic §8.1). Default assumption: write the prompt to `D:/QM/strategy_farm/logs/<task>/prompt.md`, keep argv small.
- **`--auto`** guarantees no interactive prompt hangs a headless run; the adapter validates argv and runs under a watchdog because a malformed argv drops into the TUI (audit §4). Note `--auto` executes *everything* with no interruption — the read-only enforcement for a critic run is therefore posture + probe, not `--auto` (see §3.5, F1).

### 3.2 Output parsing

- Parse `--output-format stream-json` to the **final assistant text** (D1). Text mode is a fallback only: strip leading `^kimi version `, `• ` thinking bullets, and the trailing `To resume this session: kimi -r …` line (audit §5, §9-recommended-contract).
- The stream-json event schema is **UNVERIFIED** and is settled by one probe (§13). The parser must fail closed on **valid JSON with an unexpected/renamed event set** (a realistic outcome after a CLI auto-update), classified distinctly from non-JSON garbage (§14, F9).

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
- **Error classes** (the taxonomy the ledger and governor consume): `auth_expired`, `rate_limited` / `quota`, `timeout`, `malformed_output`, `schema_mismatch`, `cli_missing`, `unknown`. Only exit `0` is observed today, so classification is heuristic (non-zero/empty stdout → classify by stderr + cheap health checks `kimi provider list` (source=oauth) and `kimi doctor` before a batch — audit §9). `auth_expired` is **not silently automatable** (needs a device-code `kimi login`) — it raises to a governor state, never a silent retry loop.

### 3.5 Tool posture per role — READ-ONLY CRITIC IS ENFORCED, NOT MERELY DETECTED (D1; R-D; resolves blocking F1)

`--auto` runs every tool including shell and file writes, and Kimi exposes **no** tool-restriction flag equivalent to the claude chain envelope (audit §4; critic F1). A post-hoc repo git-hash guard alone is *detection, not prevention*, and its scope is the repo tree only — `farm_state.sqlite`, verdicts and evidence live under `D:/QM`, outside the repo (`data_memory.md §1`), reachable by any shell tool an `--auto` run invokes. The critic posture is therefore layered:

| Role | Working dir | `--add-dir` | Write path | Enforcement |
|---|---|---|---|---|
| research **creator / research / formatter** | isolated git worktree or scratch dir | limited to that dir | that dir only | **no-shell `--agent-file`** (Read/Grep/Glob/List/Write/Edit, **no Bash/PowerShell**) + worktree isolation + two-scope mutation guard (below) |
| research **critic** | scratch dir (writable) | **scratch dir only, with read access to the repo** — never the live tree granted write | **scratch dir only** | **primary** read-only posture (no Write/Edit either) + **secondary** hash guard + **tertiary** code guards (below) |
| **research_ml** | research venv / isolated worktree | that dir only | that dir only | **shell-capable by design** (ML exploration); has NO agent file. `kimi_adapter.run_kimi` accepts it **only** when the caller passes `allow_shell=True` — the orchestration lane and `agent_chain` never do; only the research package tooling may. |

> No-shell posture generalised (review F2, 2026-09-15): the earlier draft removed shell **only** for the critic and left the unattended `creator`/`research` roles with Kimi's full default toolset (Bash/PowerShell), so their authority guards were prompt-level, not mechanical. All unattended non-critic roles now carry a no-shell `--agent-file` (`research_agent_file_content` in `config/kimi_adapter.v1.json`). `research_ml` is the one deliberate shell-capable exception and is gated behind `allow_shell=True`.

**Primary (prevention) — Kimi read-only posture (R-D):** a dedicated Kimi `--agent-file`/skills posture that **denies file-writing tools** (Write/Edit/Bash/shell), with `--add-dir` limited to a **scratch dir** that carries **read** access to the repo. The posture is validated by the probe battery before any unattended critic runs: *(a) does `--add-dir` grant write access? (b) does `--plan` deny writes?* (§13, probes 4 and 7). Install of the Kimi critique/orchestration tasks is gated on these probes passing, not merely on a smoke receipt (F1).

**Secondary (detection) — adapter two-scope mutation guard (R-D; implemented F3, 2026-09-15):** on **every** run the adapter computes (a) a `git status --porcelain` hash of `C:/QM/repo` and (b) a listing hash `(path, size, mtime)` of the protected trees read from config `protected_trees` (defaults: `D:/QM/strategy_farm/state`, `D:/QM/reports/state`, `D:/QM/strategy_farm/artifacts/cards_approved`, `C:/QM/mt5/T_Live/MT5_Base/MQL5`, `C:/QM/mt5/T_Live/MT5_Base/config`) — skipping absent paths and excluding the adapter's own ledger/lock/governor-state files — **before and after** the run. The result carries `repo_write`, `protected_write` and the `changed_paths`. A **critic** that changed either scope → status **`critic_wrote`** (output discarded, no formatter). A **research/creator/formatter** run that changed a **protected** tree → status **`protected_write`** (text kept but flagged; the lane result surfaces it via the status field). Repo writes by a non-critic role are legitimate (its worktree/out_dir) and stay `ok` with `repo_write=true` recorded.

**Tertiary (structural) — code guards (R-F, §4.2):** the Kimi lane declares no `code/ops/repo_edit` caps (rows unclaimable), no Kimi branch has a verdict-write path, T_Live paths are never placed in `--add-dir`, and no `farmctl` subcommand is callable by a Kimi task — so even a mutating shell cannot self-approve or advance state.

**Downstream verification (R-D):** `research_source.verify` **fails closed** when a `critic_receipt.json` carries `repo_write=true` — a critic that wrote can never satisfy R1 (§10).

> Resolution note (F1): the review proposed running the critic against a throwaway **copy** of the repo. Orchestrator resolution **R-D** supersedes the copy mechanism with a **posture-denial + scratch-only `--add-dir`** primary guard, probe-verified, plus the extended (repo **and** `D:/QM`) hash guard as secondary detector and the `critic_wrote`/no-formatter discard path. Prevention is thereby posture-first with a two-scope detector, satisfying the finding's intent (no mutation reaches the real repo or `D:/QM`).

### 3.6 Credential handling, single-flight lock, at-rest hardening — SYSTEM vs console session

- The credential is a plain-JSON, qm-admin-owned file with a **15-min rolling token** auto-refreshed via refresh_token (audit §1; critic §4). A SYSTEM (session-0) scheduled task may **read** it but a token **refresh write** can fail without operator context.
- Adapter passes `USERPROFILE`/`HOME` env so the credential resolves under SYSTEM (D3, mirroring the claude lane `agent_env :198`). **If the probe (§13) shows refresh fails under SYSTEM**, the orchestration task hops to the qm-admin console session via `run_in_console_session.ps1` (the branch agy/gemini use, install ps1 :68-82; router_providers §8).
- **Machine-wide single-flight lock (R-E; resolves major F2).** `max_parallel = 1` on the registry row is consulted **only by Plane A** (`agent_router.py:1681 _running_count` is DB/registry-scoped); it does **not** stop the two Plane-B spawners (orchestration + critique sweep) from launching Kimi processes concurrently, and `MaxSessions=1` only prevents one task overlapping *itself* (router_providers §1, risk 1; critic F2). Because the OAuth credential refresh is a shared-file race, `kimi_adapter.py` holds a **machine-wide single-flight lock** (named mutex / lockfile carrying the holder pid) around **every** Kimi invocation regardless of caller — orchestration lane, chain, or research tooling all serialize through it. `max_parallel=1` on the lane is the **second belt**, not the primary guarantee. The test asserts the **adapter-level cross-process lock** (`test_max_parallel_1_enforced`), not a registry field (§14).
- **Credential at-rest hardening (resolves minor F8).** The credential is a plain-JSON bearer refresh token; verify and, if needed, tighten the ACL on `C:/Users/Administrator/.kimi-code/credentials/kimi-code.json` to **qm-admin/SYSTEM only** as a one-line install step. The adapter logs field names and the non-secret expiry epoch only — **never token values** (directive §5; critic §4).

---

## 4. Capabilities and what Kimi is NOT allowed to do

### 4.1 Granted capabilities (directive §5)

`research`, `strategy`, `summary`, `source_discovery` (classic, to make it routable on existing task types) **plus** `deep_research`, `long_context_synthesis`, `edge_discovery`, `cross_experiment_analysis`, `research_review`, `research_critic`, `hypothesis_authoring`, `ml_research` (D3).

### 4.2 Denied authority — code-level guards vs process-level guards (directive §5, §23; router_providers §2; R-F; resolves major F3)

Kimi gets NO gate / live / deployment / verdict-write / T_Live / unrestricted-queue authority. The distinction below is deliberate: **code-level guards** are mechanically enforced by capability omission and by the absence of any Kimi code path to the authority; **process-level guards** are receipts and orchestrator review. The earlier draft cited `run_agent_orchestration_task.py:273-294` as an "exact code guard" — those lines are the **HARD_RULES prompt docstring** handed to the LLM ("leave … in REVIEW … do not self-approve"), i.e. a **prompt-level** constraint, not enforcement. It is corrected here (critic F3).

**Code-level guards (mechanical):**

| Denied | Code guard (cite) |
|---|---|
| code / tests / repo edits / ops / builds | **Do NOT** declare `code`, `tests`, `repo_edit`, `repo`, `ops`, `scalpel_mechanization` on the kimi registry row (`DEFAULT_AGENT_REGISTRY`); a lane is eligible only if `required ⊆ caps` (`agent_router.py:1678-1680`). `build_ea` requires `code` (`TASK_TYPE_CAPABILITIES:109`) → unreachable for kimi. |
| ops_issue / triage_failure lane pin | **Do NOT** add `kimi` to `AGENT_TASK_TYPE_LANES` (`agent_router.py:215-220`) → those rows never route to kimi. |
| scalpel / Astra capture | Omit `scalpel_mechanization`; that cap is declared by codex/claude only (D10, `:127`, `:556`, `:579`). |
| verdict write / APPROVED | **No Kimi branch has a verdict-write path.** Verdicts and `APPROVED` are written only by the orchestrator's manual `close-review` CLI (`agent_router.py`). A kimi task carries no `code`/`ops` cap and no `farmctl` subcommand is callable by it (below), so it cannot invoke `close-review`, advance `main`, or self-approve — independent of any prompt instruction. |
| `farmctl` subcommands | **No `farmctl` subcommand is callable by a Kimi task**: as of F2 (2026-09-15) **every unattended role** (critic, creator, research, formatter) runs under a `--agent-file` that denies Bash/PowerShell, so no shell exists to invoke `farmctl approve-card` / `close-review`. The one shell-capable role, `research_ml`, is reachable only via `run_kimi(allow_shell=True)`, which the lane and chain never pass. |
| T_Live / gate manifest / live book | **T_Live paths are never placed in `--add-dir`**; nothing in this integration touches the gate manifest, T_Live isolation, or `terminal_worker`. ROT zone (CLAUDE.md; directive §23). |
| queue control | No `code`/`ops` caps → cannot claim ops/build rows; router selection is capability-gated (`agent_router.py:1678-1680`). |

**Process-level guards (receipts + orchestrator review):**

| Guard | Mechanism |
|---|---|
| REVIEW-terminal, no self-advance | A kimi orchestration task terminates in **REVIEW**; the orchestrator's manual `close-review` is the only path onward. The HARD_RULES prompt docstring (`run_agent_orchestration_task.py:271-294`) *reinforces* this at the prompt level, but the guarantee is the code-level absence of a verdict-write path above. |
| generic critic of EA builds excluded | `agent_chain.v1.json critique.skip_task_types = ["review_ea"]`. |
| cross-vendor critic receipt | `by_creator_vendor.kimi` = non-Kimi seats only (§6); receipts logged (§9). |
| orchestrator review | Fable reviews REVIEW-terminal kimi artifacts before any promotion; the routing receipt (§9) records the seat choice. |

**Honesty note — mechanical vs. prompt+detection+review (review F2/F3, 2026-09-15).** Be precise about which of the above is *mechanically* enforced and which rests on prompt + detection + human review:

- **Mechanical (cannot be bypassed by the LLM):** (1) the critic's read-only `--agent-file` (no Write/Edit/Bash) and every unattended role's no-shell `--agent-file` (no Bash/PowerShell); (2) capability omission — build/ops/verdict task types are structurally unroutable to kimi (`required ⊆ caps`); (3) no Kimi code branch has a verdict-write / `close-review` / `farmctl` path; (4) the guard **scopes** — `--add-dir` confines writes to the worktree/out_dir, and the two-scope before/after mutation guard (§3.5) detects any write into the repo or the protected `D:/QM`/T_Live trees; (5) `research_ml` (shell-capable) is refused unless the caller passes `allow_shell=True`, which the lane and chain never do.
- **Prompt + detection + orchestrator review (NOT purely mechanical):** *which* files a research/creator role writes **inside its own worktree/out_dir** is bounded mechanically to that directory, but the intent ("write only the research artifact, leave the task in REVIEW, never self-advance") is a **prompt-level** instruction. It is backed by **detection** (the two-scope mutation guard flags any escape as `protected_write`/`critic_wrote`; a `repo_write=true` critic receipt fails `research_source.verify` closed) and by **orchestrator review** of every REVIEW-terminal artifact before promotion. A misbehaving in-worktree write is caught after the fact and never promoted, but it is not prevented a-priori the way shell denial is.

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
    "max_parallel": 1,   # second belt only; the real guard is the adapter single-flight lock (§3.6, R-E)
    "cost_rank": 12,     # after gemini(10), before codex(20)/claude(30)
},
```

The row lands in the DB only after `sync_default_registry` runs from the canonical checkout (5-min task; `agent_router.py:1065`, trigger gate `:826-833,936-964`). **cost_rank = 12 is load-bearing** (critic §2): gemini's cost_rank 10 historically captured every `[research,strategy]` row (the D10 comment at `:118-127`). Placing kimi at 12 keeps it *behind* gemini for cheap generic research but ahead of codex/claude — so kimi is preferred for the new research task types (which gemini/codex/claude do not declare) without capturing the whole `[research,strategy]` funnel from the cheaper gemini lane. **Kimi must never be given a cost_rank < 10** or it repeats the capture defect.

### 5.2 gemini-down interaction — cost_rank alone does NOT protect the subscription (R-G; resolves major F4)

The cost_rank-12 protection holds **only while the gemini lane is enabled**. At audit the gemini/agy lane is **auth-degraded** (`agy_quota.json` HTTP 401 `token_expired`, `AGY_LOW_QUOTA.flag` set — drift.md Quota flags). With gemini out, kimi at rank 12 becomes the **cheapest eligible lane** for `research_strategy` and other generic `[research,strategy]` rows (codex 20 / claude 30 are dearer), so it would immediately capture the generic research funnel and burn the fixed one-month subscription on exactly the low-value log/summary work the OWNER said Kimi is NOT for (directive §4, §20). cost_rank is therefore **not** the guarantee; the governor and routing policy are:

- **Governor call caps (R-G):** conservative defaults, config-driven and OWNER-adjustable — **40 calls/day, 200 calls/week**; **CONSERVE at 70 %**, **EXHAUSTED at 100 %** of a cap **or on 2 consecutive rate/auth failures**. State is derived at each invocation and by the 15-min governor task (§7).
- **Routing policy:** generic `research_strategy` is treated as a **low-value class** that prefers gemini/codex and uses kimi only as a **bounded last resort**; in **CONSERVE**, generic `research_strategy` is **excluded** from kimi and only the high-value capabilities remain (edge_discovery / hypothesis_authoring / cross_experiment_analysis / research_critic-for-non-Kimi-authored — §7.2). Even in NORMAL the daily/weekly caps bound generic capture when gemini is down.

### 5.3 New task types → routability (the unroutable-capability trap)

The 8 new caps map to no `TASK_TYPE_CAPABILITIES` entry, so a lane declaring only them is idle (`agent_router.py:106-128`; critic §2, router_providers §2). Add:

```python
"research_edge_discovery":  ["research", "edge_discovery"],
"research_hypothesis":      ["research", "strategy", "hypothesis_authoring"],
"research_critique":        ["research_critic"],
```

Existing `research_strategy: ["research","strategy"]` stays routable to gemini/kimi/codex/claude by cost rank (subject to §5.2). High-value tasks may also pin caps via payload `required_capabilities` / `required_skills` (they gate only because kimi *declares* them, `agent_router.py:1217-1235,1770-1800`), or pin the lane durably via `payload.decision_bound_agent` (`:497,1128-1175`) — kimi is a valid pin target once registered.

### 5.4 Orchestration lane branch (Plane B, D3)

Add a `kimi` branch to each per-agent function in `run_agent_orchestration_task.py`: `resolve_cli` (`:155`), `agent_env` (`:182` — set `USERPROFILE`/`HOME` like claude `:198` so the credential resolves under SYSTEM), `build_prompt` (`:206`), `command_for` (`:408` — prompt file + pointer argv, `--auto`, stream-json), `headless_model_contract` (`:501`), `run_agent_slot` (worktree via `worktree_path :547`), and the `--agent` `choices` tuple (`:1906`). Add `KIMI_BIN` and `KIMI_HEADLESS_MODEL` constants (mirror `CLAUDE_HEADLESS_MODEL :141`). Every spawn routes through `kimi_adapter.py` so the single-flight lock (§3.6) applies. The stdin/TTY choice is load-bearing (wrong choice hangs to timeout — router_providers risk 3); the probe (§13) settles ConPTY-vs-stdin. Install the scheduled task `QM_StrategyFarm_KimiOrchestration_15min` **only after** the probe battery and smoke receipt (D3, §8).

---

## 6. agent_chain vendor (Plane B critic chain, D4)

Config (`config/agent_chain.v1.json`) and code (`agent_chain.py`) changes:

**Config:**
- `vendors.kimi`: `{ "models": {"default":"kimi-code/kimi-for-coding","k3":"kimi-code/k3"}, read_only_tools/disallowed_tools as claude }` plus the Kimi read-only agent-file posture (§3.5).
- `gates.kimi_low_quota_flag: "D:/QM/strategy_farm/KIMI_LOW_QUOTA.flag"` (extend `gates :60-65`).
- `by_creator_vendor.kimi` = **only non-kimi seats** `[claude sonnet, codex terra, agy]` (satisfies directive §8.2 "a Kimi-authored hypothesis must receive a non-Kimi critic"). **Never list a kimi seat inside `by_creator_vendor.kimi`** (router_providers risk 7); this invariant is never relaxed by quota state (F5).
- Insert `kimi` into the `claude`, `codex`, `agy`, and `unknown` creator tables so kimi can critique others (D4): claude creator → `[codex terra, kimi, claude opus, agy]`; codex creator → `[claude sonnet, kimi, claude opus]`.
- **Kimi as formatter: never** — Haiku stays the formatter (D4; `roles.formatter :48-51`).

**Code:** `VENDOR_ALIASES` add `moonshot/k2 → kimi` (`:68`); `vendor_gate` branch that **fails closed** on missing `KIMI_LOW_QUOTA.flag` **and** on a missing CLI binary **and** on a missing/expired credential file (D4; F6 — matching the unknown-vendor fail-closed path at `:172`, not flag-only); `resolve_cli`/`seat_env`/`_model_id` kimi cases (`:352,362,385`); `run_seat` elif → `run_kimi` (`:617`); implement `run_kimi` (mirror `_run_agy :552` if ConPTY/no-stdin, else `_run_claude :421`) — all through `kimi_adapter.py`. `open_critic_seats` already enforces cross = `seat.vendor != creator_vendor` (`:267`). Critic prompts unchanged; the kimi critic gets the §3.5 read-only posture, the extended hash guard, and the `critic_wrote`/no-formatter discard path.

---

## 7. Subscription / quota management (D2, R-G)

No programmatic usage endpoint exists (audit §6), so governance is a **local ledger + a governor deriving states**, with honest uncertainty surfaced (directive §6, §21).

### 7.1 Append-only usage ledger

`D:/QM/reports/state/kimi_usage_ledger.jsonl`, schema `qm.kimi-usage/v1`, one line per call: `ts, task_id, role, capability, model, prompt_sha256, output_sha256, latency_s, exit_class, retries, cli_version, usage_snapshot` (the last only if the `status_line` hook captured one — whether it is subscription-remaining vs per-session is **UNVERIFIED**, critic §3). Written by `kimi_adapter.py` on every call. Mirrors the proven `tester_memory_ledger.jsonl` convention (data_memory §2).

### 7.2 Governor `tools/strategy_farm/kimi_governor.py`

Mirrors `agy_governor.py`. Derives NORMAL / CONSERVE / EXHAUSTED from: rolling call counts vs the **daily/weekly call caps** (R-G: 40/day, 200/week defaults, config, OWNER-adjustable), consecutive `rate_limited`/`quota`/auth error classes, `auth_expired`, `cli_missing`, **and the recorded subscription period** (F7). Ownership-tracked state `D:/QM/reports/state/kimi_governor_state.json`; flag helpers mirror `agy_governor._set_flag/_clear_flag` (`:79-102`) with a `MANAGED_BY` marker (only clears a flag it set). Subscription period (**start 2026-09-15, one month**) recorded in `config/kimi_governor.v1.json` (directive §1.1, §6).

| State | Trigger (R-G) | Effect |
|---|---|---|
| NORMAL | within caps and comfortably before period end | flag absent; kimi routable for all its capabilities |
| CONSERVE | **≥ 70 %** of a daily/weekly cap, soft error streak, **or period-end approaching** | only `edge_discovery` / `hypothesis_authoring` / `cross_experiment_analysis` / `research_critic` (for **non-Kimi-authored** creators) stay allowed (directive §6; the `by_creator_vendor.kimi`=non-kimi invariant is never relaxed by quota state — F5); generic `research_strategy` is **excluded** from kimi; other kimi routes fall back |
| EXHAUSTED | **100 %** of a cap, **2 consecutive rate/auth failures**, `auth_expired`, `cli_missing`, **or subscription period passed** | `KIMI_LOW_QUOTA.flag` written → **lane disabled**; an **OWNER-visible reason** is surfaced (routing receipt / mission control), never auto-purchase; fallbacks per the candidate tables (§6) |

**Period-end visibility (F7):** because the month boundary is a known, measurable date, the governor raises CONSERVE as period-end approaches and EXHAUSTED once it passes, with an OWNER-visible reason — so the subscription cannot silently run out only to be discovered at first `rate_limited`/`auth` failure (directive §25). No auto-purchase / renewal — OWNER-only (directive §1.1).

### 7.3 The flag is consumed by BOTH planes (closes the pacing gap)

The router-vs-execution pacing gap (`GATED_AGENTS={codex,claude}`, `quota_spawn_gate.py:36`; a chain-only flag never stops `route_once` — router_providers §3, critic §2) is closed by wiring the flag into **both**:
- **Plane A:** `sync_default_registry` disables/limits the kimi lane when `KIMI_LOW_QUOTA.flag` exists — the exact pattern used for `CLAUDE_DISABLED.flag` (`agent_router.py:1072-1074`).
- **Plane B:** `agent_chain.vendor_gate` reads `gates.kimi_low_quota_flag` (§6), and the orchestration branch checks the flag before spawning.

**Backtests are never affected** (directive §6; `quota_spawn_gate._intrinsic_deterministic`; data_memory §5 — MT5 workers self-throttle independently and win contention). No auto-purchase / renewal — OWNER-only (directive §1.1).

---

## 8. Scheduled tasks (§10 of directive scope)

Add to `install_agent_orchestration_scheduled_tasks.ps1` (definitions `:42-46`; router_providers §8):
- `QM_StrategyFarm_KimiOrchestration_15min` — runs the kimi orchestration branch. **Installed only after the §13 probe battery passes AND the smoke receipt.** Use the plain SYSTEM branch (install ps1 `:83-91`) unless the probe shows the credential refresh needs the console-session hop (`:68-82`). `MaxSessions=1` (auth race, `:31-41`) — note `MaxSessions=1` guards only same-task overlap; cross-plane serialization is the adapter lock (§3.6).
- `QM_StrategyFarm_KimiGovernor_15min` — mirrors `QM_StrategyFarm_AgyGovernor`, runs `kimi_governor.py`.

Existing critique sweep `QM_StrategyFarm_AgentChain_Critique_15min` (`agent_chain.py critique-pending --apply --max 2`) picks up kimi vendors automatically once §6 lands (drift §undocumented-mechanisms 1). Because that sweep is a **second, registry-blind Plane-B spawner**, the adapter single-flight lock (§3.6) is what prevents it racing the orchestration lane on the credential.

---

## 9. Observability / routing receipts (D3, directive §21; R-I)

- **Orchestration result JSON** under `D:/QM/strategy_farm/logs/` (`run_agent_orchestration_task.py:987`): `agent, execution_backend, model_contract, slot, prompt_path, live_log, command, cwd, worktree, started_at, pid, returncode, ok, finished_at`. The kimi lane uses the plain file lock (`acquire_lock`), not the codex-only managed lease (router_providers §6), **plus** the adapter single-flight lock (§3.6).
- **Chain receipt** `qm.agent-chain.receipt.v1` under `D:/QM/strategy_farm/state/agent_chain/<chain_id>.json` — the **real field paths** (R-I): `plan.creator` / `plan.critic` (each carrying `vendor`, `model`), `stages[].seat`, `critic_verdict`, `finding_counts`, `scope_drift`, `receipt_path`, `critic_fallback_used`, `critic_seat_final`; per-stage `prompt.md` + vendor log + `answer.md` (router_providers §6). A critic run that mutated the repo/`D:/QM` records stage status `critic_wrote` and no formatter stage (§3.5).
- **Routing receipt per high-value task** (D3): JSON under `D:/QM/strategy_farm/logs/routing_receipts/` — `task_id, capability, candidates_considered, chosen_provider, reason, quota_states`. This is the "compact routing receipt" the directive §7 requires and is written by Fable/the router when it selects a non-deterministic seat; the governor's period-end EXHAUSTED reason (§7.2) is surfaced here.
- **Usage ledger** (§7.1) is the Kimi-specific spend telemetry; subscription period + whatever usage indicators exist are recorded, and **no token/USD values are invented** (directive §21).

---

## 10. R1 internal source class (integration hook; detail in the source-contract doc, D5; R-A/R-B/R-C)

Full contract is `INTERNAL_RESEARCH_SOURCE_CONTRACT.md`. Integration-relevant facts (cards_r1_research audit):

- R1 is **already source-agnostic**: `_card_r1_build_ready` returns `bool(source_id non-empty)` (`farmctl.py:4229-4237`); `R_STRICT_PASS_FIELDS = (r2_mechanical, r3_data_available, r4_ml_forbidden)` excludes R1 (`:4219,4467-4471`). This is the substrate — but a bare non-empty `source_id` is **no longer sufficient** for the internal class; it must resolve (below).
- **Fail-closed enforcement point for the internal-source class (R-A).** Two code paths perform the same verify:
  1. `card_intake_prescreen.evaluate_card` gains a branch: when frontmatter `source_type == internal_research` **OR** `source_id` matches `^QM-RESEARCH-\d{4}-\d{4}$` → `research_source.verify(id)` must succeed: **artifact dir present**; `source.md` sha256 **== card `source_hash`**; the `research.json` / `lineage.json` / `critic_receipt.json` hashes are **present in the `source.md` manifest block**; and the ledger row status is in `{reviewed, preregistered, carded}`. Otherwise **REJECT** with reason **`INTERNAL_SOURCE_UNRESOLVED`**.
  2. `farmctl approve-card` (the G0 promotion path, `_card_r1_build_ready`) performs the **same** verify and refuses.
  3. **`author = Kimi` without a resolvable artifact is exactly that REJECT** (`INTERNAL_SOURCE_UNRESOLVED`) — directive §2 "`source = Kimi` without a resolvable artifact is invalid".
  4. **External cards: unchanged code path** (external attribution rules unchanged).
- **Hash anchoring (R-B):** `source.md` carries a fenced **manifest block** listing sha256 of `research.json`, `lineage.json`, `critic_receipt.json` (and any dataset manifests it cites); the card's `source_hash = sha256(source.md)`; the ledger row records the same. Any later edit = a **new version id with a parent link** — immutability by content hash + append-only ledger + git history.
- **DSR coupling (R-C) — NO gate-criteria change.** No change to the DSR/FDR formula or to how `dsr_cohort` computes counts (ROT). The research layer's `search_history_ledger` is the **evidence** for the `research_trial_count` the existing single-configuration/card contract already declares. An internal card must declare `research_trial_count >= ` the ledger's count for its hypothesis family; the intake check **fails closed** when the ledger shows searches but the card declares 0. **Numeric provenance rule:** every quantitative claim in a QM-RESEARCH artifact references a computed output file (projector/campaign JSON with sha256), never an LLM-computed number (directive §6). `dsr_cohort.py` already carries `search_history` / `research_trial_count` / `effective_trial_count` (`:751-758`); the edge-discovery search-history ledger feeds those (detail in `KIMI_EDGE_DISCOVERY_DESIGN.md`).
- **One required prescreen scoping change:** scope `card_intake_prescreen._affirmative_prohibited_mechanics` (`:464-489`, trips `PROHIBITED_MECHANICS:ML` at `:541-543`) to the mechanics sections, exempting a `## Research provenance` section, so ML-provenance prose is not auto-rejected (critic §5; cards_r1_research §2b). The runtime R4 ML scan is **untouched** — it scans only `.mq5/.mqh` with comments/strings blanked (`build_check.ps1 Invoke-ForbiddenScan :888-960`), so an ML-authored *research* provenance never trips *runtime* R4. **This scoping change must NOT ship ahead of the signed HR14/R4 Vault annex** (§16.3).
- `farmctl.VALID_SOURCE_TYPES` (`:33580-33583`) += `internal_research` (needed only if a routable DB `sources` row via `add-source` is wanted; AI cards today are card+decisions-only).
- Durable store `strategy-seeds/sources/QM-RESEARCH-YYYY-NNNN/` (`source.md`, `research.json` with sha256, `critic_receipt.json`, `lineage.json`); append-only registry `D:/QM/reports/state/research_source_ledger.jsonl`; resolver `tools/strategy_farm/research_source.py` (`mint`/`resolve`/`verify`: `QM-RESEARCH://id → path + sha check`, fail-closed on `critic_receipt.repo_write=true` per §3.5/R-D). External attribution rules unchanged.

---

## 11. Routing policy — how Fable chooses (directive §4, §7; R-H)

For every non-deterministic task Fable estimates reasoning depth, context requirement, novelty, value of an independent lens, semantic complexity, expected information gain, current provider quota, historical quality, and latency (directive §7). Then:
- **Deterministic task** (metric a script can compute) → Python/SQL/tooling, never an LLM (directive §4, §6 "LLMs never compute metrics a script can compute").
- **Large-scale cross-experiment synthesis / novel-edge hypothesis / ML-assisted discovery** → **Kimi preferred** when quota is NORMAL (directive §7).
- **Generic `research_strategy` / log-summary** → **low-value class**: prefer gemini/codex; kimi only as a bounded last resort and **never** in CONSERVE (§5.2, R-G).
- **MQL5/Python implementation** → Codex. **Architecture synthesis / OWNER-facing writing** → Fable/Claude. **Source discovery** → Antigravity or Kimi. **Independent critique** → a provider *different from the creator* (cross-vendor, §6).
- Mechanically, once task types + cost_rank land (§5), the deterministic router selects by `required ⊆ caps` then `cost_rank ASC`; Fable overrides via payload capability pins or `decision_bound_agent` for high-value work and records the routing receipt (§9).
- **CONSERVE** narrows kimi to high-value research only; **EXHAUSTED** falls back to the candidate tables (§7).
- **Research objective metrics (R-H)** split into authoring-time computable (novelty via strategy-fingerprint distance + hypothesis-family taxonomy; mechanizability via `mechanization_check`; falsifiability via a required FALSIFICATION section with a numeric kill rule; reproducibility via dataset manifest hashes + preregistration record) vs post-pipeline observed (robustness / portfolio usefulness / independence from Q-gate and portfolio evidence), each with the computing file — the objective is quality on these axes, not strategy count (directive §9, §20). Detail lives in `KIMI_EDGE_DISCOVERY_DESIGN.md`.

---

## 12. Failure handling — a Kimi failure never corrupts a task

The directive requires "a Kimi failure must never corrupt an existing task" (§5). Existing mechanisms deliver this:
- **Bounded retries (max 2) + error classes** in the adapter (§3.4); `auth_expired`/`cli_missing` raise to governor state, never a silent loop.
- **Router idempotency:** a lane that cannot execute leaves the row claimable; the `spawn_leases`/`LEASE_TTL_MINUTES=30` release path (`agent_router.py:103-104`) and lane-heartbeat staleness de-list (`:617`, `_lane_heartbeat_stale`) return an abandoned kimi claim without a verdict — re-routed on the next cycle.
- **Chain fallback:** `vendor_gate` fails closed on unknown/gated vendors, on missing CLI, and on a missing/expired credential (§6, F6), and `open_critic_seats` walks the candidate table, so a gated/broken kimi seat falls to the next seat with `critic_fallback_used=true` / `cross_vendor=false` recorded, never a corrupted receipt (§6, §9).
- **Critic-wrote is a failed run:** a critic that mutated the repo or `D:/QM` state has its output discarded, stage status `critic_wrote`, no formatter run (§3.5, R-D).
- **REVIEW-terminal + no verdict-write path** (§4.2): a kimi task can never write a verdict, so a failed kimi run cannot poison gate/verdict state.
- **Backtests / MT5 workers untouched** regardless of kimi state (§7.3; directive §5, §22 "no effect on MT5 workers if Kimi is unavailable").

---

## 13. Probe battery — one-time in implementation (D1)

Run **at most 7 tiny calls** LATER in implementation (not in this design pass), to settle the UNVERIFIED items. **The Kimi orchestration/critique scheduled tasks are installed only after probes 4, 5, 7 pass** (the read-only-critic gate, F1):

1. **Prompt delivery** — `-p` argv vs `-p @file` pointer vs stdin (32 KB cmdline limit; whether `acp` is needed for large prompts).
2. **stream-json event schema** — the framing the adapter parses to final assistant text; also the well-formed-JSON/wrong-schema shape (§14, F9).
3. **Exit codes on auth failure** — simulated by a bogus provider config in a temp `HOME` (no real quota burned).
4. **`--add-dir` write test (read-only-critic gate, R-D/F1)** — does `--add-dir` grant *write* access to the named dir, and to the repo when the repo is only read-scoped? Required before any unattended critic run.
5. **`--plan` denies writes? (read-only-critic gate, R-D/F1)** — does `--plan` (and/or the deny-writing-tools agent-file posture) genuinely prevent Bash/Write execution? Required before any unattended critic run.
6. **stdin-vs-TTY/ConPTY** — does a SYSTEM/pipe invocation run headless or hang (agy-class)?
7. **Credential refresh under SYSTEM** — does the 15-min token refresh succeed session-0, or is the console-session hop required (§3.6, §8)?

Do not burn meaningful subscription capacity on retry tests — use mocks (directive §22). Never `--add-dir` the live tree under `--auto` for a critic until probes 4 and 5 pass.

---

## 14. Test matrix (directive §22 → concrete test files)

| Directive §22 requirement | Test file · case |
|---|---|
| basic Kimi CLI invocation | `tests/test_kimi_adapter.py::test_invoke_stream_json_parses_final_text` (mock subprocess) |
| authentication failure | `test_kimi_adapter.py::test_auth_expired_classified_no_silent_retry` |
| timeout | `test_kimi_adapter.py::test_watchdog_timeout_classified` |
| rate/quota failure | `test_kimi_adapter.py::test_rate_limited_class` + `test_kimi_governor.py::test_conserve_on_quota_streak` |
| malformed output (non-JSON) | `test_kimi_adapter.py::test_malformed_stream_json_class` |
| schema failure (valid JSON, wrong/renamed events) | `test_kimi_adapter.py::test_stream_json_schema_mismatch_class` (guards silent breakage after CLI auto-update — F9) |
| retry exhaustion | `test_kimi_adapter.py::test_retry_exhaustion_max2` |
| unavailable CLI | `test_kimi_adapter.py::test_cli_missing_class` |
| fallback provider | `test_agent_chain.py::test_kimi_gated_falls_to_next_critic_seat` |
| chain gate fails closed on missing CLI / credential | `test_agent_chain.py::test_kimi_vendor_gate_fails_closed_no_cli_or_cred` (F6) |
| quota-conservation mode | `test_kimi_governor.py::test_states_normal_conserve_exhausted` + flag read `test_agent_router.py::test_kimi_low_quota_disables_lane` |
| subscription period end → CONSERVE/EXHAUSTED with reason | `test_kimi_governor.py::test_period_end_raises_conserve_then_exhausted` (F7) |
| gemini-down does not let kimi capture generic research | `test_agent_router.py::test_generic_research_prefers_gemini_codex` + `test_kimi_governor.py::test_generic_research_excluded_in_conserve` (F4) |
| Kimi Creator → non-Kimi Critic | `test_agent_chain.py::test_kimi_creator_critic_is_non_kimi` (invariant: no kimi in `by_creator_vendor.kimi`, never relaxed by quota state — F5) |
| non-Kimi Creator → Kimi Critic | `test_agent_chain.py::test_kimi_eligible_as_critic_for_claude_codex` |
| critic that wrote is a failed run (repo + D:/QM scope) | `test_kimi_adapter.py::test_critic_write_repo_fails_run` + `test_critic_write_dqm_state_fails_run` + `test_agent_chain.py::test_critic_wrote_status_no_formatter` (F1/R-D) |
| Kimi internal source → R1 PASS | `tests/test_internal_research_source.py::test_valid_kimi_source_passes` |
| Kimi name without artifact → R1 FAIL | `test_internal_research_source.py::test_author_kimi_without_artifact_fails` (`INTERNAL_SOURCE_UNRESOLVED`) + `test_missing_hash_fails_closed` |
| approve-card enforces the same verify | `test_farmctl_approve_card.py::test_internal_source_unresolved_refused` (R-A) |
| research_trial_count vs ledger fails closed | `test_internal_research_source.py::test_declared_trials_below_ledger_fails` (R-C) |
| critic_receipt repo_write=true fails verify | `test_internal_research_source.py::test_repo_write_receipt_fails_closed` (R-D) |
| external unattributed FAILS / external valid PASSES | `test_internal_research_source.py::test_external_unattributed_fails` / `test_external_valid_passes` |
| ML research → mechanical Strategy Card conversion | `test_card_intake_prescreen.py::test_ml_provenance_section_not_rejected` + `test_mechanization_check.py::test_finite_params_no_ml_terms` |
| rejection of an EA requiring runtime ML | `test_mechanization_check.py::test_runtime_ml_ea_rejected` (and existing `build_check` scan) |
| restart/recovery | `test_agent_orchestration_lock.py` (kimi lock/lease release) |
| secret leakage | `test_kimi_adapter.py::test_no_secret_fields_logged` |
| concurrency — adapter single-flight lock | `test_kimi_adapter.py::test_max_parallel_1_enforced` (asserts the **cross-process adapter lock**, not the registry field — F2/R-E) |
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
6. **Do not connect Kimi's hypothesis volume to DSR without counting trials** (critic §7; R-C): uncounted kimi trials silently inflate survivorship. No change to the DSR formula (ROT); the edge-discovery `search_history_ledger` supplies the evidence for `research_trial_count`, and an internal card must declare `research_trial_count >=` the ledger count for its hypothesis family (intake fails closed on a 0-vs-nonzero mismatch). `dsr_cohort.py` already carries the fields (`:751-758`); detail in `KIMI_EDGE_DISCOVERY_DESIGN.md`.
7. **Research intermediates off D:** D: was ~65 GB free at audit (below purge lines); kimi/research outputs stay small and on C:/G:, gated on worker CPU/RAM latches (data_memory §5,§7) so backtests keep winning contention.

---

## Appendix A — UNVERIFIED items to resolve in implementation

- stream-json event schema; `-p` file-pointer vs stdin vs `acp` for large prompts; non-zero exit-code taxonomy; concurrency/rate-limit behaviour; whether `status_line usage` is subscription-remaining or per-session; credential refresh success under SYSTEM (session-0); plan-mode output shape; **whether `--add-dir` grants write and whether `--plan`/an agent-file posture genuinely denies write tools** (the read-only-critic gate). All are settled by the §13 probe battery; probes 4, 5, 7 gate the install of `QM_StrategyFarm_KimiOrchestration_15min` / the kimi critique path.

---

## Appendix B — Review disposition

Review file: `docs/ops/evidence/2026-09-15_kimi_integration/design/KIMI_INTEGRATION_ARCHITECTURE.review.json` (verdict `ACCEPT_WITH_FIXES`). Findings numbered in review order.

| # | Sev | Claim (abbrev.) | Disposition |
|---|---|---|---|
| F1 | blocking | Critic read-only enforced only by post-hoc repo git-hash guard; no probe verifies read-only; scope is repo only, D:/QM verdict store reachable under `--auto`. | **applied (resolved-by-orchestrator, R-D).** Primary = probe-verified read-only posture (agent-file denying write tools) + `--add-dir` scratch-dir-only with repo read access (probes 4,5 in §13, install-gated); secondary = adapter hash guard extended to **both** repo and D:/QM state paths; `critic_wrote` → output discarded, no formatter (§3.5, §9); `research_source.verify` fails closed on `repo_write=true` (§10). The review's "throwaway copy" mechanism is superseded by R-D's posture-first guard — noted in §3.5. |
| F2 | major | `max_parallel=1` is registry-only (Plane A); two Plane-B spawners can race the OAuth refresh. | **applied (R-E).** `kimi_adapter.py` holds a machine-wide single-flight lock (named mutex/lockfile w/ pid) around every invocation regardless of caller; `max_parallel=1` is the second belt; `test_max_parallel_1_enforced` asserts the adapter lock (§3.6, §14). |
| F3 | major | §4.2 cited a prompt docstring (`:273-294`) as an "exact code guard" for verdict/APPROVED. | **applied (R-F).** §4.2 split into code-level guards (capability omission → unclaimable rows; no verdict-write path in any Kimi branch; T_Live never in `--add-dir`; no `farmctl` subcommand callable by a Kimi task) vs process-level guards (REVIEW-terminal, receipts, orchestrator review); the docstring reclassified as prompt-level reinforcement. |
| F4 | major | cost_rank=12 protects only while gemini enabled; gemini currently auth-degraded → kimi captures generic research funnel and burns the subscription. | **applied (R-G).** §5.2 documents the gemini-down interaction; governor caps 40/day, 200/week, CONSERVE 70 %, EXHAUSTED 100 % or 2 consecutive rate/auth failures; generic `research_strategy` is a low-value class preferring gemini/codex and excluded from kimi in CONSERVE (§7.2, §11); tests added (§14). |
| F5 | minor | §7.2 CONSERVE wording read as permitting Kimi-critiques-Kimi. | **applied.** Reworded to "research_critic (only for non-Kimi-authored creators; the `by_creator_vendor.kimi`=non-kimi invariant is never relaxed by quota state)" (§7.2). |
| F6 | minor | Chain gate read only the flag; D4 wants flag + CLI-present + credential-present. | **applied.** `vendor_gate` fails closed on missing flag **and** missing CLI **and** missing/expired credential (§6); test added (§14). |
| F7 | minor | Subscription period recorded but governor ignored the measurable month boundary. | **applied.** Governor acts on the recorded period: CONSERVE as period-end approaches, EXHAUSTED once passed, OWNER-visible reason in receipts (§7.2, §9); test added (§14). |
| F8 | minor | Credential is a plain-JSON world-readable bearer token; at-rest exposure unaddressed. | **applied.** One-line install hardening: verify/tighten ACL on the credential file to qm-admin/SYSTEM only; adapter logs field-names/expiry-epoch only (§3.6). |
| F9 | minor | §14 collapsed "malformed output" and "schema failure" into one test. | **applied.** Split into `test_malformed_stream_json_class` (non-JSON) and `test_stream_json_schema_mismatch_class` (valid JSON, wrong/renamed events); added `schema_mismatch` error class (§3.2, §3.4, §14). |

All items the review marked **keep** are retained: two-plane model with the flag consumed by both planes; cost_rank=12 with the "never < 10" rule; R1-source-agnostic recognition with the prescreen scoping change gated behind the signed HR14/R4 annex; runtime R4 untouched; layered LLM-PASS-≠-pipeline-PASS defence; `by_creator_vendor.kimi`=non-kimi; DSR trial-counting hook; case-by-case §22 test matrix; probe battery deferred and capped with mocks; single-commit discipline + full rollback table; research intermediates small/off-D:; the git-hash guard kept as the secondary detector (now prevention-first via R-D, extended to D:/QM).

## Addendum 2026-09-15 11:1xZ — probe battery results that amend §3 (implementation C1, commit see git log)

- `--auto` and `--plan` do NOT combine with `-p` (argparse rejects both). Creator/research roles therefore run plain `-p` (non-interactive, auto-runs Read/Write inside `--add-dir`); §3.1's `--auto` assumption is withdrawn.
- Read-only critic posture = `--agent-file` with a `tools:` allowlist that omits Write (prevention, proven: the model could not create a file); the `git status --porcelain` before/after guard on C:/QM/repo stays as the detection belt (`critic_wrote`, output discarded).
- stream-json = JSONL; final text = last `{"role":"assistant","content":<non-empty>}`; `cli_version` from the `system.version` meta line. Pointer prompt file proven with a 72 KB prompt; argv stays tiny.
- Auth-failure simulation (redirected HOME) exits 1 with `No model configured … /login`; the real credential file was never touched.
- Ledger `D:/QM/reports/state/kimi_usage_ledger.jsonl` (first real line = adapter smoke), flag `D:/QM/strategy_farm/KIMI_LOW_QUOTA.flag` (MANAGED_BY=kimi_governor, evaluated, not set), plus `state/kimi_adapter.lock` and `state/kimi_governor_state.json`. Evidence: `docs/ops/evidence/2026-09-15_kimi_integration/probe_battery/README.md`.

## Review disposition 2026-09-15 (adversarial review fix slice)

Second adversarial review (5 lenses, `docs/ops/evidence/2026-09-15_kimi_integration/review/lenses.json`)
on the six committed slices. Surviving findings and how the fix slice closed them (no
live Kimi calls; all paths injectable in tests):

| # | Finding (surviving) | Fix (files) |
|---|---|---|
| F1 | Governor wrote `KIMI_LOW_QUOTA.flag` only on EXHAUSTED and in a key=value body; CONSERVE was inert end-to-end and EXHAUSTED worked only by the routers' fail-closed accident. The flag body contract disagreed across writer/readers. | `kimi_governor.reconcile_flag` now writes ONE canonical JSON body (`schema qm.kimi-low-quota-flag/v1`, `state`, `managed_by`, `reason`, `set_at_utc`, `counts`, `caps`) on **both** CONSERVE and EXHAUSTED, clears only on NORMAL-and-owned, rewrites on a state transition. `_flag_owned` reads `managed_by` from JSON and still tolerates the legacy `MANAGED_BY=` body. `agent_router.kimi_quota_state` (JSON-only, garbage → EXHAUSTED) and `agent_chain._read_kimi_flag_state` (JSON or key=value, MANAGED_BY-only → EXHAUSTED) both parse it. New `test_kimi_quota_flag_contract.py` drives the real governor at NORMAL/CONSERVE(≥70 %)/EXHAUSTED and asserts both planes agree and that `sync_default_registry`/`vendor_gate` react. (`kimi_governor.py`, config doc, tests) |
| F2 | Unattended `creator`/`research` roles had Kimi's full default toolset (Bash/PowerShell) — authority guards were prompt-level, not mechanical, for those roles. | `config/kimi_adapter.v1.json`: `creator`/`research`/`formatter` now use a no-shell `--agent-file` (`research_agent_file_content`: Read/Grep/Glob/List/Write/Edit, no Bash/PowerShell); `critic` keeps the read-only allowlist. New role `research_ml` keeps the shell and `run_kimi` accepts it **only** when `allow_shell=True` (config `requires_allow_shell`); the orchestration lane and `agent_chain` never pass it. `build_argv` materialises the per-role agent file. Tests: research/creator argv carry no shell tool; `research_ml` without `allow_shell` → ValueError. (`kimi_adapter.py`, config, tests) |
| F3 | Mutation guard was repo-only and critic-only; `_dir_listing_hash` was dead; the D:/QM scope from R-D was unimplemented; the named test was absent. | `run_kimi` hashes (a) `git status --porcelain` of `C:/QM/repo` **and** (b) a `(path,size,mtime)` listing of `protected_trees` (config; defaults D:/QM state + reports/state + cards_approved + T_Live MQL5/config), skipping absent paths and excluding the adapter's own ledger/lock/state files. Result carries `repo_write`, `protected_write`, `changed_paths`. Critic → `critic_wrote` on either scope; research/creator/formatter → status `protected_write` (text kept, flagged; surfaced by the lane via the status field). Temp-tree tests. (`kimi_adapter.py`, config, tests) |
| F4 | Valid-JSON-wrong-schema collapsed into `malformed_output`; no distinct class or test. | Added `STATUS_SCHEMA_MISMATCH`: valid JSONL with no recognizable assistant content → `schema_mismatch` (config-class, not retried), distinct from non-JSON → `malformed_output`; the text-mode fallback is skipped when JSON was seen. Tests for both. (`kimi_adapter.py`, tests) |
| F5 | Concurrency covered only by single-threaded lock-state detection; the architecture-named `test_max_parallel_1_enforced` did not exist. | Added `test_max_parallel_1_enforced`: two threads call `run_kimi` with a fake spawn blocking on an Event; exactly one runs, the other returns status `error` / `single_flight_busy`. (tests) |
| F6 | `lineage.json` schema collision: `research_source.mint` writes no `versions` key; `preregister._update_lineage` did `lineage["versions"].append` → KeyError on a minted artifact. | `preregister._update_lineage` initialises `versions=[]` when absent and preserves all existing C4 keys; one schema id `qm.research-lineage/v1` with a `versions[]` array both tools share. Test: mint (temp store) → preregister → v1 parent None → changed spec → v2 parent v1, no crash. (`research/preregister.py`, tests) |
| F7 | No test that non-kimi lanes are unaffected when Kimi is EXHAUSTED / cli_missing. | Router test: with kimi EXHAUSTED and with kimi absent from the registry, `build_ea`/`ops_issue` still route to their non-kimi lanes and `work_items` is untouched (the router never calls the adapter). (tests) |
| F8 | `QM_KIMI=0` honoured only inside the adapter; the chain still selected kimi. | `agent_chain.vendor_gate` kimi branch returns `kill_switch_QM_KIMI=0` when `QM_KIMI=0` (consistent with the adapter's no-spawn kill switch); other vendors unaffected. Test added. (`agent_chain.py` kimi gate, tests) |
| F9 | §4.2 claimed mechanical enforcement the code delivered only for the critic role; docs did not distinguish mechanical from prompt+detection+review, nor note `research_ml`. | §3.5 role table + honesty note generalise the no-shell posture to all unattended roles and document `research_ml`/`allow_shell`; §3.5 secondary guard rewritten to the implemented two-scope guard; §4.2 adds an explicit mechanical-vs-prompt+detection+review honesty note; this section appended. (`KIMI_INTEGRATION_ARCHITECTURE.md`) |

Scope respected: no changes to `dsr_cohort`/`terminal_worker`/`farmctl` gate code, T_Live, or D:/QM at runtime; no live Kimi calls (fake/mocks only). Not addressed here (out of the fix-slice scope, tracked separately): the missing `QM_StrategyFarm_KimiGovernor_15min` scheduled task (governor is call-driven only for now), single-flight pid-liveness on the stale path, routing-receipt field-name drift, the committed worked-example hash mismatch, and the auto-updater version-pin/alert — all minor/ops-lens items from the same review.
