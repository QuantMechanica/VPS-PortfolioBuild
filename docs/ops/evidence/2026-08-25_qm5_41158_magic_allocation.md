# QM5_41158 governed magic-allocation receipt

Date: 2026-08-25

Scope: non-live build identity for `QM5_41158_wti-repmedian-tr`, with
`XTIUSD.DWX` slot 0 / magic `411580000`.

## Canonical allocator attempt

The exact-card dry run selected one eligible approved card, the existing
scaffolded EA directory, one build-time card copy, and exactly one card-
declared symbol row. It allocated no second identity because `QM5_41158` had
already been reserved atomically by `farmctl reserve-ea-ids`. The dry-run
receipt is `artifacts/qm5_41158_magic_allocation_dry_run_20260825.json`,
SHA-256
`8EAC4103AD5D3CA036EBF82BC3EBFAF115C150C61F0328611850C5DC80160439`.

The normal apply path then aborted atomically before retaining a card copy,
magic row, or resolver change. Strict-default regeneration found the same
three pre-existing active registry IDs (`1001`, `1015`, and `1016`) whose EA
directories are absent and correctly refused to remove their baked resolver
rows. The abort receipt is
`artifacts/qm5_41158_magic_allocation_20260825.json`, SHA-256
`9FB028B55EED4610872A9857981EB3096C35B30D42A3B68A789A1C908B99E22A`.

## Reviewed non-dropping fallback

The bounded fallback already documented for `QM5_41133` through `QM5_41139`
and `QM5_41157` was applied for this unchanged legacy condition:

1. the EA identity had already been reserved by the atomic allocator in
   commit `5426d995f`;
2. only `framework/EAs/QM5_41158_wti-repmedian-tr` was scaffolded, before any
   magic row, in commit `598a3e322`;
3. the approved card was copied byte-identically to
   `docs/strategy_card.md`;
4. only the deterministic card-declared active row was appended:
   `41158,wti-repmedian-tr,0,XTIUSD.DWX,411580000,...`;
5. `framework/scripts/update_magic_resolver.py --keep-obsolete` retained
   18,002 rows and reported zero drops;
6. the resolver contains the exact `(41158, 0, XTIUSD.DWX, 411580000)` mapping
   and embeds canonical-LF registry SHA-256
   `E5BE42F382213343C8FF2979D5BF47393F290BF6F0A45E1226AEDE06F7570043`;
7. a second identical regeneration produced the same resolver byte SHA-256
   `68FB0945C7285B3C77457D36142335D73A3779FDB8A9FD69401FC2C8A6758FDF`;
   and
8. the approved and build-time card copies both hash to
   `EE70A8E3B61252507B608E1D3865660EA8044CE93867A76C9C726AA08397E499`.

The pre-allocation non-duplicate authority remains
`artifacts/qm5_wti_repmedian_tr_preallocation_dedup_20260825.json`.

This fallback did not use `--allow-dropped`, create placeholder legacy
directories, retire or change any legacy identity, hand-edit the generated
resolver, allocate another EA, enqueue work, run a tester, or authorize live
use.
