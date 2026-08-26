# QM5_41160 governed magic-allocation receipt

Date: 2026-08-26

Scope: non-live build identity for `QM5_41160_xauxag-mlad-rv`, with
`XAUUSD.DWX` slot 0 / magic `411600000` and `XAGUSD.DWX` slot 1 / magic
`411600001`.

## Canonical allocator attempt

The exact-card dry run selected one eligible approved card, one new EA
directory, one card copy, and exactly two card-declared symbol rows. It added
no second identity because `QM5_41160` had already been reserved atomically by
`farmctl reserve-ea-ids`. The dry-run receipt is
`artifacts/qm5_41160_magic_allocation_dry_run_20260826.json`, SHA-256
`3B614F77BFFCB6E498C1498ED80C214659579EB4F13C9804E2968C9D28AE2F7F`.

The normal apply path then aborted atomically before retaining a directory,
card copy, registry row, or resolver change. Strict-default regeneration found
the same three pre-existing active registry IDs (`1001`, `1015`, and `1016`)
whose EA directories are absent and correctly refused to remove their baked
resolver rows. The abort receipt is
`artifacts/qm5_41160_magic_allocation_20260826.json`, SHA-256
`9FB028B55EED4610872A9857981EB3096C35B30D42A3B68A789A1C908B99E22A`.

## Reviewed non-dropping fallback

The bounded fallback already documented for `QM5_41133` through `QM5_41139`
and `QM5_41157` through `QM5_41159` was applied for this unchanged legacy
condition:

1. the EA identity had already been reserved by the atomic allocator in
   commit `8f60d667d`;
2. only `framework/EAs/QM5_41160_xauxag-mlad-rv` was scaffolded, before any
   magic row, in commit `fd693a8bc`;
3. the approved card was copied byte-identically to
   `docs/strategy_card.md`;
4. only the two deterministic card-declared active rows were appended:
   `41160,xauxag-mlad-rv,0,XAUUSD.DWX,411600000,...` and
   `41160,xauxag-mlad-rv,1,XAGUSD.DWX,411600001,...`;
5. `framework/scripts/update_magic_resolver.py --keep-obsolete` retained
   18,005 rows and reported zero drops;
6. the resolver contains both exact `(ea_id, slot, symbol, magic)` mappings
   and embeds canonical-LF registry SHA-256
   `BF6B36DD6E27CC3FA241DE3285EB9CC5FF96F0F6451F5A387ED936F69D5C056C`;
7. a second identical regeneration produced the same resolver byte SHA-256
   `37C11946495D2508B3CF62923A719F6550EF348181AF0C1A9F39B04C06DB920C`;
   and
8. the approved and build-time card copies both hash to
   `814C3F24CAB28D7B0ADAAA7A090BA2FF8AC2522E13584C43016A9F1968B2604A`.

The pre-allocation non-duplicate authority remains
`artifacts/qm5_xauxag_mlad_rv_preallocation_dedup_20260826.json`.

This fallback did not use `--allow-dropped`, create placeholder legacy
directories, retire or change any legacy identity, hand-edit the generated
resolver, allocate another EA, enqueue work, run a tester, or authorize live
use.
