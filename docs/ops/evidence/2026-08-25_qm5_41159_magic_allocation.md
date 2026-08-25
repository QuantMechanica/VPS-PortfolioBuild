# QM5_41159 governed magic-allocation receipt

Date: 2026-08-25

Scope: non-live build identity for `QM5_41159_wti-lad-tr`, with
`XTIUSD.DWX` slot 0 / magic `411590000`.

## Canonical allocator attempt

The exact-card dry run selected one eligible approved card, the existing
scaffolded EA directory, one build-time card copy, and exactly one card-
declared symbol row. It allocated no second identity because `QM5_41159` had
already been reserved atomically by `farmctl reserve-ea-ids`. The dry-run
receipt is `artifacts/qm5_41159_magic_allocation_dry_run_20260825.json`,
SHA-256
`4B98E2B7E1328E032A12EA5F7516B7E8AEE091B90D98A6E91AC86326AB113F5A`.

The normal apply path then aborted atomically before retaining a card copy,
magic row, or resolver change. Strict-default regeneration found the same
three pre-existing active registry IDs (`1001`, `1015`, and `1016`) whose EA
directories are absent and correctly refused to remove their baked resolver
rows. The abort receipt is
`artifacts/qm5_41159_magic_allocation_20260825.json`, SHA-256
`9FB028B55EED4610872A9857981EB3096C35B30D42A3B68A789A1C908B99E22A`.

## Reviewed non-dropping fallback

The bounded fallback already documented for `QM5_41133` through `QM5_41139`,
`QM5_41157`, and `QM5_41158` was applied for this unchanged legacy condition:

1. the EA identity had already been reserved by the atomic allocator in
   commit `4bbf7dda3`;
2. only `framework/EAs/QM5_41159_wti-lad-tr` was scaffolded, before any magic
   row, in commit `9220888e8`;
3. the approved card was copied byte-identically to
   `docs/strategy_card.md`;
4. only the deterministic card-declared active row was appended:
   `41159,wti-lad-tr,0,XTIUSD.DWX,411590000,...`;
5. `framework/scripts/update_magic_resolver.py --keep-obsolete` retained
   18,003 rows and reported zero drops;
6. the resolver contains the exact `(41159, 0, XTIUSD.DWX, 411590000)` mapping
   and embeds canonical-LF registry SHA-256
   `C738C98963FECE4DC60152DE933F0F19AB1D421AD3F54ED47ABE74822058C5EB`;
7. a second identical regeneration produced the same resolver byte SHA-256
   `277BFA4BD8C56F920502C5BF5096A19094592C496CFF58A12F3025CAB0141902`;
   and
8. the approved and build-time card copies both hash to
   `F396276C9CA565681703F8681EF04F48069716CEC05F20A5ADA91EE3F122B3B3`.

The pre-allocation non-duplicate authority remains
`artifacts/qm5_wti_lad_tr_preallocation_dedup_20260825.json`.

This fallback did not use `--allow-dropped`, create placeholder legacy
directories, retire or change any legacy identity, hand-edit the generated
resolver, allocate another EA, enqueue work, run a tester, or authorize live
use.
