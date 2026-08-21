# Cards-review G0 adjudication — wave 1

Date: 2026-08-21

Task: `88273f13-3a4d-49da-8ab7-7b0d2d96c27c`

Authority: OWNER drain directive D1, routed by Claude

Selection: the first 25 `ADJUDICATE` rows in
`2026-08-21_ea_id_disposition_963.csv`, preserving decision-list order.

## Result

All 25 cards received a terminal G0 decision through the governed
`farmctl reject-card` command.

| Outcome | Count |
|---|---:|
| Approved | 0 |
| Rejected | 25 |
| Undecided | 0 |

Rejection is the correct outcome for this wave: none of the cards cleared all
four gates without weakening the rubric.

## Rubric distribution

Failures overlap because one card can fail more than one gate.

| Finding | Cards |
|---|---:|
| R1 source/track-record failure | 17 |
| R2 mechanical-closure failure | 20 |
| R3 governed-data failure | 7 |
| R4 ML violation | 0 |
| Duplicate of an approved primitive | 3 |

The three duplicates are the Balke range-breakout, Go Long, and Turnaround
Tuesday drafts. Their corresponding approved cards are QM5_12832, QM5_13036,
and QM5_12788/QM5_12836.

## Per-card decisions

| EA | Decision | Failed checks | Short reason |
|---|---|---|---|
| QM5_10764 | REJECTED | R1 | No traceable source behind `EXTERNAL_SOURCE`. |
| QM5_10765 | REJECTED | R1, R2 | No source; seasonal rule is left in alternative forms. |
| QM5_10766 | REJECTED | R1, R2 | No source; NFP timing is not calendar/DST closed. |
| QM5_10767 | REJECTED | R1, R3 | No source; constituent earnings data is outside governed DWX data. |
| QM5_10768 | REJECTED | R1 | No durable source for the claimed post-FOMC drift. |
| QM5_10864 | REJECTED | R1, R2 | Uncited academic claim; smoothing and portfolio mapping incomplete. |
| QM5_10865 | REJECTED | R1, R3 | Uncited claim; historical swaps and VIX unavailable. |
| QM5_10889 | REJECTED | R2, R3 | Yield proxy unspecified; government-yield data unavailable. |
| QM5_10890 | REJECTED | R1, R2 | Intervention and stabilization concepts are discretionary. |
| QM5_10891 | REJECTED | R1 | No durable source for the pre-FOMC anomaly. |
| QM5_10893 | REJECTED | R1, R2 | MSS and order-block selection are not deterministic. |
| QM5_10894 | REJECTED | R1, R2, R3 | Weights/gate undefined; commodity basket unavailable. |
| QM5_11917 | REJECTED | R1, R2 | Simons analogy is not evidence; lead-lag rules incomplete. |
| QM5_11918 | REJECTED | R1, R2, R3 | Valuation mapping incomplete; yield history unavailable. |
| QM5_11919 | REJECTED | R1, R2, R3 | Consensus/pair rules unavailable and hold window discretionary. |
| QM5_11920 | REJECTED | R1, R2 | Realized-vol rule is mislabeled VRP and portfolio gate is incomplete. |
| QM5_11921 | REJECTED | R2, duplicate | Mixed variants; existing approved Balke range-breakout. |
| QM5_11922 | REJECTED | R2, duplicate | Sizing incomplete; existing approved Balke Go Long. |
| QM5_11923 | REJECTED | R2, duplicate | Sizing incomplete; existing approved Turnaround Tuesday. |
| QM5_11924 | REJECTED | R2 | RSI period remains an unresolved 14-or-20 choice. |
| QM5_11925 | REJECTED | R1, R2 | Source, instrument, order lifecycle, and time exit incomplete. |
| QM5_11926 | REJECTED | R2 | Alternative exits unresolved; sizing absent. |
| QM5_11927 | REJECTED | R2 | Direction and closed-bar entry trigger are absent. |
| QM5_11928 | REJECTED | R2, R3 | Core parameters absent; crypto outside the target matrix. |
| QM5_11929 | REJECTED | R1, R2 | No durable STS citation; structure terms remain discretionary. |

## Verification and CLI compatibility

- 25/25 source cards now have `g0_status: REJECTED`.
- 25/25 have an explicit `g0_rejection_reason` and
  `last_updated: 2026-08-21`.
- The first seven decisions applied immediately. The eighth exposed legacy
  UTF-8-BOM frontmatter that `update_card_frontmatter` could parse for reads
  but not patch for writes.
- Commit `1b0f13648` makes the governed frontmatter updater accept and preserve
  BOM encoding; its focused regression test passes for BOM and non-BOM cards
  (`2 passed`). The remaining 18 decisions then applied through the same CLI.
- `reject-card` intentionally received the `cards_review` paths. Its present
  contract records the decision in place (it only relocates `cards_draft`
  inputs); no card was hand-moved.

Machine-readable receipt:
`C:/QM/repo/artifacts/reviews/88273f13-3a4d-49da-8ab7-7b0d2d96c27c.json`
