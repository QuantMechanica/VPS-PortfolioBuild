# MNT-031 — repository, worktree, and integration truth contract

Date: 2026-08-21  
Router task: `9abed1bd-0f23-4847-bb41-b0b6685e66e0`  
Branch: `agents/board-advisor`  
Inventory: `docs/ops/evidence/2026-08-21_mnt031_worktree_inventory.json`

## Verdict

`CONTRACT_AND_READ_ONLY_INVENTORY_READY_FOR_REVIEW`

No fetch, checkout, reset, branch update, merge, cherry-pick, push, worktree
move/removal, or cleanup was performed. This document and its inventory are
committed from the canonical operative checkout, not from an orphan branch.

## Binding branch/worktree contract

1. **Canonical operative checkout:** `C:/QM/repo` on
   `agents/board-advisor`. Factory tools, operator evidence, and ops artifacts
   are read and committed here. A clean/dirty statement is meaningful only
   with this exact path, branch, and HEAD.
2. **Integration authority:** `origin/main` is the comparison/integration
   target, but only Claude+OWNER close-outs may advance it. Agents do not merge,
   cherry-pick, reset, or fast-forward `main`.
3. **Local main worktree:** `C:/QM/worktrees/cto_main` is OWNER/Claude
   integration staging. Its local `main` ref is not current-state authority and
   must never be used as a proxy for `origin/main` or the operative branch.
4. **Agent worktrees:** `C:/QM/worktrees/*` are task-isolated authoring or
   analysis contexts. Their changes have no production effect until explicitly
   reviewed and integrated through the authorized close-out path.
5. **Runtime worktrees:** `C:/QM/runtime_worktrees/*` are detached execution
   materializations owned by Pipeline-Operator. They are not source-of-truth
   branches and must not be promoted merely because a runtime used them.
6. **Detached/legacy worktrees:** detached or unclassified paths default to
   `Claude+OWNER disposition`; they are neither operative nor integration
   authority. Archive/removal requires separate authorization and recoverable
   backup evidence.
7. **Ahead/behind semantics:** every number must name its comparison ref and
   captured OID. “Unpushed” is used only for a branch with a configured
   upstream. For the 65 branches without one, unpushed is undefined—not zero.
8. **Production provenance:** dashboards/build evidence should name checkout
   path, branch/ref, and commit. A commit found only on a task/orphan branch is
   not a production change.

## Captured ref facts

The inventory was generated at `2026-08-21T11:28:51Z` without fetching:

| Ref/path | Captured HEAD | vs captured `origin/main` |
|---|---|---:|
| `origin/main` | `3f8c5a1164fc62518ed0ec418aa8cc39dde464ca` | baseline |
| `C:/QM/repo` / `agents/board-advisor` | `652f3d3f508ca2cf6a5162e09bb0a57a115bb6c2` | 7 ahead, 0 behind |
| `C:/QM/worktrees/cto_main` / local `main` | `6aa27d286c88aa5705464edbd066363c573fd80e` | 14 ahead, 1,493 behind |
| scheduled slot `codex-orchestration-1` | `1a06c0bd51acaf5eb051937573fe25b2cdc2b2bc` | 12 ahead, 11,932 behind |

This corrects two unsafe shortcuts. First, the scheduled Codex worktree is far
behind and cannot stand in for the canonical checkout. Second, local `main` is
materially divergent from captured `origin/main`; it is not safe integration
input merely because its branch name is `main`.

## Inventory summary

- 59 registered worktrees.
- 23 dirty worktrees.
- 11 detached worktrees.
- 74 local branches; 65 have no upstream.
- 41 local branches are ahead of captured `origin/main` (non-deduplicated sum
  2,382 commits). This is a divergence indicator, not an integration plan.
- Four branches are ahead of their configured upstream. Their non-deduplicated
  ahead sum is 11,886, dominated by a deeply divergent Claude orchestration
  branch; the inventory preserves the per-branch values rather than repeating
  the earlier ambiguous “about 1,014 unpushed” claim.

Each worktree record includes path, HEAD, branch/detached/lock state,
ahead/behind versus the captured `origin/main` OID, configured upstream and
upstream divergence where defined, dirty tracked/untracked counts, owner,
owner-inference basis, and lifecycle role.

## Reproduction and verification

```powershell
python tools/strategy_farm/worktree_truth_inventory.py `
  --repo C:/QM/repo `
  --output C:/QM/repo/docs/ops/evidence/2026-08-21_mnt031_worktree_inventory.json

python -m pytest `
  tools/strategy_farm/tests/test_mnt031_worktree_truth_inventory.py -q

3 passed in 0.33s

inventory_validation=PASS worktrees=59 dirty=23 detached=11
```

The generator uses only `git worktree list`, `status`, `rev-parse`,
`for-each-ref`, and `rev-list`. It deliberately does not call `git fetch`.
