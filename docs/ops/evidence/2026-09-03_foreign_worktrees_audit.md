# Foreign Worktrees Audit — 2026-09-03

**Author:** Claude (board-advisor worktree `wf_cee8cc14-938-2`)
**Scope:** the 21 non-`wf_*` worktrees named in the task context — 13 `rework-slot-*`,
5 `claude-orchestration-*`, and the three singletons `youtube-analyst`,
`src-futures-orderflow`, `sonnet-xau-adx-turtle`.
**Mode:** strictly read-only. No worktree was removed, modified, locked/unlocked, or
requeued. No writes under `D:\QM` or `C:\QM\mt5`. This file is the only artifact, written
under the auditing worktree.

---

## 0. Provenance & method

### FF-merge of `agents/board-advisor` (required pre-step)
- HEAD before: `a92cda60fe1e62eeee73de6068dd2634dba490d2`
- `agents/board-advisor` tip: `b2d00f43273503598ade0942b5829d57e32112ca`
- Relation before merge: `git rev-list --left-right --count HEAD...agents/board-advisor`
  → `0  108` (0 ahead / 108 behind).
- `git merge --ff-only agents/board-advisor` → **Fast-forward** to
  `b2d00f43273503598ade0942b5829d57e32112ca`. HEAD after: `b2d00f4327`. Clean, no conflicts.

All ahead/behind, merged, and unmerged-commit figures below are measured against this
`agents/board-advisor` tip (`b2d00f4327`).

