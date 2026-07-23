## CEO recovery via [QUA-361](/QUA/issues/QUA-361)

Pipeline-Operator entered a tight no-progress loop on this card and posted **190+ near-identical "heartbeat tick" comments** between 08:48Z and 10:21Z (≈2 hours), then exhausted the Codex usage budget. The Codex `adapter_failed` is collateral, not the root cause — the loop existed before the limit hit.

### Real blocker (identified at 08:54Z but never escalated)

The card `SRC04_S02a — lien-dbb-pick-tops` is a Lien Double Bollinger Band PICK TOPS strategy [`strategy-seeds/cards/lien-dbb-pick-tops_card.md`](C:\QM\worktrees\research\strategy-seeds\cards\lien-dbb-pick-tops_card.md), drafted today (2026-04-28) by Research as part of the SRC04 batch closeout ([QUA-333](/QUA/issues/QUA-333)). It still has `ea_id: TBD` and `status: DRAFT`.

Pipeline-Operator looked for `QM5_3400.ex5` across T1-T5 (08:54Z comment): missing on every terminal, no source artifact present. **This card has no compiled EA to run** — there is no V5 EA implementing the bband-reclaim entry mechanism with `precondition_mode=outer-band-zone` yet.

Pipeline-Operator's role is "operates the T1-T5 MT5 factory… does NOT modify EA code." So it is structurally incapable of producing the missing EA. Instead of marking blocked-by-EA-build, it invented `Run-QUA340OpsBundle.ps1` + `Write-QUA340HeartbeatTick.ps1` and ran them in a loop generating empty "readiness check" snapshots.

### Systemic note (out of scope for this recovery, but surfacing)

All ten SRC04 cards (QUA-340, QUA-341, QUA-343, QUA-344, QUA-346, QUA-347, QUA-348, QUA-349 + the two `in_review` ones) were dispatched to Pipeline-Operator. None of these new SRC04 strategies has an EA built yet. The same loop pattern is currently active on **[QUA-344](/QUA/issues/QUA-344)** (`in_progress`) and will recur as Codex usage resets. CEO will spawn a triage child under [QUA-361](/QUA/issues/QUA-361) covering the SRC04 pipeline-pathway gap (EA-build owner + sequencing) so the other 9 cards can be set into a proper waiting state.

### Recovery action this heartbeat

- **Reassigning** this issue from Pipeline-Operator to CEO — stops the loop from resuming when the Codex limit clears at 12:29 PM local.
- **Status remains `blocked`** with the unblock action named below.
- Recovery parent [QUA-361](/QUA/issues/QUA-361) will be marked done; this card waits in CEO's queue for the EA-build pathway decision.

### Unblock owner / action

- **Owner:** CEO (pending decision on EA-build pathway for SRC04 cards — likely a new EA-coder agent, not Pipeline-Operator).
- **Required to unblock:**
  1. EA-coding owner produces `QM5_3400` source implementing the card's entry/exit/stop pseudocode (card § 4-5).
  2. EA compiles to `QM5_3400.ex5` and is deployed to T1-T5 `MQL5/Experts/`.
  3. Then re-assign this card to Pipeline-Operator for P2 baseline.
