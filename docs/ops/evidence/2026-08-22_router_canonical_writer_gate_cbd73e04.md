# Canonical router writer gate and worktree currency contract

- Task: `cbd73e04-2cfe-422a-95fb-6633d46a55ad`
- Date: 2026-08-22
- Disposition: REVIEW
- Implementation commit: `a573365e6aa30677f83347812d6956c5f9068b47`
- Writer generation: `qm.router-writer/2026-08-22.v1`

## Outcome

`agent_router.py` now refuses `run`, `route-many`, `route-once`, and
`replenish` when its checkout has a linked-worktree `.git` file instead of the
canonical checkout's `.git` directory. The refusal is emitted as loud JSON that
names the command, executing checkout, `.git` marker, and canonical root.

The shared SQLite database now independently enforces the same authority. A
persisted writer-generation contract and triggers prevent a stale router that
does not contain the new Python guard from:

- inserting an agent task;
- changing task ownership;
- inserting, updating, or deleting the agent registry; or
- replacing the writer-generation contract.

Normal consumer completion fields remain outside these triggers. In particular,
a worker may still record its REVIEW artifact and verdict without becoming a
router.

Headless agent prompts now use absolute `C:/QM/repo` paths for `health`,
`status`, `list-tasks`, and `update-task`, and explicitly prohibit all four
router-writer commands. The separate `QM_StrategyFarm_AgentRouter_5min`
scheduled task remains the sole operational routing authority.

## 30-day live-log audit

Audit window: 2026-07-23 through 2026-08-22 05:00 UTC. The upper bound excludes
the currently running audit session so searches recorded in its own live log do
not recursively count as historical command executions.

Method:

- Codex logs retain tool transcripts. A match required the executable transcript
  form `-Command ... agent_router.py <writer-command> ... in <checkout>`.
- Claude and Gemini logs retain compact completion narratives rather than full
  tool transcripts. A match required an explicit completed `run`, `route-many`,
  `route-once`, or `replenish` statement; the companion orchestration JSON bound
  the session workspace.
- `git worktree list --porcelain` supplied heads without modifying any checkout.
  Ahead/behind is `worktree_head...canonical_head`, measured at
  `2026-08-22T05:58:38Z` against canonical head `a573365e6`.

| Recorded execution/session workspace | Matching logs | First / last evidence | Head at measurement | Ahead / behind canonical | Router policy present in that head | Can write router state after deployment? |
|---|---:|---|---|---:|---|---|
| `C:/QM/repo` | 98 Gemini sessions, plus 2 explicit Claude canonical overrides | `gemini_orchestration_slot1_20260815T084505Z.live.log` / `gemini_orchestration_slot1_20260821T181504Z.live.log`; Claude overrides `claude_orchestration_slot2_20260817T181507Z.live.log` and `...20260821T083004Z.live.log` | `a573365e6` | 0 / 0 | Current application and DB generation gates | Yes technically; operationally reserved to the scheduled router |
| `C:/QM/worktrees/codex-orchestration-1` | 46 direct command-bearing logs | `codex_orchestration_slot1_20260815T113002Z.live.log` / `codex_orchestration_slot1_20260822T040002Z.live.log` | `1a06c0bd51` | 12 / 12,245 | None: no writer gate and no OWNER human-lane hold | No; linked-checkout guard blocks current code and DB triggers block its stale code |
| `C:/QM/worktrees/claude-orchestration-1` | 10 completion logs | `claude_orchestration_slot1_20260816T090002Z.live.log` / `claude_orchestration_slot1_20260821T160001Z.live.log` | `c32fb88ad6` | 3 / 381 | None of the new writer-generation checks | No |
| `C:/QM/worktrees/claude-orchestration-2` | 7 completion logs; 2 explicitly used canonical instead, leaving 5 linked-worktree executions evidenced | `claude_orchestration_slot2_20260816T090002Z.live.log` / `claude_orchestration_slot2_20260821T130002Z.live.log` | `e3ccb00838` | 458 / 12,245 | None: no writer gate and no OWNER human-lane hold | No |
| `C:/QM/worktrees/claude-orchestration-3` | 2 completion logs | `claude_orchestration_slot3_20260816T111502Z.live.log` / `claude_orchestration_slot3_20260821T130002Z.live.log` | `4de11d1958` | 421 / 12,245 | None: no writer gate and no OWNER human-lane hold | No |

