# QUA-392 CTO Re-Submission Checklist (Governance Fix)

Issue: `QUA-392`

## Must be true before CTO re-review

- [x] `strategy-seeds/cards/lien-dbb-trend-join_card.md` is no longer `status: DRAFT` (`status: APPROVED`).
- [x] Approval source is documented (CEO/Research approval note or explicit CEO waiver).
- [x] CTO packet updated to cite governance evidence path.
- [ ] No-dispatch constraint remains in place until CTO approval.

## Governance Evidence Used

- Card header now contains:
  - `status: APPROVED`
  - `g0_verdict: APPROVED`
  - `g0_reviewer: CEO (interim until Quality-Business hire)`
  - `g0_reviewed_at: 2026-04-28`
  - `g0_issue: QUA-398`
- Upstream approval commit: `9457934` on `agents/ceo`.

## Technical baseline already satisfied

- [x] EA implementation committed (`8871df3`)
- [x] Compile evidence `0 errors, 0 warnings`
- [x] Registry/magic rows for `1008` present
