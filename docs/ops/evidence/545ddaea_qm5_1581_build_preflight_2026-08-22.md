# QM5_1581 build preflight — deterministic session-contract stop

- Router task: `545ddaea-94fe-494c-a675-79db08806fa4`
- Task type / priority: `build_ea` / `50`
- Canonical checkout: `C:/QM/repo`
- Branch / inspected HEAD: `agents/board-advisor` / `6840f4ce9de75b015b58bcfcc0f5d2de48f0c447`
- Verdict: `REVIEW — BUILD_NOT_STARTED_SESSION_CONTRACT_UNDEFINED`

## Governed preflight

| Gate | Evidence | Result |
|---|---|---|
| Approved Strategy Card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1581_aa-rod-lh-mom.md` declares matching ID/slug and `g0_status: APPROVED` | PASS |
| Exact active EA registry identity | `1581,aa-rod-lh-mom,...,active` | PASS |
| Magic registry | 13 active rows exist, including the intended `SP500.DWX`, `NDX.DWX`, and `WS30.DWX` hosts | PASS |
| Mechanical session clock | The card says “Define the equity-index session in broker time before P1” but supplies no open, second-to-last-window, final-window, or close timestamps | FAIL |
| Card build condition | The card says build should proceed only when a deterministic cash-session mapping exists | FAIL |
| Session registry | `session_offset_minutes.csv` has measured `+60` bar offsets for the three symbols, but no cash-session open/close mapping | INSUFFICIENT |

The frontmatter labels R3 `PASS`, while the card body labels R3 `UNKNOWN` and
explicitly makes deterministic session mapping a build prerequisite. The
strategy cannot calculate its prior close, enter at the final half-hour start,
or exit at cash-session close without choosing unapproved broker-time values.
The measured archive-bar offset is not a market-session schedule and cannot be
used to invent those times.

No source, registry, resolver, setfile, or binary was changed, and no compile
or pipeline phase was run. An OWNER-approved session mapping (including
early-close/holiday handling) or explicit card correction is required before
implementation.

## Focused verification

```text
card Entry: "Define the equity-index session in broker time before P1."
card R3: "Build should proceed only if ... a deterministic cash-session mapping."

framework/registry/session_offset_minutes.csv
=> NDX.DWX, SP500.DWX, WS30.DWX each have measured offset_minutes=60
=> no session-open, final-half-hour, or cash-close fields/registry exist
```
