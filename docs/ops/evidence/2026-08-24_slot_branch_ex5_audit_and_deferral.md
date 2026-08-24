# Slot-branch sanitization — complete audit, remediation deferred (concurrency blocker)

- **Task ID:** b4fe23af-4f60-42d1-bf00-a9ff3185fad6 (claude, ops_issue, priority 75)
- **Commissioned by:** claude-orchestrator 2026-08-24 Factory-CEO-Session
- **Title:** Slot-Branch-Sanierung: Ad-hoc-EX5 von rework-slot-1/2/6/11/12 strippen, dann merge-faehig melden
- **Generated:** 2026-08-24, claude-orchestration-3 (headless single-pass cycle)
- **Status: PARTIAL.** Full audit complete (exceeds the task's named scope). Remediation
  (stripping + rebinding + merge-ready declaration) **deferred** — see §3 for why, and §4 for the
  exact procedure to run once safe.

## 1. Root cause reference

`tools/strategy_farm/validate_ex5_commit_guard.py` docstring names the exact incident class this
task targets: ".ex5 bytes compiled ad hoc ... after the governed wrapper failed closed with
LIVE_FACTORY_AD_HOC_COMPILE_REFUSED, then committed anyway (39001 x2, 38001, 38008, 9914, 9947,
35008)." The guard is now active (fail-closed on any newly staged `.ex5` under `framework/EAs/`
lacking a matching `work_items` row with `kind='compile', phase='COMPILE_EA', status='done',
verdict='COMPILE_OK'` binding both `ex5_sha256` and `mq5_sha256`). This task cleans up the
pre-existing violations still sitting on unmerged rework-slot branches from before the guard went
live.

## 2. Full audit (exceeds the 4 EAs named in the task payload)

Reused the guard's own `find_receipt()` against the live `D:/QM/strategy_farm/state/farm_state.sqlite`,
applied to every commit unique to each of the 5 named branches relative to `agents/board-advisor`
(not just the 4 EAs the task payload named), computing each `.ex5`/`.mq5` pair's SHA256 from the
**actual committed blob** (`git show <commit>:<path>`, i.e. already on the canonical LF-blob basis
— see the companion task `8628cddd`).

