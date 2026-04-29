# Lesson — Development recursive self-wake hot-poll (2026-04-29)

## Summary

Development agent (`ebefc3a6-...`) entered a recursive self-wake loop: posted a comment → Paperclip's comment-event handler woke Development → Development read its own comment → posted another comment → loop. Sustained ~225-237 successful runs/hour with no commensurate `done` issue throughput. Burned a meaningful share of Codex monthly cap before being detected and paused.

## Pattern

```
Development.run() {
  if no_assigned_work:
    post_noop_heartbeat_comment()  // <- triggers comment-event
}
// comment-event handler:
//   if agent.runtime_config.wakeOnDemand:
//     wake(agent)                   // <- next Development.run()
```

The loop is mechanical and self-sustaining. No human or external trigger needed.

## Detection delay

The pattern was visible in `heartbeat_runs` table from at least 2026-04-28 ~10:39 (issue QUA-372 opened then). It went uncodified until 2026-04-29 ~07:35 when run-rate analysis flagged 474 runs/2h on Development vs 6 for CTO, 9 for CEO, etc. — i.e. ~24 hours between first observation and quantified diagnosis.

## Failed mitigations

| Attempt | Theory | Result |
|---|---|---|
| Lower CTO heartbeat cycle to wake faster | Faster CTO ⇒ faster fix | CTO ran 6× in 2h on QUA-372, fix did not ship |
| `cooldownSec: 60 → 3600` PATCH on Development | Coalesce rapid wakes into 1/hour | **No effect.** Paperclip's wakeOnDemand events ignore `cooldownSec`; only timer heartbeats honor it. Verified by post-PATCH measurement: 338 runs in 90 min after PATCH applied. |
| `maxConcurrentRuns: 5 → 1` | Serialize the recursion | No effect on rate; only prevents parallel runs of the same wake source. |

## Working mitigation

`POST /api/agents/<id>/pause`. Cancels active runs, blocks all subsequent wakes (timer + on-demand). Reversible via `/resume`.

## Proper fix path (still pending at lesson authoring)

Two simple filters in Development's BASIS prompt or executor harness:

1. **Comment de-duplication** — if Development is about to post a comment byte-identical to its previous comment on the same issue, skip the post. Stops the visible "100 identical heartbeats" symptom.
2. **Self-author filter** — when Development wakes via comment-event, check if the comment author was Development itself. If yes, exit immediately without posting.

These break the loop without requiring architectural changes to Paperclip's comment-event wake handler.

## Going-forward rules

- **Detection** — CEO scans `heartbeat_runs` count vs `issues marked done` count per agent on every heartbeat. If `runs_last_hour > 50 AND done_last_hour < 5` for an agent, run `processes/17-agent-runtime-health.md` § Hot-poll branch.
- **Heartbeat config knowledge** — `cooldownSec` does NOT throttle wakeOnDemand. Codified in `processes/process_registry.md` § "Paperclip platform semantics". Don't waste time on cooldown tuning for hot-poll.
- **First-line action is `/pause`, not config patching** — when in doubt, full-pause and investigate. Reversible. Cheaper than letting the loop continue while you experiment with config knobs.
- **Agent BASIS prompt audit** — every agent prompt should include a "post nothing if no work assigned" guard. Add to `paperclip-prompts/development.md` and similar; flag for Doc-KM cross-check on all 13 prompts in `paperclip-prompts/`.

## Cost

- Pre-detection: ~24 hours of unmeasured runs before the rate became visible. Estimate based on 200 runs/hour × 24 = ~4,800 wasted Codex runs. Real cost depends on per-run token average.
- Detection-to-mitigation: 90 min between rate quantification and `/pause`. Another ~340 wasted runs in that window (failed `cooldownSec` PATCH attempt).
- Total wasted Codex runs from this single bug: **~5,000-6,000**, contributing materially to the 2026-04-28 usage-cap exhaustion that throttled the entire company for ~12 hours.

## Cross-references

- `processes/17-agent-runtime-health.md` — runtime pathology process this incident motivated
- `processes/12-board-escalation.md` § Class 6 — escalation contract this incident motivated
- `processes/process_registry.md` § "Paperclip platform semantics" — heartbeat / cooldown knowledge-base entry
- `lessons-learned/2026-04-27_codex_done_before_commit.md` — adjacent agent-behavior pattern (verify-before-promote); same root concern: agent runtime habits drift if not codified
- `lessons-learned/2026-04-26_dwx_spec_patch_blockers.md` — first instance of "ship simple fix first, investigate root cause later" being the right call
