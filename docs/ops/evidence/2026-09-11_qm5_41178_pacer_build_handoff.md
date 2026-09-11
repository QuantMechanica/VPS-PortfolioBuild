# QM5_41178 PACER build handoff — 2026-09-11

## Unit selected

- EA: `QM5_41178_xtixng-mwilcoxon-rv`
- Class: monthly XTI/XNG relative-value basket, approximately 4–8 packages/year.
- Approved card: `strategy-seeds/cards/approved/QM5_41178_xtixng-mwilcoxon-rv_card.md`.
- Registry identity: EA ID `41178`; slot 0 `XTIUSD.DWX` / magic `411780000`;
  slot 1 `XNGUSD.DWX` / magic `411780001`.
- Diversity basis: market-neutral-style energy relative value rather than another
  directional FX, equity-index, gold, or natural-gas sleeve.
- Dedup basis: the approved card cites
  `artifacts/qm5_xtixng_mwilcoxon_rv_preallocation_dedup_20260827.json` and records
  manual clean adjudication of its two fuzzy neighbors.

## Source and structural edge

The card cites the U.S. EIA oil/gas relationship study by Villar and Joutz
(2006), the peer-reviewed Energy Journal paper by Ramberg and Parsons (2012),
Mann and Whitney (1947), and pinned R Core `stats::wilcox.test` method files.
The implementation compares fixed older/newer six-month blocks of twelve
synchronized completed XTI/XNG month-end log ratios and fades inclusive
Mann–Whitney tails as one opposite-side, equal-notional package.

## Change made

- Removed locked-configuration comparisons against RNG, news, Friday-close,
  portfolio-weight, and the default stress probability.
- Retained equality locks only for `strategy_*`, `qm_ea_id`,
  `qm_magic_slot_offset`, and the Q02 fixed-risk mode.
- Changed the stress guard to `MathIsValidNumber` plus inclusive `0..1` bounds.
- Resolved the XTI host leg from `_Symbol`; the XNG companion remains the
  declared `strategy_xng_symbol` input.
- Updated `SPEC.md` so it no longer describes framework inputs as locked.

No signal, threshold, direction, sizing formula, or exit mechanic changed.

## Deterministic evidence

- `validate_spec_doc.py`: PASS.
- Reference suite: 8 tests PASS.
- Mandatory source audit:
  `audit_framework_input_pins.py --check-source <mq5>` returned exit 0,
  `ok=true`, `EA_FRAMEWORK_INPUT_PINNED`, `hit_count=0`.
- Scoped `build_check.ps1` did not compile: it correctly returned
  `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because terminal processes were alive
  and directed the build to governed `enqueue-compile`.

## Governed handoff and capacity stop

- `COMPILE_EA` work item: `4a360a7e-bf47-495b-bfe2-f53d81e9e416`.
- The item-specific `COMPILE_EA_WORKER_ROLLOUT_PENDING` activation hold was
  released through `farmctl release-hold`; DB backup SHA-256:
  `3303436f1cf6b4dfc664626c5991853de425649598355633c1e5f2b78ab99910`.
- The released worker claimed T3 and completed at `2026-09-11T09:18:45Z`:
  `COMPILE_OK`, build check PASS, compile PASS, 0 errors, 0 compiler warnings.
- Binary SHA-256:
  `5cf8c0b9d5e80a670b271badbfc2b9c6351300123ce960bc6eb373bc0c58c000`.
- Governed evidence:
  `D:\QM\reports\work_items\4a360a7e-bf47-495b-bfe2-f53d81e9e416\QM5_41178\COMPILE_EA\compile_evidence.json`.
- Build check emitted five non-fatal migration/metadata warnings: two
  grandfathered XNG symbol-literal occurrences and three missing unique-card
  deductions (loss limit, broker-time window, and pending-order contract).
- Post-release CPU samples: `100,100,99,97,99`; average `99.0%`, maximum
  `100.0%`. D: free space: `69.3 GB`.

The PACER CPU ceiling was therefore reached. No tester dispatch, Q02 intake,
portfolio gate, live action, or AutoTrading action was performed. Q02 remains
contingent on a fresh capacity check admitting the single logical basket
canary; compile readiness is already satisfied.
