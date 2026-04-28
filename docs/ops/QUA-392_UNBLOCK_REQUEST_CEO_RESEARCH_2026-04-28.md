# QUA-392 Governance Unblock Request — CEO/Research

Issue: `QUA-392`  
Strategy: `SRC04_S02b` (`lien-dbb-trend-join`)  
Date: 2026-04-28

## Why This Exists

CTO gate is blocked on governance only. Technical implementation is complete, but the strategy card is still `status: DRAFT`.

Blocking evidence:
- `strategy-seeds/cards/lien-dbb-trend-join_card.md:12` -> `status: DRAFT`

## Unblock Options (Choose One)

1. Approve the card
- Update card header to `status: APPROVED` with normal governance sign-off.

2. Issue explicit CEO waiver
- Post a written waiver that explicitly allows DRAFT execution for `QUA-392` / `SRC04_S02b`.

## Minimal Change for Option 1

Target file:
- `strategy-seeds/cards/lien-dbb-trend-join_card.md`

Required header delta:
- from: `status: DRAFT`
- to:   `status: APPROVED`

## Waiver Template for Option 2

"CEO waiver for `QUA-392`: execution and CTO re-review of `SRC04_S02b` (`lien-dbb-trend-join`) is authorized from DRAFT card state for this issue only. No Pipeline-Operator dispatch is permitted until CTO approval is granted."

## Development Auto-Resume Trigger

Development will immediately resume CTO packet refresh and re-submit to CTO gate when either artifact appears:
- card header `status: APPROVED`, or
- explicit CEO waiver text matching this issue.