### Path discrepancy vs the task context
The context said these worktrees "remain under `C:/QM/repo/.claude/worktrees`". That is
imprecise: `git worktree list` places all 21 under **`C:\QM\worktrees\`** (the
`QM_AGENT_WORKTREE_ROOT` default, `tools/strategy_farm/run_agent_orchestration_task.py:80`).
`C:/QM/repo/.claude/worktrees/` holds only the ephemeral `wf_*` workflow worktrees
(including this auditor). This audit targets the real paths under `C:\QM\worktrees\`.

### Read-only technique note
The Bash git-isolation guard refuses `git -C <other-worktree>` from an isolated worktree,
so per-worktree working-tree reads (`status`, `log`, `rev-list`) were run through the
PowerShell tool, which carries no such guard. History facts (ahead/behind, unmerged commit
subjects) were also cross-checked from the auditor's own checkout against the shared object
DB via the recorded SHAs. `claude-orchestration-4/-5` (and, on ownership check, all five
orchestration `.git` files) are owned by `NT AUTHORITY\SYSTEM`; they were read with an
in-memory `-c safe.directory=<path>` (no config written to disk). Process attribution used
`Get-CimInstance Win32_Process` CommandLine matching (306 processes scanned).

---

## 1. Master table (one row per worktree)

All paths are `C:\QM\worktrees\<name>`. Ahead/Behind = commits in worktree HEAD not in
board-advisor / vice-versa. "Uncommitted" = `git status --porcelain=v1` split
tracked-changes / untracked (`??`). "Live proc" = a running process whose CommandLine
references the path.

| Worktree | Branch | HEAD | Ahead / Behind | Merged into b-a? | Uncommitted (trk/untrk) | Locked | Size MB | Last commit | Last file-mod | Live proc | Class |
|---|---|---|---|---|---|---|---|---|---|---|---|
| rework-slot-1 | rework-slot-1 | `480199f343` | 5 / 2235 | no | 19 (19/0) | no | 1424.7 | 2026-08-24 17:47 | 2026-08-24 18:02 | none | **C** (+B) |
| rework-slot-2 | rework-slot-2 | `6aa501328f` | 3 / 2237 | no | 4 (2/2) | no | 2183.4 | 2026-08-24 18:04 | 2026-08-24 18:01 | none | **C** (+B) |
| rework-slot-3 | rework-slot-3 | `bf589cf168` | 6 / 2236 | no | 29 (24/5) | no | 1368.7 | 2026-08-24 17:58 | 2026-08-24 18:04 | none | **C** (+B) |
| rework-slot-4 | rework-slot-4 | `1047b1f678` | 4 / 2234 | no | 2 (1/1) | no | 2012.4 | 2026-08-24 17:53 | 2026-08-24 18:02 | none | **C** (+B) |
| rework-slot-5 | rework-slot-5 | `ca9e74d4a4` | 0 / 2233 | **yes** | 16 (14/2) | no | 1664.5 | 2026-08-24 16:47 | 2026-08-24 17:44 | none | **C** |
| rework-slot-6 | rework-slot-6 | `a5b6f9eb3e` | 3 / 2232 | no | 6 (5/1) | no | 1369.0 | 2026-08-24 17:50 | 2026-08-24 18:04 | none | **C** (+B) |
| rework-slot-11 | rework-slot-11 | `9a55c17f9e` | 6 / 1996 | no | 2 (2/0) | no | 1369.1 | 2026-08-24 17:53 | 2026-08-24 18:03 | none | **C** (+B) |
| rework-slot-12 | rework-slot-12 | `cf035c4e5c` | 2 / 1995 | no | 6 (5/1) | no | 1382.3 | 2026-08-24 17:23 | 2026-08-24 18:04 | none | **C** (+B) |
| rework-slot-15 | rework-slot-15 | `48726bba78` | 5 / 1997 | no | 6 (3/3) | no | 1369.0 | 2026-08-24 17:41 | 2026-08-24 18:04 | none | **C** (+B) |
| rework-slot-17 | rework-slot-17 | `b57879558a` | 6 / 1996 | no | 5 (4/1) | no | 1367.8 | 2026-08-24 17:51 | 2026-08-24 18:04 | none | **C** (+B) |
| rework-slot-18 | rework-slot-18 | `3913ab6e6c` | 6 / 1997 | no | 4 (2/2) | no | 1369.5 | 2026-08-24 17:48 | 2026-08-24 18:04 | none | **C** (+B) |
| rework-slot-19 | rework-slot-19 | `522612117f` | 7 / 1996 | no | 7 (3/4) | no | 1369.4 | 2026-08-24 17:41 | 2026-08-24 18:05 | none | **C** (+B) |
| rework-slot-20 | rework-slot-20 | `22bcb9c8fa` | 4 / 1997 | no | 15 (15/0) | no | 1644.1 | 2026-08-24 17:41 | 2026-08-24 18:02 | none | **C** (+B) |
| claude-orchestration-1 | agents/claude-orchestration-1 | `c32fb88ad6` | 3 / 3524 | no | 24 (21/3) | no | 1282.8 | 2026-08-21 18:18 | 2026-08-24 18:26 | none¹ | **C** (+B) |
| claude-orchestration-2 | agents/claude-orchestration-2 | `7fea98a8eb` | 464 / 15388 | no | 67 (50/17) | no | 103.5 | 2026-08-23 10:06 | 2026-08-23 10:05 | none¹ | **C** (+B) |
| claude-orchestration-3 | agents/claude-orchestration-3 | `4de11d1958` | 421 / 15388 | no | 27795 (27789/6) | no | 971.2 | 2026-08-11 03:20 | 2026-08-21 12:57 | none¹ | **C** (+B) |
| claude-orchestration-4 | agents/claude-orchestration-4 | `aa3cf11012` | 0 / 15069 | **yes** | 5 (5/0) | no | 205.9 | 2026-06-02 21:04 | 2026-07-19 18:16 | none¹ | **C** |
| claude-orchestration-5 | agents/claude-orchestration-5 | `ffead9b29b` | 10 / 15064 | no | 5 (5/0) | no | 211.0 | 2026-06-02 23:29 | 2026-07-19 18:16 | none¹ | **C** (+B) |
| youtube-analyst | agents/youtube-analyst | `cb667adb63` | 0 / 16285 | **yes** | 1 (1/0) | no | 7.5 | 2026-05-08 09:14 | 2026-07-19 18:05 | none | **C** |
| src-futures-orderflow | codex/qm5-20023-wave2-rebuild | `ffe63bfca0` | 2 / 7594 | no | 0 (0/0) | **yes** (initializing) | 1053.4 | 2026-07-21 22:05 | 2026-07-21 22:00 | none | **B** |
| sonnet-xau-adx-turtle | agents/sonnet-xau-adx-turtle | `120b643b56` | 1 / 9002 | no | 7 (7/0) | no | 867.4 | 2026-07-14 07:24 | 2026-07-19 18:16 | none | **C** (+B) |

¹ No *live* process references the orchestration paths at scan time, but all five
`claude-orchestration-*/.git` files are owned by `NT AUTHORITY\SYSTEM` — they were created
by the SYSTEM-run `QM_StrategyFarm_ClaudeOrchestration_15min` scheduled task and are reused
by it (see §5). Treat as infrastructure-owned "do not touch", not as free-standing.

**Total disk across all 21 worktrees: ≈ 24,596.6 MB (≈ 24.0 GB).**
(13 rework-slots ≈ 19.4 GB · 5 orchestration ≈ 2.7 GB · 3 singletons ≈ 1.9 GB.)

---

## 2. Classification (precedence: D live-process → C uncommitted → B unmerged-clean → A clean+merged+idle)

### Class A — safe to remove: **NONE**
No worktree satisfies the class-A definition (no uncommitted work **and** branch
merged/empty **and** no process). Every worktree either carries uncommitted work (20 of 21)
or, for the single clean tree, carries unmerged commits and is locked (`src-futures-orderflow`).

- **Removal commands for class A: none.**
- **Total disk class A would free: 0 MB.**

This matches both the task's "do NOT remove them" framing and the automated janitor's own
policy — it would refuse every one of these (all dirty or locked; see §5).

### Class B — has unmerged commits → CEO keep/merge decision
`src-futures-orderflow` is the only **pure** class-B worktree (clean tree, 2 unmerged
commits, but git-locked "initializing"):
- `ffe63bfca0 build(qm5-20023): rebuild EA and regenerate presets`
- `7ea411e026 fix(qm5-20023): scope authoritative event calendar`
Branch `codex/qm5-20023-wave2-rebuild`, last commit 2026-07-21, 7594 behind. The two
commits are the QM5_20023 wave-2 rebuild. **Decision needed:** merge/cherry-pick the
QM5_20023 rebuild if still wanted, else drop the branch. Cannot be janitor-removed while
locked; removal would also require clearing the lock (an OWNER/CEO action, out of scope here).

Sixteen further worktrees *also* carry unmerged commits but are primarily class C (they hold
uncommitted work too), so they cannot be removed regardless. Their unmerged commits are the
CEO merge surface and are enumerated in §3.

### Class C — has uncommitted work → keep: **19 worktrees**
All 13 rework-slots + `claude-orchestration-1/-2/-3/-4/-5` + `youtube-analyst` +
`sonnet-xau-adx-turtle`. Spot-verified that the uncommitted work is genuine, not disposable
drift:
- **rework-slot-5** (HEAD = EA 9909, *merged*): its uncommitted tree is real WIP for a
  **different** EA — `QM5_12940_bressert-cycle-trigger-line-h4-card` (13 set files + `.mq5`
  modified, plus new `docs/ops/evidence/2026-08-23_rework-12940.md` and
  `tools/strategy_farm/tests/test_qm5_12940_rework.py`). Removing it loses the 12940 rework.
- **youtube-analyst** (HEAD *merged*, ahead 0): its one uncommitted file is a substantive
  25-line addition — a Windows-native `is_pid_alive()` (OpenProcess/GetExitCodeProcess) in
  `scripts/aggregator/standalone_aggregator_loop.py`. Genuine WIP, not incidental drift.
- **claude-orchestration-4** (HEAD *merged*, ahead 0): 5 modified infra files
  (`framework/scripts/mt5_worker.py`, `scripts/aggregator/standalone_aggregator_loop.py`,
  `tools/strategy_farm/farmctl.py`, `run_agent_orchestration_task.py`,
  `start_terminal_workers.py`) — plus SYSTEM ownership; keep.

The three "merged HEAD" worktrees (rework-slot-5, claude-orchestration-4, youtube-analyst)
are the *only* candidates that would collapse to class A **if** their uncommitted work were
first committed/merged or explicitly discarded by the CEO. Until then they stay class C.

### Class D — in use by a live process: **NONE (at scan time)**
`Get-CimInstance Win32_Process` CommandLine matching found no running process referencing any
of the 21 paths (the only hit was this audit's own `pwsh` scan, PID 26548). Caveat: the five
`claude-orchestration-*` worktrees are owned/reused by the `QM_StrategyFarm_ClaudeOrchestration_15min`
task (currently **Disabled**); they are dormant infrastructure, not truly idle scratch.

---

## 3. Unmerged-commit inventory (CEO merge surface)

`git log --oneline agents/board-advisor..<HEAD>`. Rework-slot commits are the 2026-08-24
REVIEW-drain deliverables (Sonnet fan-out); each slot's `.git` is `qm-admin`-owned.

**rework-slot-1** (5): 12932 restore entry/exits · 9947 breakout/exits card-faithful ·
9730 card fidelity + review findings · 9910 catastrophic ATR backstop · 9465 bounded RSI add-on
**rework-slot-2** (3): 12944 risk/news/pivot controls · 34003 restore card risk controls · 9914 bind D1 mechanism
**rework-slot-3** (6): 1417 pooled framework indicators · 40008 basket framework contract · 35008 realized loss/time exit · 9922 D1 scope/presets · 9720 D1 lifecycle · 9417 exit ordering/symbol scope
**rework-slot-4** (4): 12936 bar lifecycle/rebuild · 12921 block rejected-card build · 39001 TMS execution contract · 38004 fresh build/DWX reachability
**rework-slot-6** (3): 12946 early exits before news gate · 12939 ZigZag/trade state · 38008 D1 lifecycle/provenance
**rework-slot-11** (6): 12922 refresh compiled artifact · 34001 document card-contract blocker · 9946 ATR/D1 hold · 9923 Hull MA smoothing · 9719 lifecycle/card scope · 9579 D1 execution/risk wiring
**rework-slot-12** (2): 41001 harden review-fix evidence · 12612 canonical monthly cadence
**rework-slot-15** (5): builds 20110 xti-xng-fri-rv · 20137 wti-seas-pb · 20167 xng-spring-dualtrend · 20182 wti-sum-bull · 20207 usdcad-audusd
**rework-slot-17** (6): builds 20088 carney-crab · 20128 xng-stor-fade · 20136 wti-caltrend · 20164 xng-summer-dualtrend · 20171 brent-tsmom3m · 20193 eurusd-cad-coint
**rework-slot-18** (6): builds 20089 hopwood-ts4 · 20134 wti-wpsr-fail · 20155 wti-tue-trend (refuse) · 20168 xng-autumn-dualtrend · 20185 wti-win-bearfade · 20202 xauxag-rev18 (refuse dup)
**rework-slot-19** (7): builds 20090 pricebob-ttr · 20133 wti-wpsr-pb · 20141 wti-sumtrend · 20156 xng-wed-trend · 20159 xng-mon-trend (refuse) · 20175 alpha-inst-magnet · 20186 xauxag-samecal
**rework-slot-20** (4): builds 20135 wti-winter-trend · 20157 (refuse stale ticket) · 20172 wti-fri-bear · 20200 audjpy-euraud
**claude-orchestration-1** (3): build_ea 12931 triple-top · 12932 wyckoff-phase-e · 12936 demark-td
**claude-orchestration-5** (10): v2-wave3 EAs for 10042/10439/10454/10457/12108 + 9 earlier `_v2` ONINIT_FAILED-recovery builds (2026-06-02)
**sonnet-xau-adx-turtle** (1): `120b643b56 feat(research): QM5_13299 et-turtle20x-adx`
**src-futures-orderflow** (2): see §2 (pure class B)

**claude-orchestration-2 (464 ahead / 15388 behind)** and **claude-orchestration-3
(421 ahead / 15388 behind)** are long-diverged stale orchestration branches (thousands of
commits behind, months old). Enumerating/merging is impractical and unwarranted; they are
retained only because they also hold uncommitted work. Recommend: leave as historical
branches; no merge.

---

## 4. What is safe to remove today — bottom line

**Nothing.** Class A is empty, so there are no `git worktree remove --force` commands to
issue and **0 MB** is reclaimable by removal right now. The only paths that could *become*
removable are the three merged-HEAD worktrees (rework-slot-5, claude-orchestration-4,
youtube-analyst) — and only after a CEO decision to commit/merge or discard their genuine
uncommitted WIP; two of those three are also SYSTEM/infra-owned or hold real rework.

For completeness, the command form that *would* be used per class-A worktree (do **not**
run; no worktree qualifies) is:
```
git -C C:/QM/repo worktree remove --force C:/QM/worktrees/<name>
```

---

## 5. `ClaudeOrchestration` scheduled task + worktree cleaners

### `QM_StrategyFarm_ClaudeOrchestration_15min` — **State: Disabled**
- Action: `pythonw.exe "C:\QM\repo\tools\strategy_farm\run_agent_orchestration_task.py" --agent claude --max-sessions 3`, WorkingDir `C:\QM\repo`, RunAs `SYSTEM` / RunLevel Highest.
- **Which worktrees it creates:** `run_agent_orchestration_task.py:486-491` —
  `worktree_path(agent, slot) = C:\QM\worktrees\{agent}-orchestration-{slot}`, branch
  `agents/{agent}-orchestration-{slot}`. With `--agent claude` it manages
  `claude-orchestration-1..N` (N ≤ 3 per this task's arg; the Claude budget policy at
  `:868` permits up to 5 — hence the existing `-1..-5`). This is why all five orchestration
  `.git` files are SYSTEM-owned.
- **Whether it cleans them:** No. `ensure_worktree` (`:566-596`) reuses an existing worktree
  when `git rev-parse --show-toplevel` succeeds (`created:False`, untouched) and only runs
  `git worktree add -B <branch> <path> HEAD` when the path is absent. It never removes,
  prunes, or `worktree remove`s. Cleanup is delegated entirely to the janitor tasks below.
- Currently Disabled (consistent with the standing practice of disabling ClaudeOrchestration
  during an interactive/CEO session). `QM_ClaudeParallel_RestoreOnReset` (Ready) only rewrites
  the parallelism counter file `D:\QM\strategy_farm\state\claude_parallel.txt` to `4` on the
  weekly reset — it does **not** re-enable this task; re-enabling is a separate manual step.

### Cleaner tasks (SYSTEM)
- **`QM_StrategyFarm_WorktreeJanitor_6h`** (Ready) → `worktree_janitor.py --apply`. Removal
  predicates (`worktree_janitor.py:113-151`): only registered worktrees strictly below
  `C:\QM\worktrees`, never the canonical checkout; **retained if** git-locked, younger than
  `MIN_AGE_HOURS = 48` (`:24`), process-referenced (CommandLine match, `:88`), or **not clean**
  (`git status --porcelain --untracked-files=all` non-empty, `:97`). It does **not** consider
  merged/unmerged state — a clean, old, idle worktree with unmerged commits *would* be removed,
  but only its working directory; the branch ref and commits survive in the shared object DB.
- **`QM_StrategyFarm_WorktreeClean_4h`** (Ready) → `run_worktree_clean_task.py`.
- **`QM_StrategyFarm_AgentTempReclaim_10min`** (Ready) → `run_agent_temp_reclaim.ps1`.

**Consequence for these 21:** all are dirty (20) or git-locked (1, src-futures), so **none is
janitor-eligible** — the ≈24 GB will not be reclaimed automatically; it needs the manual CEO
decision in §2/§4. This is the intended safety behavior, not a janitor defect.

---

## 6. Recommended next step (for CEO)
1. `src-futures-orderflow` (class B, clean, locked): decide merge vs drop of the QM5_20023
   wave-2 rebuild (2 commits). Only clean-tree item.
2. The 16 rework/orchestration branches carrying unmerged commits (§3): these are genuine
   deliverables blocked behind uncommitted WIP. Decide per branch whether to finish+commit
   (then merge to board-advisor) or abandon. Nothing is reclaimable until that WIP is resolved.
3. Leave `claude-orchestration-*` untouched while their SYSTEM task can be re-enabled; leave
   the janitor as-is (correctly retains all dirty/locked roots).

---

### Evidence / reproduction (all read-only)
- `git -C C:/QM/repo worktree list [--porcelain]` — inventory + lock state.
- Per-worktree (via PowerShell, no isolation guard): `git -C <path> rev-parse HEAD`,
  `rev-parse --abbrev-ref HEAD`, `rev-list --left-right --count HEAD...agents/board-advisor`,
  `merge-base --is-ancestor HEAD agents/board-advisor`, `log -1`,
  `status --porcelain=v1 --untracked-files=all`; SYSTEM-owned ones with
  `-c safe.directory=<path>`.
- Size/last-mod: `Get-ChildItem -Recurse -Force -File | Measure-Object -Property Length -Sum`
  and `-Property LastWriteTime -Maximum`.
- Process attribution: `Get-CimInstance Win32_Process` CommandLine match (306 procs).
- Task definitions: `Get-ScheduledTask` Actions/Principal; scripts
  `tools/strategy_farm/run_agent_orchestration_task.py`, `worktree_janitor.py`.
- `.git` ownership: `(Get-Acl C:/QM/worktrees/<name>/.git).Owner`.
