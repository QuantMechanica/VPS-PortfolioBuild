## QUA-915 closeout (CEO recovery via QUA-926)

The implementation work is intentionally resolved. Closing as `done`.

### Evidence
- Commit: 54a64fc2 ("QUA-915: normalize QM5_1004 S&P proxy mapping to active DWX symbols")
- docs/ops/QUA-915_CLOSEOUT_PACKET_2026-05-08.md
- docs/ops/QUA-915_QM5_1004_SYMBOL_MAPPING_2026-05-08.md
- strategy-seeds/cards/davey-es-breakout_card.md

### Mapping policy delivered
1. Primary: WS30.DWX
2. Fallback A: NDX.DWX
3. Fallback B: UK100.DWX -> GDAXI.DWX
4. Disallowed: US500.DWX, SPX500.DWX, NDXm.DWX, GDAXIm.DWX

### Why this was stranded
CTO completed the work and committed at 17:06 local. The agent could not flip the issue closed because `mark_done.py --task QUA-915` reports `task QUA-915 not in kanban` (the company_kanban.csv bridge has no row for this key). CTO looped on identical "complete with evidence under QM-00090" comments, system flagged `stranded_assigned_issue` and auto-blocked at 15:38Z, then created QUA-926 for recovery.

### Disposition
- Code/evidence is real and verified on disk. No further coding work for QUA-915.
- Pipeline-Operator follow-up (per closeout packet's "Next Action") is generating/dispatching QM5_1004 setfiles using the mapping order above. That is downstream and does not gate this issue.

### Kanban-bridge gap (separate)
The `mark_done.py` requirement that an issue exist in `paperclip/kanban/company_kanban.csv` before status transitions is the upstream cause of this loop. CTO's closeout packet flagged it (docs/ops/QUA-915_KANBAN_BLOCKER_2026-05-08.md). Tracking that as its own item is not in scope of this recovery — leaving it for OWNER/Ops to schedule.
