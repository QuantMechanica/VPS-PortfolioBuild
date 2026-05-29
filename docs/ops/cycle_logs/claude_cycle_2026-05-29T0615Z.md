# Claude Cycle 2026-05-29T0615Z

## Status
- No routable claude task. `run --min-ready-strategy-cards 5 --max-routes 5` → replenish
  frozen (`generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`, ready cards
  0); `route-many --max-routes 5` → `no_routable_task`; `list-tasks --agent claude` → `[]`
  (empty in all states).
- Replenish inventory: 2674 approved / **0 ready** / 49 draft; `open_build_or_review_tasks=59`;
  `active_pipeline_eas=0`; `blocked_approved_cards=2674`.

## Health (overall FAIL, 4 fail / 0 warn / 15 ok)
- `p2_pass_no_p3` FAIL **127** — profitable P2-PASS without P3 promotion (pump §10c,
  Codex/pump-side).
- `p_pass_stagnation` FAIL **0 P3+ PASS / 12h** — consistent with Q04 wall (below); green
  earlier only on Q03 throughput, now red as the 12h Q03 window also dried.
- 2 further FAILs (pump/unbuilt-side); 15 OK incl. `mt5_dispatch_idle` 416 pending / 6 active
  / 9 pwsh workers, `disk_free_gb` D: 52.9 GB, `codex_auth_broken` 0 (auth_age 234.5h).

## Pipeline Q-state (DB snapshot ~0620Z)
- Last ~1h: Q02 4 PASS / 4 FAIL / 12 INFRA_FAIL; Q03 24 PASS / 3 FAIL / 18 INFRA_FAIL;
  **Q04 24 INFRA_FAIL / 0 PASS**.
- Cumulative Q04: **3,926 failed / 3 pending / 0 PASS ever.**
- Queue (live): pending Q02 254 / Q03 152 / Q04 1; active Q02 1 / Q03 5.

## KEY FINDING — Q04 blocker narrowed to a single OWNER lever: daemon restart
Prior cycles (0600Z) concluded "daemons run main code which lacks the Q04 fix → must
push+merge to main." **That assumption is now disproven.** Verified this cycle:
- `C:/QM/repo` — the working tree the `terminal_worker` daemons execute — is checked out on
  `agents/board-advisor`, HEAD `07cea03f`, which **contains all three Q04 fixes**: `26fb4fdb`
  (phase-name P3/Q03), `9c1427eb` (sys.path off-by-one), and the new `a8c1da38`
  (`fix(farmctl): translate P-era args for Qxx phase runners`, committed 06:16Z).
- So origin/main being 20 commits behind is **durability hygiene, not the live-blocker** —
  daemons run the working tree, not origin/main.
- The real, single blocker: the dispatcher (`a8c1da38`) and phase-name (`26fb4fdb`) fixes
  live in `farmctl.py`, which `terminal_worker` imports **once in a persistent daemon loop**.
  Running daemons hold a stale farmctl in memory and won't load the on-disk fix until
  restarted. (The sys.path fix `9c1427eb` is in the *spawned* q04–q10 runner files, read
  fresh per work-item — already live, proven by argparse errors replacing ModuleNotFoundError.)
  The fix commit message states this verbatim.
- **Proof still inert:** newest Q04 INFRA_FAILs `06:18:02Z` (EURJPY) and `06:17:19Z` (USDJPY)
  post-date the `06:16Z` fix commit → daemons have not restarted.

The dispatcher arg-mismatch is the same disease latent in Q05–Q10 (all leave
`--out-prefix`/`--period`); `a8c1da38`'s post-branch translation covers them too, so once the
daemons restart the entire Q04–Q10 stack should clear in one move (Q08 already rebuilds cmd).

## QM5_10260 queue (cycle step 4)
- 230 work_items, 0 pending / 0 active. Q02 25 done + 1 failed; Q03 102 done (PASS);
  Q04 102 INFRA_FAIL. Failing on merits at Q02 + walled at Q04 like every EA. TIMEOUT framing
  remains obsolete (0 TIMEOUTs).

## Router task slate (no claude assignments)
- 6 gemini REVIEW research_strategy (Codex's review per hard rules — untouched, not
  self-approved); 8 unassigned + 1 codex PIPELINE build_ea; 19 unassigned RECYCLE build_ea;
  2 codex RECYCLE + 2 codex PASSED ops_issue; 2 codex PASSED build_ea.

## Actions taken this cycle
- Updated memory `project_qm_q04_infra_fail_scaled_2026-05-28` + MEMORY.md index to record the
  narrowed blocker (daemon restart, not push-to-main) and the proof timestamps. No code or
  pipeline changes; no router state changes.

## Risks / blockers
- Q04 100% INFRA_FAIL / 0 PASS ever — pure MT5 waste continues until daemons restart.
- **OWNER-only lever:** restart `terminal_worker` daemons from the RDP session
  (`feedback_factory_interactive_visible_mode_2026-05-23`); do NOT autonomously restart or
  start terminal64. Push of board-advisor → origin/main remains blocked on PAT (durability,
  separable from the live fix).

## Recommended next step
- **OWNER (TOP, single action):** restart the `terminal_worker` daemons. The fix is already on
  disk in `C:/QM/repo`; a restart reloads `farmctl.py` and should flip Q04 (and latent Q05–Q10)
  off the INFRA_FAIL wall in one move. No push/merge required for liveness.
- OWNER (durability): refresh PAT, push `agents/board-advisor` (HEAD 07cea03f) → origin, merge
  to main, so the fix survives a worktree reset.
- Next-cycle proof-of-live signal: first Q04 row with `updated_at` after the restart showing
  PASS or WAITING_INPUT instead of INFRA_FAIL.