The registered but inactive `C:/QM/worktrees/gemini-orchestration-1` had no
orchestration-session JSON in this audit window: Gemini sessions used
`C:/QM/repo`. Its registered head was `1bea1f58b8` (0 ahead / 12,245 behind)
and lacked all new gates. It is SYSTEM-owned, so it was neither entered with
`git -C` nor added to `safe.directory`; its head was read only through the
canonical repository's worktree metadata.

All four historical linked execution heads lacked
`qm_router_writer_generation` and `RouterCheckoutError`. The three heads that
were 12,245 commits behind also lacked `ROUTER_AWAITING_HUMAN_LANE`, which is the
specific policy gap implicated by the 2026-08-22 OWNER-only video assignment.

## Worktree purpose and currency contract

The durable contract is:

1. Agent worktrees exist for isolated task implementation and artifact creation
   on their agent branch. They are not control-plane authorities.
2. Worktree currency is not trusted for queue, registry, lease, or routing
   behavior. All permitted control-plane reads and consumer updates use the
   absolute canonical scripts under `C:/QM/repo`.
3. Only `QM_StrategyFarm_AgentRouter_5min`, executing `C:/QM/repo`, may run a
   router-writer command. An agent session launched in `C:/QM/repo` is still
   prohibited by its role contract even though the checkout-level gate is
   technically satisfied.
4. Stale or dirty agent worktrees are not auto-merged, reset, or refreshed by an
   orchestration cycle. Rebuild/refresh is a separate OWNER-approved maintenance
   action. This remediation does not merge any of them.
5. `gemini-orchestration-1` remains untouched because it is SYSTEM-owned. Gemini
   continues to use the canonical shared repo for task execution, but consumes
   already-routed work only.

This separates artifact isolation from control-plane currency: a months-old
worktree can finish its assigned artifact without carrying a months-old router
into the shared queue.

## Enforcement layers

### Current-code checkout refusal

The CLI and callable functions both check the existing canonical-registry rule:
the executing checkout must have a `.git` directory. A linked worktree has a
`.git` file. Unit coverage invokes all four commands from a synthetic linked
checkout and verifies exit code 2 plus the named JSON refusal before any router
mutation.

### Shared-database stale-code refusal

Canonical connections register the connection-local generation function
`qm_router_writer_generation()`. Current code from a linked checkout registers
it as NULL; old code does not register it at all. Durable SQLite triggers compare
that function with the singleton `router_writer_contract` row. Consequently,
both current linked code and old code fail closed at the database boundary.

Live contract receipt after the implementation commit:

```text
generation:              qm.router-writer/2026-08-22.v1
canonical_checkout_root: C:\QM\repo
installed_at:            2026-08-22T05:58:20+00:00
installed_by_head:       a573365e6aa30677f83347812d6956c5f9068b47
```

A live raw connection that deliberately omitted the generation function was
tested inside rolled-back transactions. Results:

```text
registry update:  OperationalError: no such function: qm_router_writer_generation
task enqueue:     OperationalError: no such function: qm_router_writer_generation
task assignment:  OperationalError: no such function: qm_router_writer_generation
probe row count:  0
task assignee:    codex (unchanged)
```

## Verification

- `python -m py_compile tools/strategy_farm/agent_router.py tools/strategy_farm/run_agent_orchestration_task.py` — PASS.
- Focused router/prompt regression suite — `67 passed in 93.33s`.
- Canonical `agent_router.py status` — PASS; writer contract reported
  `authorized=true`, `.git` marker type `directory`, registry contract clean.
- Live SQLite schema inspection — PASS; seven durable triggers present (writer
  contract insert/update, registry insert/update/delete, task insert, and task
  assignment).
- Live stale-connection probes — PASS; three prohibited writer classes rejected
  and both postconditions unchanged.

No `run`, `route-many`, `route-once`, or `replenish` command was executed during
this remediation.
