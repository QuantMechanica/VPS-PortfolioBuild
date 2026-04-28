# QUA-184 — Documentation-KM Adapter CWD Worktree Rollout (2026-04-27)

## Scope

Rollout step under PC1-00 (parent QUA-181) to move the Documentation-KM agent's
adapter `cwd` from the shared repo root (`C:\QM\repo`) to a dedicated git
worktree (`C:\QM\worktrees\docs-km`) on branch `agents/docs-km`.

This isolates Documentation-KM file-write activity from concurrent writers in
other worktrees, satisfying the PC1-00 CWD-isolation control.

## Pre-state

- Agent id: `8c85f83f-db7e-4414-8b85-aa558987a13e` (Documentation-KM)
- Adapter type: `claude_local`
- Previous adapter `cwd`: `C:\QM\repo`
- Verified via: `GET /api/agents/me` (Bearer agent JWT)

## Worktree Convergence

Idempotent script (re-run safe):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File C:\QM\repo\infra\scripts\Ensure-AgentWorktree.ps1 `
  -RepoRoot C:\QM\repo `
  -WorktreeRoot C:\QM\worktrees `
  -AgentKey docs-km `
  -CreateBranchIfMissing
```

Result captured at `docs/ops/QUA-184_DOCS_KM_WORKTREE_PROOF_2026-04-27.json`:

- `status=ok`
- `action=created`
- `branch=agents/docs-km`
- `worktree_path=C:\QM\worktrees\docs-km`

Runtime checks (executed from the new worktree CWD):

- `git rev-parse --show-toplevel` → `C:/QM/worktrees/docs-km`
- `git branch --show-current` → `agents/docs-km`

## Adapter Config Patch

Performed via authenticated self-patch:

```http
PATCH /api/agents/8c85f83f-db7e-4414-8b85-aa558987a13e
Authorization: Bearer <agent JWT>
X-Paperclip-Run-Id: <run id>
Content-Type: application/json

{ "adapterConfig": { "cwd": "C:\\QM\\worktrees\\docs-km" } }
```

The route at `app/server/src/routes/agents.ts:2047` merges (no
`replaceAdapterConfig`) so all instructions-bundle keys, `model`, and
`dangerouslySkipPermissions` remain untouched. `cwd` is in the adapter-agnostic
key set and is the only field changed.

A new agent config revision is recorded automatically (`recordRevision.source =
"patch"`), enabling rollback via:

```http
POST /api/agents/8c85f83f-db7e-4414-8b85-aa558987a13e/config-revisions/<previous-revision-id>/rollback
```

## Verification (markdown / export jobs)

Documentation-KM's day-to-day surface is reading and writing markdown under
`docs/`, `lessons-learned/`, `processes/`, and `branding/`. From the new
worktree, these paths resolve to a working tree on branch `agents/docs-km` that
shares the canonical `.git/` directory with `C:\QM\repo`. Verified:

- `ls C:\QM\worktrees\docs-km\docs\ops\` lists synced ops docs (e.g.
  `AGENT_SKILL_MATRIX.md`, `EPISODE_GUIDE.md`, `LIVE_T6_AUTOMATION_RUNBOOK.md`).
- The worktree HEAD is at the latest commit on `agents/docs-km` and tracks the
  same object database as the main repo, so future
  `git add/commit/push` operations from within the worktree publish to the
  agent branch and remain mergeable into `main`.

For Notion → Git nightly export, no path changes are required: the export
target is `docs/` *relative* to the agent's adapter cwd, which now points at
the worktree. Export jobs continue to write to `docs/...` as before; the
absolute path is now `C:\QM\worktrees\docs-km\docs\...`.

All git operations from the worktree should continue to use the per-repo
mutex wrapper (`infra/scripts/Invoke-GitWithMutex.ps1`) per the PC1-00 hard
rule.

## Rollback

Two equivalent rollback paths exist; either is sufficient.

### Path A — API revision rollback (preferred)

1. List config revisions:

   ```http
   GET /api/agents/8c85f83f-db7e-4414-8b85-aa558987a13e/config-revisions
   Authorization: Bearer <agent JWT>
   ```

2. Identify the most recent revision *before* this rollout (the one with
   `adapterConfig.cwd = "C:\\QM\\repo"`).

3. Roll back:

   ```http
   POST /api/agents/8c85f83f-db7e-4414-8b85-aa558987a13e/config-revisions/<id>/rollback
   Authorization: Bearer <agent JWT>
   X-Paperclip-Run-Id: rollback-qua-184
   ```

### Path B — Direct re-PATCH

```http
PATCH /api/agents/8c85f83f-db7e-4414-8b85-aa558987a13e
Authorization: Bearer <agent JWT>
X-Paperclip-Run-Id: rollback-qua-184
Content-Type: application/json

{ "adapterConfig": { "cwd": "C:\\QM\\repo" } }
```

### Worktree teardown (optional, only if abandoning the rollout)

```powershell
git -C C:\QM\repo worktree remove C:\QM\worktrees\docs-km
git -C C:\QM\repo branch -D agents/docs-km   # destructive, OWNER approval required
```

Do **not** delete the worktree directory by hand — always go through
`git worktree remove` to keep the worktree registry consistent.

## Authority and Boundaries

- Self-patch is permitted: `assertCanUpdateAgent` (see
  `app/server/src/routes/agents.ts:386`) returns early when
  `actorAgent.id === targetAgent.id`.
- The patch only mutates the adapter `cwd` field. Instructions-bundle keys,
  `instructionsFilePath`, `instructionsRootPath`, `instructionsEntryFile`,
  `instructionsBundleMode`, and `agentsMdPath` are untouched, so the change
  does not require `agents:create` or instructions-path management
  permissions.
- AGENTS.md and any prompt content remain Git-canonical and are not modified
  by this rollout.

## Evidence

- Worktree convergence JSON: `docs/ops/QUA-184_DOCS_KM_WORKTREE_PROOF_2026-04-27.json`
- This runbook: `docs/ops/QUA-184_DOCS_KM_WORKTREE_ROLLOUT_2026-04-27.md`
- Agent config revision diff: visible via
  `GET /api/agents/8c85f83f-db7e-4414-8b85-aa558987a13e/config-revisions`
