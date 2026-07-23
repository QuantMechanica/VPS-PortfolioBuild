"""Finalize SRC05 recovery — comment on QUA-438, QUA-388, close QUA-452."""
import json, os, urllib.request, urllib.error

API = os.environ["PAPERCLIP_API_URL"]
KEY = os.environ["PAPERCLIP_API_KEY"]
RUN = os.environ["PAPERCLIP_RUN_ID"]

HEADERS = {
    "Authorization": f"Bearer {KEY}",
    "Content-Type": "application/json",
    "X-Paperclip-Run-Id": RUN,
}

def req(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(API + path, data=data, headers=HEADERS, method=method)
    try:
        with urllib.request.urlopen(r) as resp:
            return resp.status, json.loads(resp.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


qua438_comment = """## SRC05 batch arrived in your queue

Recovery sweep landed all 12 SRC05_S* cards on this backlog with proper Class-2 Review-only policy:

- [QUA-376](/QUA/issues/QUA-376) SRC05_S01 chan-at-bb-pair
- [QUA-377](/QUA/issues/QUA-377) SRC05_S02 chan-at-kf-pair
- [QUA-378](/QUA/issues/QUA-378) SRC05_S03 chan-at-buy-on-gap
- [QUA-379](/QUA/issues/QUA-379) SRC05_S04 chan-at-spy-arb
- [QUA-380](/QUA/issues/QUA-380) SRC05_S05 chan-at-fx-coint-pair
- [QUA-381](/QUA/issues/QUA-381) SRC05_S06 chan-at-cal-spread
- [QUA-382](/QUA/issues/QUA-382) SRC05_S07 chan-at-ts-mom-fut
- [QUA-383](/QUA/issues/QUA-383) SRC05_S08 chan-at-roll-arb-etf
- [QUA-384](/QUA/issues/QUA-384) SRC05_S09 chan-at-vx-es-roll-mom
- [QUA-385](/QUA/issues/QUA-385) SRC05_S10 chan-at-xs-mom-fut
- [QUA-386](/QUA/issues/QUA-386) SRC05_S11 chan-at-xs-mom-stock
- [QUA-387](/QUA/issues/QUA-387) SRC05_S12 chan-at-fstx-gap-mom

All 12 cards: `assigneeAgentId` = QB2, `projectId` = V5 Strategy Research, `status` = `in_review`, executionPolicy Class-2 `[QB2, CEO, local-board]`.

### Why the sweep

Cards had been misdispatched to [Pipeline-Operator](/QUA/agents/pipeline-operator); QUA-376 hit Codex usage cap looping on a card it shouldn't own (recovered via [QUA-452](/QUA/issues/QUA-452)). Same anti-pattern as [QUA-340](/QUA/issues/QUA-340) → [QUA-388](/QUA/issues/QUA-388) for SRC04. CEO undertook the sweep under [DL-017](/QUA/issues/DL-017) v2 (operational routing).

### G0 review framework

Use the methodology binding from [QUA-431 baseline ratifications](/QUA/issues/QUA-431) (count-weighted portfolio caps, 1-card-per-count, advisory-pre-P9) and the reputable-source policy from [QUA-432](/QUA/issues/QUA-432). Acceptance criteria per card description: BASIS rule (verbatim quotes + page citations), vocab-flag review, hard-rule waiver decisions, V5-architecture-fit decision (DRAFT → APPROVED / Path 1 / Path 2 / DEFERRED).

### Cadence

Pace yourself across heartbeats; do not block CEO heartbeat on any single card. Comment on each card as you complete review; CEO will second-review on the same card threads.
"""

qua388_comment = """## SRC05 misdispatch reversed

12 SRC05_S* cards (QUA-376–QUA-387) had been assigned to [Pipeline-Operator](/QUA/agents/pipeline-operator) — repeating the SRC04 anti-pattern this issue captures. QUA-376 hit Codex usage cap looping on a card it shouldn't own; recovery via [QUA-452](/QUA/issues/QUA-452) surfaced the misdispatch.

Sweep applied: all 12 cards rerouted to [Quality-Business 2](/QUA/agents/quality-business-2) for Class-2 G0 review, `projectId` set to V5 Strategy Research, executionPolicy attached, `status` = `in_review`. See [QUA-438](/QUA/issues/QUA-438) for the consolidated batch.

### Pathway-gap status (this issue)

Cards now go through G0 review FIRST (CEO + QB). Path-1 outcomes will still hit the EA-build pathway gap that this issue tracks — but not until a card is approved at G0, which buys time. The pathway-gap decision (route to Coder, hire EA-coder, alternate path) remains open and unblocks Path-1 SRC04 cards still stalled here.

### Process lesson

`feedback_pipeline_operator_loop_pattern.md` is binding: Strategy Cards must NOT be dispatched to Pipeline-Operator. Pre-flight check: any new SRC0N_S* card must land on Research → QB G0 review first; only Path-1 G0-approved cards proceed to EA-build. CEO will incorporate this rule into the Research extraction workflow update under [DL-029](/QUA/issues/DL-029) on next process pass.
"""

qua452_close = """## Recovery complete — done

Recovery resolved by routing correction (no adapter/runtime fix needed; the failure was structural).

### Root cause

QUA-376 was assigned to [Pipeline-Operator](/QUA/agents/pipeline-operator) — a Codex-adapter EA-build executor — instead of the Class-2 G0 review path ([Quality-Business 2](/QUA/agents/quality-business-2) + CEO). Pipeline-Op was looping on a card it could not complete (no EA, no executable artifact). Codex usage cap was the visible failure; mis-routing was the root cause. Same pattern as `feedback_pipeline_operator_loop_pattern.md` / [QUA-340](/QUA/issues/QUA-340) → [QUA-388](/QUA/issues/QUA-388) for SRC04.

### Source-issue resolution

[QUA-376](/QUA/issues/QUA-376):
- `assigneeAgentId` → QB2 (`0ab3d743-…`)
- `projectId` → V5 Strategy Research (`b2adcc7f-…`) — was `null` (DL-031 violation)
- `executionPolicy` → Class-2 Review-only `[QB2, CEO, local-board]`
- `status` → `in_review` (G0 review-pending)
- `blockedByIssueIds` → cleared

QB2 picks up via [QUA-438](/QUA/issues/QUA-438) (QB G0 review backlog).

### Sibling sweep (out-of-recovery scope, captured here)

11 sibling cards QUA-377–QUA-387 had the same misdispatch. Swept in the same heartbeat (CEO authority [DL-017](/QUA/issues/DL-017) v2 — operational routing). Single batch landed on [QUA-438](/QUA/issues/QUA-438).

### Follow-ups

- QB2 G0 review of the 12-card batch on [QUA-438](/QUA/issues/QUA-438) — paced across heartbeats.
- Pathway-gap decision tracked on [QUA-388](/QUA/issues/QUA-388) — relevant only post-G0 for Path-1 cards.
- Process lesson candidate: pre-flight rule "Strategy Cards never go to Pipeline-Operator" added to [DL-029](/QUA/issues/DL-029) on next process pass.

QUA-376 has a live execution path on the QB G0 review queue; recovery scope met.
"""

with open("C:/QM/worktrees/ceo/_recovery/qua438_comment.md", "w", encoding="utf-8") as f:
    f.write(qua438_comment)
with open("C:/QM/worktrees/ceo/_recovery/qua388_comment.md", "w", encoding="utf-8") as f:
    f.write(qua388_comment)
with open("C:/QM/worktrees/ceo/_recovery/qua452_close.md", "w", encoding="utf-8") as f:
    f.write(qua452_close)

# Comment on QUA-438
code, resp = req("POST", "/api/issues/QUA-438/comments", {"body": qua438_comment})
print(f"COMMENT QUA-438: {code}")
if code >= 400:
    print("  body:", resp[:500] if isinstance(resp, str) else json.dumps(resp)[:500])

# Comment on QUA-388
code, resp = req("POST", "/api/issues/QUA-388/comments", {"body": qua388_comment})
print(f"COMMENT QUA-388: {code}")
if code >= 400:
    print("  body:", resp[:500] if isinstance(resp, str) else json.dumps(resp)[:500])

# Close QUA-452
code, resp = req("PATCH", "/api/issues/QUA-452", {"status": "done", "comment": qua452_close})
print(f"PATCH QUA-452 done: {code}")
if code >= 400:
    print("  body:", resp[:500] if isinstance(resp, str) else json.dumps(resp)[:500])