| branch | commit | EA | receipt found? |
|---|---|---|---|
| rework-slot-1 | `e7710e7de8` | QM5_9730 | **NO** — not named in task payload |
| rework-slot-1 | `449f331daa` | QM5_9947 | **NO** — named in task payload |
| rework-slot-2 | `1444d7f3b9` | QM5_9914 | **NO** — named in task payload |
| rework-slot-2 | `977c42e58c` | QM5_34003 | **NO** — not named in task payload |
| rework-slot-2 | `6aa501328f` | QM5_12944 | **NO** — not named in task payload |
| rework-slot-6 | `4c36e0863b` | QM5_38008 | **NO** — named in task payload |
| rework-slot-6 | `3474c80109` | QM5_12939 | **NO** — not named in task payload |
| rework-slot-11 | `9a55c17f9e` | QM5_12922 | **NO** — not named in task payload |
| rework-slot-12 | (all commits) | QM5_12612, QM5_41001 | **N/A — clean**, no `.ex5` change lacking a receipt found (matches task payload's "sauber" label) |

**8 unreceipted `.ex5` commits found across 4 of the 5 branches**, vs. the 4 EAs (9947, 9914,
38008, plus 39001 on a branch not in this task's scope — see §5) named in the task payload. The
task's acceptance criterion 1 ("no tracked `.ex5` delta without receipt remains on the 5 branches")
requires addressing all 8, not only the 4 named ones. `rework-slot-12` is confirmed genuinely clean
— no remediation needed there.

Every flagged commit follows the same shape: one self-contained commit per EA bundling the ad-hoc
`.ex5` binary, the (legitimate) `.mq5` source repair, `SPEC.md`, setfiles, a new test file, and an
evidence doc. Only the `.ex5` binary is the guard violation; everything else in each commit is
sound rework output that must be preserved.

## 3. Why remediation is deferred this cycle

Attempted to inspect/prepare each target worktree before writing anything. All 5 are **live right
now**, each with a **different, currently-uncommitted rework in progress**, unrelated to the EAs
this task would touch:

| worktree | live uncommitted work (different EA, unrelated to this task) |
|---|---|
| `C:/QM/worktrees/rework-slot-1` | QM5_1409 (fully staged: `.ex5`, `.mq5`, `SPEC.md`, setfiles, evidence, test) |
| `C:/QM/worktrees/rework-slot-2` | QM5_11537 (`.mq5`, `SPEC.md`, evidence, test — unstaged/untracked) |
| `C:/QM/worktrees/rework-slot-6` | QM5_37005 (`.mq5`, `SPEC.md`, setfiles, test — unstaged/untracked) |
| `C:/QM/worktrees/rework-slot-11` | QM5_1407 (`.mq5`, test — unstaged) |
| `C:/QM/worktrees/rework-slot-12` | QM5_12931 (`.mq5`, `SPEC.md`, setfile, `compile_work_items.py` + test — unstaged/untracked) |

Two independent blockers, either one sufficient on its own to stop here:

1. **Concurrency risk.** A branch-advancing commit made via git plumbing (no working-directory
   interaction — see §4) would not disturb the other session's working tree or index directly, but
   its **next commit** on that branch would use its current (stale) index as the tree basis for any
   path it doesn't explicitly touch. Since that index still lists the old, ad-hoc `.ex5` blob
   unchanged, the live session's very next commit would **silently re-introduce the exact `.ex5` I
   just removed** — undoing the fix without anyone intending it. This is a mechanical git property,
   not a hypothetical.
2. **Ownership boundary.** `rework-slot-1`, `rework-slot-2`, and `rework-slot-6` are owned by
   Windows identity `WIN-B95G5LPSJ1O/qm-admin`; this session runs as `NT AUTHORITY/SYSTEM`. Direct
   `git` operations there fail closed with "detected dubious ownership" unless
   `safe.directory` is added — which durably changes git config and was explicitly out of scope
   ("NEVER update the git config"). A read-only, single-invocation `git -c safe.directory=... status`
   was used only to confirm the concurrency finding above; no write operation crossed this boundary.

Per the standing instruction to prefer reversible, non-disruptive actions and to treat "someone
else's in-progress work" as something to investigate rather than override, remediation is deferred
rather than forced through.

## 4. Recommended procedure (for the next safe attempt — once all 5 worktrees are idle)

Operate from `C:/QM/repo` (the ownership-clean canonical checkout) via plumbing only — never `cd`
into or `checkout` the target branches, since they share the same object database as `C:/QM/repo`
and their branch refs are directly reachable/writable from there without touching their working
directories:

```bash
# Per flagged (branch, commit, ea_dir, ex5_path):
TMP_INDEX=$(mktemp)
GIT_INDEX_FILE="$TMP_INDEX" git read-tree <branch-tip-commit>
GIT_INDEX_FILE="$TMP_INDEX" git rm --cached "<ex5_path>"
NEW_TREE=$(GIT_INDEX_FILE="$TMP_INDEX" git write-tree)
NEW_COMMIT=$(git commit-tree "$NEW_TREE" -p <branch-tip-commit> \
  -m "fix(<ea_id>): strip ad-hoc EX5 lacking governed COMPILE_EA receipt, keep source repair")
git update-ref "refs/heads/<branch>" "$NEW_COMMIT"
rm -f "$TMP_INDEX"
```

This never touches any worktree's working directory or index — it only advances the branch ref via
a new commit object, so it is safe **once no session has uncommitted local changes on that branch**
(check with the same `git -c safe.directory=<path> -C <path> status --short` read-only probe used
in §3 immediately before running it).

For each stripped commit, additionally (same plumbing pass, added to the tree before `write-tree`):
add a new evidence file `docs/ops/evidence/2026-08-24_rework_<ea_id>_ex5_strip_and_hash_rebind.md`
(append-only — do not edit the original `docs/ops/evidence/2026-08-23_rework-<ea_id>.md`) recording
the canonical `mq5_sha256` = `git show <branch-tip-commit>:<mq5_path> | sha256sum` (already
LF-blob-canonical, per `git show`) so downstream evidence binds to the actually-committed source.

After all branches are stripped: enqueue a governed `COMPILE_EA` successor for each affected EA
(`farmctl.py enqueue-compile <EA_LABEL>`) — **only after the branch is merged into
`agents/board-advisor`**, since `enqueue-compile` compiles whatever `.mq5` is currently checked out
in `C:/QM/repo`, which only reflects the fix once merged. Do not compile ad hoc yourself.

Affected EA labels for the successor queue (post-merge): `QM5_9730_bandy-weekly-rsi-extreme-d1-trigger-mr-index`,
`QM5_9947_bandy-double-bottom-formalised-mr-index`, `QM5_9914_bandy-zlema-distance-trend`,
`QM5_34003_triple-timeframe-williams-r-champion`, `QM5_12944_sperandeo-trend-fault-line-h4`,
`QM5_38008_codetrading-optimized-bollinger-trend-breakout`, `QM5_12939_carney-alternate-bat-h4`,
`QM5_12922_ariel-first-half-month-idx`.

## 5. Scope discrepancy: EA 39001 is not on any of the 5 named branches

The task payload calls out "39001/98d2a81a0 ROT-Wiederholung" (repeat offender) alongside the 4
branches this task names, but `git branch --all --contains 98d2a81a0` resolves to **only**
`rework-slot-4`, which is not in this task's "rework-slot-1/2/6/11/12" scope. `rework-slot-4` is
also currently live (uncommitted QM5_11899 work in progress). The guard docstring says "39001 x2"
(two separate ad-hoc incidents for this EA) — this task only accounts for one, and it isn't on a
branch this task covers. Flagging for the orchestrator/OWNER rather than silently expanding scope
into an unnamed branch: `rework-slot-4` likely needs the same treatment, as a follow-up ticket.

## 6. Not done

- No branch was modified. No commit was created on any `rework-slot-*` branch.
- No merge-ready declaration is made for any branch — acceptance criterion 4 cannot be honestly
  satisfied while criterion 1 (no un-receipted `.ex5` remaining) is unmet.
- No `COMPILE_EA` successor was enqueued (nothing to compile yet — sources aren't merged).

## 7. Artifacts

- This document (the table in §2 is the durable record of the audit).
- Audit reproduction: for each branch, `git log --reverse --format=%H agents/board-advisor..<branch>`
  then, per commit, `git diff-tree --no-commit-id --name-status -r --diff-filter=ACMR <commit>`
  filtered to `framework/EAs/**/*.ex5`, hashing each blob via `git show <commit>:<path>` and checking
  `tools/strategy_farm/validate_ex5_commit_guard.find_receipt()` against the live state DB — this is
  a read-only cross-check, safe to rerun at any time without touching any worktree.
