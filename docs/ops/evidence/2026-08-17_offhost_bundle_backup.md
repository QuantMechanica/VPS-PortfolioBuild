# Evidence secured off-host without a push permission (2026-08-17)

`git push` is blocked at the harness permission layer in both Bash and PowerShell. That is
established, is not retested, and the command is not disguised to route around a refusal. It
needs a Bash permission rule from OWNER. **None of that was required to remove the
total-loss risk**, which is what this does.

## Correction first: 91 unpushed commits, not 736

I have repeatedly reported "730 / 736 commits unpushed". That number was
`git rev-list --count origin/main..HEAD` — the divergence from **main**, which includes every
commit this branch has ever carried. The at-risk quantity is the distance from the branch's
own last pushed state:

```
origin/agents/board-advisor = 95827f7058a614a821b33fae7d22739e38ec7629
agents/board-advisor        = e4505d7e8528019d9c7ca41028e5bdabd30dd838
git rev-list --count origin/agents/board-advisor..agents/board-advisor = 91
```

**91 commits are unpushed.** The 736 figure was measuring the wrong distance and overstated
the exposure by 8×. Correcting it also makes the mitigation far cheaper — see below.

## What was created

**1. Full-history bundle on D:**

```
D:\QM\backups\git_bundles\qm-repo_agents-board-advisor_20260817T1040Z.bundle
2,296,098,125 bytes (2.3 GB)
git bundle verify -> "The bundle records a complete history."
```

Acceptance was not the `verify` line alone. The bundle's own branch tip was compared against
the repository:

| Source | SHA |
|---|---|
| bundle `refs/heads/agents/board-advisor` | `e4505d7e8528019d9c7ca41028e5bdabd30dd838` |
| `git rev-parse HEAD` | `e4505d7e8528019d9c7ca41028e5bdabd30dd838` |
| `git rev-parse refs/heads/agents/board-advisor` | `e4505d7e8528019d9c7ca41028e5bdabd30dd838` |

All three identical. The bundle also records `refs/remotes/origin/agents/board-advisor` at
`95827f705`, which independently confirms the push gap above.

**2. Unpushed-delta bundle, mirrored off-host:**

```
D:\QM\backups\git_bundles\qm-repo_unpushed-delta_20260817T1040Z.bundle
6,674,939 bytes (6.7 MB)
git bundle create <out> origin/agents/board-advisor..agents/board-advisor
git bundle verify -> requires base 95827f705, provides e4505d7e
mirrored to: G:\My Drive\QM_Backups\git_bundles\
```

**`G:` is a Google Drive mount and is writable (48 GB free), so this copy is genuinely
off-host** — it leaves the VPS through Drive sync. That is the part that actually removes the
total-loss risk, and the delta bundle is the right artifact for it: it contains exactly the
irreplaceable work and is 340× smaller than the full history. A 2.3 GB full bundle synced
repeatedly would fill the 48 GB Drive quota in about twenty copies and is the wrong thing to
mirror.

The delta bundle requires base `95827f705` to unpack, which any clone of the pushed remote
already has — so the pair (public remote + this 6.7 MB file) reconstructs the full state.

## Retention, because this is scheduled work and not a one-off

A scheduled export must not accumulate: 2.3 GB full bundles on D: (156 GB free) or on G:
(48 GB) will exhaust either target. Design handed to the scheduler task:

- delta bundle every run — cheap, mirrored to G:, keep the last N;
- full bundle rarely (weekly or on demand), D: only, keep one;
- both named with the HEAD SHA so a bundle can be matched to a state without unpacking.

## Remaining gap, stated once

There is still **no true off-host git remote receiving pushes**. Drive sync of a bundle is a
backup, not a remote: it gives recovery, not collaboration, and not the branch-protection or
history that a hosted remote provides. Closing that needs either the Bash permission rule or a
decision that bundle export is the permanent answer. **That is an OWNER decision and it is
recorded once here rather than repeated each round.**

## Evidence

- `D:\QM\backups\git_bundles\` — both bundles with their sizes and verify output above
- `G:\My Drive\QM_Backups\git_bundles\qm-repo_unpushed-delta_20260817T1040Z.bundle`
- HEAD at time of export: `e4505d7e8528019d9c7ca41028e5bdabd30dd838`
