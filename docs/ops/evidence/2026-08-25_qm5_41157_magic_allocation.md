# QM5_41157 governed magic-allocation receipt

Date: 2026-08-25

Scope: non-live build identity for `QM5_41157_xauxag-mtheilsen-rv`, with
`XAUUSD.DWX` slot 0 / magic `411570000` and `XAGUSD.DWX` slot 1 / magic
`411570001`.

## Canonical allocator attempt

The exact-card dry run selected one eligible approved card, one new EA
directory, one card copy, and exactly two card-declared symbol rows. It added
no second identity because `QM5_41157` was already reserved atomically by
`farmctl reserve-ea-ids`. The dry-run receipt is
`artifacts/qm5_41157_magic_allocation_dry_run_20260825.json`, SHA-256
`2B0DC71774EC69E7920404240C6C3492400487220051A429EFFF3A770FE98E69`.

The normal apply path then aborted atomically before retaining a directory,
registry row, or resolver change. Strict-default regeneration found the same
three pre-existing active registry IDs (`1001`, `1015`, and `1016`) whose EA
directories are absent and correctly refused to remove their baked resolver
rows. The abort receipt is
`artifacts/qm5_41157_magic_allocation_20260825.json`, SHA-256
`9FB028B55EED4610872A9857981EB3096C35B30D42A3B68A789A1C908B99E22A`.

## Reviewed non-dropping fallback

The bounded fallback already documented for `QM5_41133` through `QM5_41139`
was applied for this unchanged legacy condition:

1. the EA identity had already been reserved in commit `b0c6b616f`;
2. only `framework/EAs/QM5_41157_xauxag-mtheilsen-rv` was scaffolded, before
   any magic row, in commit `e4f4fb9f6`;
3. the approved card was copied byte-identically to
   `docs/strategy_card.md`;
4. only the two deterministic card-declared active rows were appended:
   `41157,xauxag-mtheilsen-rv,0,XAUUSD.DWX,411570000,...` and
   `41157,xauxag-mtheilsen-rv,1,XAGUSD.DWX,411570001,...`;
5. `framework/scripts/update_magic_resolver.py --keep-obsolete` retained
   18,001 rows and reported zero drops;
6. the resolver contains both exact `(ea_id, slot, symbol, magic)` mappings
   and embeds canonical-LF registry SHA-256
   `6A3FAC98154DCBB23367C5658413CD9ABBEECC33BFD713C11E2DC6E596E7F159`;
7. a second identical regeneration produced the same resolver byte SHA-256
   `947E2A0F3333562B2DBC9F8788BB46D2A31035B737E0B50FD6674D3D0100B13D`;
   and
8. the approved and build-time card copies both hash to
   `6D0988C922C6EC3F6DA739DD8438170A5D51E2DDA90B74B968122B040144989C`.

The pre-allocation non-duplicate authority remains
`artifacts/qm5_xauxag_mtheilsen_rv_preallocation_dedup_20260825.json`. The
first attempted post-allocation rescan did not produce an artifact before its
read-only Vault scan timed out; it caused no repository, registry, or runtime
mutation and is not used as evidence.

This fallback did not use `--allow-dropped`, create placeholder legacy
directories, retire or change any legacy identity, hand-edit the generated
resolver, allocate another EA, enqueue work, run a tester, or authorize live
use.
