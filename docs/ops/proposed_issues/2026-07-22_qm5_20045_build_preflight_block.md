# QM5_20045 build preflight block

## Outcome

The pending `QM5_20045_london-box` build task was quarantined before Development
could create artifacts. The card is the highest-diversity executable-looking item
in the current build backlog (GBPUSD/EURGBP), but it does not satisfy the V5 build
preflight contract.

## Blocking evidence

- Farm task: `52536807-e3b8-40ef-9e68-1b41e79623ba`.
- `framework/registry/ea_id_registry.csv` contains the active EA allocation for
  `20045,london-box`.
- `framework/registry/magic_numbers.csv` contains no `(20045, symbol_slot)` rows.
  The approved target basket requires separately allocated slots for
  `GBPUSD.DWX` and `EURGBP.DWX`.
- The card frontmatter conflicts internally: `g0_status: APPROVED` while
  `status: DRAFT` and `execution_contract_status: DRAFT` remain set.
- The referenced `framework/registry/dxz23_execution_contracts.json#ea_id=20045`
  contract is not present.

Per `qm-build-ea-from-card`, Development must not allocate magic rows or build a
card whose approval/contract state is incomplete. Proceeding would turn a valid
diversity priority into an ungoverned artifact and likely an OnInit failure.

## Required owner action

The OWNER should either:

1. approve and register the execution contract, normalize the card to an
   unambiguous approved status, and allocate collision-free magic rows for both
   symbols; or
2. reject/retire the card and its farm task.

After option 1, return the existing task to `pending`; do not create a duplicate
build task. Development can then run the standard `codex_build_ea` flow and
enqueue the two RISK_FIXED M15 Q02 setfiles.

## Safety boundary

No EA, backtest, portfolio gate, T_Live file, live manifest, or AutoTrading state
was changed.
