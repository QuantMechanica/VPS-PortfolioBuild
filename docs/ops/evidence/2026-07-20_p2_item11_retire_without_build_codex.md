# P2 item 11 — RETIRE-without-build execution (Codex, 2026-07-20)

## Result

`COMPLETE`. The fixed ten-card cohort validated against the handoff, card
frontmatter, and backlog-priority evidence, then moved from `cards_approved` to
`cards_rejected` with byte-identical SHA-256 checks. One unclaimed pending Q02
row was retired in the same guarded operation. No EA, EX5, or terminal path was
touched.

Implementation:

- `tools/strategy_farm/retire_approved_cards.py`
- `tools/strategy_farm/tests/test_retire_approved_cards.py`

Governance/evidence inputs:

- `docs/ops/CODEX_HANDOFF_2026-07-19_audit_fix_bundle.md`, P2 addendum item 11
- `D:/QM/reports/state/build_backlog_priority_v1.csv`
  - SHA-256: `556a522c7f054d4088a4dbb0231da32990d521029578cacf8273eaafd7b1debc`

Durable execution manifest:

- `D:/QM/reports/state/p2_item11_retire_without_build_20260720.json`
- manifest SHA-256:
  `7be57e1e2794b9d7925131ad5364e963c670d4b93ddcf3541d2582998fe8783d`
- status: `COMPLETE`
- selected cards: 10
- open/claimed blockers: 0
- cohort snapshot SHA-256:
  `cd88d1f2eb0d0e992d8f0f6d12d410193e213caeb31a3301bf76937843e7b229`
- ops task: `31bc37a1-560f-419d-8b92-d86f08eac0a2`, REVIEW/PASS

## Validated retirement contract

| Reason | Cards | Machine check |
|---|---|---|
| `R1_FAIL` | QM5_12941, QM5_12942, QM5_1650, QM5_3005 | Exact card frontmatter has `r1_track_record: FAIL` and non-empty reasoning. |
| `TD_COUNTDOWN_OFF_EURUSD` | QM5_1648, QM5_12937, QM5_1622 | Exact backlog row has `HIGH` confidence and the 2026-07-19 off-EURUSD TD-countdown book-decision marker. |
| `BELOW_FIVE_TRADES_PER_YEAR` | QM5_12921, QM5_12702, QM5_12740 | Card and backlog evidence agree on 2/4/4 trades per year and carry the below-floor marker. |

The approved root contains exactly one matching source card for every ID, and
all exact destination filenames are free. The rejected archive already contains
older, differently named cards reusing IDs 1650, 1648, and 12702. The tool
preserves those files and records their paths in the manifest; it refuses an
exact destination collision.

## Farm-state plan

The consistent read-only SQLite snapshot found:

- seven matching `build_ea` tasks, all `RECYCLE`;
- completed Q02 row `88e64027-5889-4ce8-80e1-c04ea3033015` for QM5_12702,
  status `done`, verdict `FAIL`;
- one unclaimed pending Q02 row
  `4690739e-ee2f-432b-80c8-0662913a76f2` for QM5_12740.

The transaction changed that exact pending row to:

- `status=done`
- `verdict=RETIRED_WITHOUT_BUILD`
- `claimed_by=NULL`
- `evidence_path=<live retirement manifest>`
- existing payload preserved with a namespaced `retirement_audit` object appended.

Execute mode requires an assigned Codex `ops_issue` in `IN_PROGRESS` whose
payload contains:

```json
{
  "operation": "retire_approved_cards_p2_item_11",
  "allow_card_move": true,
  "allow_pending_work_retirement": true,
  "card_ids": [
    "QM5_12941", "QM5_12942", "QM5_1650", "QM5_3005",
    "QM5_1648", "QM5_12937", "QM5_1622", "QM5_12921",
    "QM5_12702", "QM5_12740"
  ],
  "approved_root": "D:/QM/strategy_farm/artifacts/cards_approved",
  "rejected_root": "D:/QM/strategy_farm/artifacts/cards_rejected"
}
```

Under `BEGIN IMMEDIATE`, execute mode re-snapshotted the cohort and authorization,
refuses drift plus every active/claimed work item or other open matching task,
stages only the exact unclaimed pending rows, moves and hashes all ten Markdown
cards without overwrite, verifies destinations, then commits. Any pre-commit
failure rolls back both SQLite and completed card moves; the manifest retains
before/planned-after/actual-after rows and per-card recovery paths.

Observed database result: transaction `COMMITTED`; work item
`4690739e-ee2f-432b-80c8-0662913a76f2` is `done` with verdict
`RETIRED_WITHOUT_BUILD`, `claimed_by=NULL`, the durable manifest as its evidence
path, and the prior payload preserved under an appended `retirement_audit`
object. All ten manifest card rows are `MOVED` and their destination hashes equal
their source hashes.

## Verification

```text
python -m pytest tools/strategy_farm/tests/test_retire_approved_cards.py -q
14 passed in 2.00s
```

Coverage includes exact cohort/reason checks, dry-run non-mutation, missing and
ambiguous source refusal, exact destination collision refusal, preservation of
historical same-ID rejected cards, required ops authorization, unclaimed-pending
transaction commit, active/claimed refusal, EA/EX5 sentinel preservation, and
filesystem-plus-database rollback after an injected move failure, plus
write-lock snapshot-drift refusal.
