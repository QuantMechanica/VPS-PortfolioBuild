# Company Audit Live Sources

Date: 2026-05-30

Use this file when restarting an agent or doing a company audit. The retired
orchestration stack is not a source of truth; do not use its old directory or dashboards as health
signals.

## Current Runtime Model

- Factory MT5 terminals: `D:\QM\mt5\T1` through `D:\QM\mt5\T10`.
- Live trading terminal: `C:\QM\mt5\T_Live`.
- `T_Live` is the former live T6 and is not part of the factory backtest pool.
- Factory phase names are `Q00` through `Q13`. Old `P*` keys may remain in generated
  compatibility files and should not be reported as canonical phase names.

### Addendum 2026-09-13 — v4 linear pipeline Q00–Q17 (supersedes "Q00 through Q13" above)

The `Q00` through `Q13` phase model above is stale. Since the **2026-08-23 v4 rebaseline**
the pipeline is a single strictly-monotone linear path **Q00–Q17** in three macro-phases.
There is **no separate "Q14–Q16 optimization branch"**: the optimization/requalification
stages are linear gates **Q09–Q14**, and **Q15–Q17** are the book-evaluation phase reachable
only via the fail-closed book trigger. Canonical source:
`tools/strategy_farm/config/gate_manifest.v4.json` (`status: ACTIVE`,
`activation_guard.state: ACTIVE`, `activated_at: 2026-08-23`, `default_manifest_switch: true`),
`decisions/2026-08-23_owner_gate_manifest_v4_linear.md`, Vault `03 Pipeline/Pipeline Overview`.

Gate names, verbatim from the active v4 manifest:

- **Q09** Baseline Full Run · **Q10** News Impact + FTMO Recommendation · **Q11** Incumbent
  Full-History Confirmation
- **Q12** Pattern Filter Selection (DL-089 pre-registered pattern-filter census; cap 3
  filters/direction; zero filters selected = valid pass-through)
- **Q13** Parameter Optimization & Freeze (challenger build + freeze; challenger re-runs Q02→Q11)
- **Q14** Best-Settings Head-to-Head — **TERMINAL** (`next: null`,
  `terminal_optimization_gate: true`, outcomes `CHALLENGER_PROMOTED` / `KEEP_INCUMBENT`); the
  OWNER path-to-25 counter counts terminal Q14 pairs
- **Q15** Final Portfolio Construction (book-trigger only: ≥25 qualified + signed OWNER order) ·
  **Q16** Operational Readiness · **Q17** Live Burn-In DXZ
  (`docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md`)

**Correction to a circulated draft addendum:** an earlier draft mislabelled these gates as
"Q11 portfolio, Q13 numeric sweep, Q15 challenger spawn". Those do **not** match the manifest —
portfolio construction is **Q15**, parameter optimization & freeze (challenger build) is **Q13**,
and **Q11** is Incumbent Full-History Confirmation. This addendum follows the manifest.

Source lines, `gate_manifest.v4.json`:

- `{"id":"Q14", ..., "name":"Best-Settings Head-to-Head", "next":null, "terminal_optimization_gate":true, "valid_outcomes":["CHALLENGER_PROMOTED","KEEP_INCUMBENT"]}`
- `{"id":"Q15", ..., "name":"Final Portfolio Construction", "entry_policy":"BOOK_TRIGGER_ONLY"}`
- `{"id":"Q16", ..., "name":"Operational Readiness"}` · `{"id":"Q17", ..., "name":"Live Burn-In DXZ", "next":null}`

Storage keeps legacy `P*`/v3 Qxx keys for migration reads only; operator surfaces show v4 Qxx
exclusively. NOTE: the manifest file also carries a stale internal `draft_note` calling itself
"PROPOSAL ONLY" — that field predates activation; the authoritative `status` / `activation_guard`
fields, `Pipeline Overview`, and the 2026-08-23 decision record confirm v4 is the active contract.

## Audit Source Order

1. Live processes:
   - `terminal64.exe` / `metatester64.exe`
   - `python.exe` / `pythonw.exe` terminal workers and Qxx scripts
   - `pwsh.exe` `run_smoke.ps1`
   - `claude.exe`, `codex.exe`, and their child processes
2. Strategy farm database and state:
   - `D:\QM\strategy_farm\state\farm_state.sqlite`
   - `D:\QM\strategy_farm\state\health.json`
   - `D:\QM\strategy_farm\state\quota_snapshot.json`
3. Work-item evidence:
   - `D:\QM\reports\work_items\...\Qxx\...\aggregate.json`
   - `D:\QM\reports\work_items\...\summary.json`
   - raw MT5 reports/logs under the same work item
4. Farm controller commands from `C:\QM\repo`:
   - `python tools\strategy_farm\farmctl.py health`
   - `python tools\strategy_farm\farmctl.py mt5-slots`
   - `python tools\strategy_farm\agent_router.py status`
   - `python tools\strategy_farm\agent_router.py list-tasks --agent claude`
   - `python tools\strategy_farm\agent_router.py list-tasks --agent codex`
5. Repo/worktree state:
   - `C:\QM\repo`
   - `C:\QM\worktrees\*`

## Stale Or Compatibility Sources

These files can be useful as exported snapshots, but they are not sufficient for a live
audit:

- `public-data\public-snapshot.json`
- `D:\QM\reports\state\pipeline_state.json`

The former static `company-runtime` export was removed because it represented a
retired agent hierarchy rather than current runtime state. Do not recreate it as a
health source.

If these mention `P2`, `P3`, `P3.5`, or old T6/T_Live assumptions, report them as stale
or compatibility data and verify against live Qxx work-item evidence.

## Claude Token Hygiene Checks

Before starting or trusting Claude orchestration, check for stale spawned sessions:

```powershell
Get-CimInstance Win32_Process -Filter "Name='claude.exe' OR Name='git.exe' OR Name='git-remote-https.exe' OR Name='git-credential-manager.exe'" |
  Select-Object ProcessId,ParentProcessId,Name,CreationDate,CommandLine
```

Red flags:

- many `claude.exe -p --model sonnet ...` sessions with no matching active router tasks;
- old `git push origin agents/claude-orchestration-*` process trees;
- `git-credential-manager get` processes older than a few minutes;
- `QM_StrategyFarm_ClaudeOrchestration_15min` running while `agent_router.py list-tasks
  --agent claude` returns `[]`.

Throttle Claude before spending more tokens: stop stale Claude processes, stop stale Git
children, and keep Claude orchestration disabled until there is a concrete premium-review
queue. Codex should handle default code/ops/build work.

## Annex 2026-09-15 — Architecture drift audit (corrected runtime facts) (OWNER-DEC-KIMI-INTEGRATION-20260915)

Authority: `decisions/2026-09-15_owner_kimi_integration_ml_research_r1_internal.md`
(OWNER-DEC-KIMI-INTEGRATION-20260915). Source: read-only drift audit
`docs/ops/evidence/2026-09-15_kimi_integration/audit/drift.md`. This annex appends the
corrected runtime facts the audit found; it does not alter any historical text above.
Truth precedence: live scheduled-task actions and code/JSON state over doc prose.

**Headline:** the hard-bounded contracts (gate names Q00–Q17, tool paths, the
gemini→agy binding, Claude=Sonnet) are faithful. Drift is concentrated in (a) one
reboot-recovery pointer at a disabled task, (b) a tester-purge threshold, (c) the agy
lane's role, and (d) several live control-plane mechanisms never documented in CLAUDE.md.

| # | Doc claim | Corrected runtime reality | Evidence | Severity |
|---|-----------|---------------------------|----------|----------|
| 1 | "After a VPS reboot, check `QM_StrategyFarm_TerminalWorkers_AT_STARTUP`." | That task is **Disabled** (LastRun 23.05.2026). Workers come up via `QM_StrategyFarm_FactoryON_AtLogon` → `Factory_ON.ps1 -CanonicalRuntimeHost -NoPause`. | `Get-ScheduledTask` state/action | HIGH |
| 2 | Tester purge "no-op ≥150GB free; LowWater 80→150 seit 2026-07-21", every 10 min. | 10-min cadence correct; the live task action runs **`-LowWaterGB 60`**. | `QM_StrategyFarm_TesterCachePurge` action ARG `-LowWaterGB 60`; `Interval=PT10M` | MEDIUM |
| 3 | "Antigravity (agy) — broad research…"; MEMORY "agy = backup only." | The live registry `gemini` lane still declares `code, tests, repo_edit`; the orchestration prompt still allows agy to draft code. Treat those caps as deprecated/backup-only pending an OWNER trim decision — do NOT copy the ambiguity onto the `kimi` lane. | `agent_router.py DEFAULT_AGENT_REGISTRY['gemini']` | MEDIUM |
| 4 | Quota section names only `quota_governor.py` (+ `agy_governor.py`). | A separate **Codex weekly budget line** (`codex_budget_line.py`, OWNER 2026-09-13) + **`codex_fleet_pacer.py`** pace the Codex lane on task `QM_StrategyFarm_CodexFleetPacer` (PT5M); rollback `QM_CODEX_BUDGET_LINE=0`. | task action; `codex_budget_line.py` header | MEDIUM |
| 5 | No mention of an automated cross-vendor critic outside EA builds. | `agent_chain.py critique-pending --apply --max 2` runs a Creator→Critic→Formatter chain over pending REVIEW rows every 15 min (task `QM_StrategyFarm_AgentChain_Critique_15min`), read-only cross-vendor critics, receipts under `D:/QM/strategy_farm/state/agent_chain/`. | task action; `agent_chain.py` header | MEDIUM |
| 6 | Gate naming (hard-bounded) / tool paths / gemini-via-agy / headless Claude=Sonnet. | **No drift** — all 18 names Q00–Q17 match the active `gate_manifest.v4.json`; 14/14 tool paths exist; gemini executes via agy; headless Claude runs Sonnet. (This branch's body still carries the stale "Q00 through Q13" wording; the 2026-09-13 addendum on main supersedes it.) | manifest dump; file-existence loop; code | none |

**New in this period (must not repeat the undocumented-mechanism pattern):** the Kimi
research provider (registry lane `kimi`, `kimi_governor.py`, `KIMI_LOW_QUOTA.flag`,
`QM_StrategyFarm_KimiGovernor_15min`, `QM_StrategyFarm_KimiOrchestration_15min`) is
documented in CLAUDE.md and `docs/ops/KIMI_INTEGRATION_ARCHITECTURE.md` in the same change.
