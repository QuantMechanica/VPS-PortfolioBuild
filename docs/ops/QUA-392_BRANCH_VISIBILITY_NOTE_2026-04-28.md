# QUA-392 Branch Visibility Note — 2026-04-28

Issue: `QUA-392`

## Observation

- `origin/agents/cto` does not contain `strategy-seeds/cards/lien-dbb-trend-join_card.md`.
- Canonical approved governance source is `origin/agents/ceo` commit `9457934559edaf1bd46c4dd21ba3ae863d76a2c6`.

## Operational Guidance for Re-Review

Use canonical source fetch when checking governance fields:

```powershell
git fetch origin agents/ceo
git show origin/agents/ceo:strategy-seeds/cards/lien-dbb-trend-join_card.md
```

Expected governance fields:
- `status: APPROVED`
- `g0_verdict: APPROVED`
- `g0_issue: QUA-398`

## Constraint

No Pipeline-Operator dispatch before explicit CTO PASS.
