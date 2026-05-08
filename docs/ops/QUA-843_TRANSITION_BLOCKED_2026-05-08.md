# QUA-843 Transition Blocker (Run Ownership Conflict)

Date: 2026-05-08
Issue: QUA-843
Attempted action: `apply_issue_transition_payload.py` to close issue

## Result

- Env preflight: PASS (`env_ok=true`)
- Transition apply: FAIL (`HTTP 409 Conflict`)

## Error

Paperclip returned `Issue run ownership conflict` for `QUA-843`.
Current checkout/execution run id on issue: `9b25b2b4-b001-47f1-a53e-fdf948f3616a`.
This heartbeat run id differs, so PATCH close is rejected.

## Unblock Owner + Action

- Owner: Harness / issue-run owner
- Action: re-run `apply_issue_transition_payload.py` from the currently owning run context (or release/re-checkout issue to this run), then apply payload:
  - `docs/ops/QUA-843_ISSUE_TRANSITION_PAYLOAD_2026-05-08.json`

## Evidence

- Closeout packet: `docs/ops/QUA-843_CLOSEOUT_PACKET_2026-05-08.md`
- Ready-to-close packet: `docs/ops/QUA-843_READY_TO_CLOSE_2026-05-08.md`

## Retry Attempt (2026-05-08T11:47Z)

- `apply_issue_transition_payload.py --payload docs/ops/QUA-843_ISSUE_TRANSITION_PAYLOAD_2026-05-08.json` failed again with `HTTP 409`.
- New conflicting owner run id reported by Paperclip: `8558e3d8-638d-4d49-ad72-f46060846b4e`.
- Dry-run confirms target transition remains:
  - issue `QUA-843`
  - target_status `done`
  - closeout comment body + evidence paths are valid.
