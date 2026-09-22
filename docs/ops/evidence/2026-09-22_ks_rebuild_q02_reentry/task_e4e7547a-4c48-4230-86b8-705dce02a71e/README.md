# KS rebuild Q02 re-entry step 3 — task e4e7547a

## Disposition

REVIEW. QM5_10403 completed the governed dry-run → append-only apply → Q02
wait → identity-proof sequence and is `EQUIVALENT_EXACT`. QM5_10706 remains
`BLOCKED`: the canonical fresh-seed command mistakes its completed base-control
row for the distinct D2g6-selected ablation-02 preset because that command's
terminal dedupe compares EX5 only. The narrow EX5 + MQ5 + setfile correction
and regression tests are included in this review, but were not executed against
the live database from an unintegrated worktree.

| Sleeve | Status | Evidence |
|---|---|---|
| QM5_13213 | EXACT | Existing proof `df7ac85c…` |
| QM5_10706 | BLOCKED | Selected seed refused against base-control row `972a6d85…`; own Q03-Q10 chain not started |
| QM5_10700 | EXACT | Existing proof `3735a37d…` |
| QM5_11422 | EXACT | Existing proof `9689e367…` |
| QM5_10403 | EXACT | Q02 `5c12f7bb…`; new proof `25d0ba87…` |
| QM5_41219 | EXACT | Existing proof `739d4f12…` |

The refreshed package under [deploy_package_review_only](deploy_package_review_only/)
is review-only and explicitly not install-authorized.

## QM5_10403 — completed exact sequence

The canonical `requalify-q02 --dry-run` authenticated predecessor
`d02bec84-87fe-43a9-94d4-2795ec46cea7`, compile row
`98873ebc-8231-4eb5-850a-e7f00d9b3598`, the 12 exact parameter changes, and
supplemental authority SHA-256 `e706ef44…`. Apply appended successor
`5c12f7bb-a49f-4249-ba4e-3fa4d631d4fc`; the predecessor was preserved.

T8 completed the successor `PASS` with EX5 `88ba0eab…`, MQ5 `65d4c206…`,
setfile `61c7fe83…`, and evidence SHA-256 `ff8479b4…`. The copied append-only
receipt is under [q02_receipts](q02_receipts/).

The generated proof compares 235/235 deal rows with zero checked-field
mismatches, exact volume, and exact net PnL. Independent `verify` returned
`ok=true`, no failures, and no warnings. Proof SHA-256:
`25d0ba875f0c3423033945fdbe06fbdaaabc947e93b833b1b223bfae36c5370a`.

## QM5_10706 — selected-preset seed blocker

The selected source remains the historical Q02 PASS
`7cf004b7-f4cf-42cb-80cc-d5c98f119ce4`. Its current canonical ablation-02 set
is fixed-risk (`RISK_FIXED=1000`, `RISK_PERCENT=0`), raw SHA-256 `8d0c40a3…`,
and still computes the D2g6 strategy identity `8182d0ff…`. The rebuilt binary
is `c9bf8e83…` and source is `c932fdd8…`.

Canonical `seed-fresh-q02` returned
`q02_pair_already_has_current_binary_terminal_result`, naming base-control row
`972a6d85-d5d0-4a5b-92d6-2a138adbc08d`. That row binds setfile `f87d38b3…`,
not the selected set. The fresh-seed query compared only EX5, while the
established stale-row path already compares EX5 + MQ5 + setfile. The patch
aligns the fresh path with that complete execution identity and retains an
exact-identity refusal. The focused test file passes 52/52 tests.

No Q02 row was appended for the selected preset, so no Q03-Q10 row was
enqueued and `OWN_CHAIN_PENDING` would be premature. The one-page timing and
live-consequence analysis is [QM5_10706_BE_STOP_TIMING.md](QM5_10706_BE_STOP_TIMING.md).

## Required review continuation

1. Review and integrate the fresh-seed identity-tuple fix into `C:/QM/repo` by
   the authorized integration lane.
2. Re-run canonical `seed-fresh-q02` for selected predecessor `7cf004b7…`,
   expected EX5 `c9bf8e83…`, and confirm the new row binds setfile `8d0c40a3…`.
3. Allow that selected identity to run its own append-only Q03-Q10 chain. Mark
   it `OWN_CHAIN_PENDING` only after the seed exists; use `EXACT` only if its
   own terminal gate evidence supports that status.
4. Regenerate or re-seal the review package after the chain. Do not install,
   launch a terminal, toggle AutoTrading, or write T_Live during this review.

Machine-readable bindings are in [operations.json](operations.json) and
[verification.json](verification.json). Nothing here supplies a pipeline
verdict, live authorization, or an identity-proof contract change.
