# Codex Handoff 2026-07-20b — priority_track for new-EA Q02s + stale-worktree holdout

Small, terminal-free follow-ups. Route via the codex lane (no raw `codex exec` while
factory automation runs — Rule 23). agents/codex worktree, explicit commit pathspecs,
evidence per claim.

## H-A — new-EA / force_build Q02s must carry `priority_track=true`

**Problem (found 2026-07-20):** the four FTMO/DXZ-critical fresh EAs — 20004 (TOM,
GDAXI+NDX), 20006 (SP500), 20010 (XAUUSD Friday), 4006 (SessionFlow, EURUSD) — have
their Q02 work-items FIFO-starved behind a May backlog. The dispatch priority
(farmctl.py:4648+ and terminal_worker.py `_priority_pending_query`) ranks
phase → prior-winner → asset-class → FIFO, but a greenfield FX/new-EA Q02 is last on
all axes. The Spur-A agent confirmed: "none of those priority Q02s actually carries
priority_track=true."

**Fix:** when an EA is force_build or freshly built (new ea_id, first Q02), stamp
`priority_track=true` into the Q02 work-item payload_json so the workers' existing
priority-track handling pulls it ahead of the aged organic backlog. The scoring hook
already exists (`strategy_priority.compute_scores()[ea]['priority_track']`,
farmctl.py:10580) and `build-ea`/enqueue already writes `priority_track` for scored
EAs (farmctl.py:10641) — extend it so a force_build / brand-new EA is treated as
priority_track even before it has a strategy_priority score. Keep it additive; do not
reorder existing survivors. Test: enqueue a fresh Q02 for a new id → payload carries
priority_track=true → it out-ranks a same-phase aged FIFO row in the dispatch query.

## H-B — QM5_10026 NDX Q04 PENDING_RUNNER: leave dead (documented decision)

The only real-defect holdout from the 2026-07-20 revival requeue. Its setfile points at
the stale worktree `C:\QM\worktrees\claude-orchestration-2\...`. **Decision (Claude):
do NOT resurrect it.** 10026 is `rw-fx-squeeze-mr` (an FX mean-reversion strategy) that
already FAILs Q02 on its real symbols (EURUSD/GBPUSD FAIL, AUDUSD INFRA); an NDX Q04 for
a failing FX-MR EA is negative-value. No action needed — the row is `status=done` and
consumes nothing. Recorded here so it is not re-flagged as an open holdout each sweep.

## Context

Both are optimizations, not blockers. H-A improves throughput for the 26.07 dual-deploy
candidates; it can land any time. The 26.07 recompile-wave factory-OFF window is the
right slot for the deferred P1.9 resolver regen (12074/12247) — H-A is independent of it.
