# QM5_41139 governed magic-allocation receipt

Date: 2026-08-24

Scope: non-live build identity for `QM5_41139_wti-mdaily-hl-mom`, with
`XTIUSD.DWX` slot 0 / magic `411390000`.

The exact-card allocator dry run selected one eligible approved card, one
existing new EA directory, one card copy, and exactly one card-declared symbol
row. The dry-run receipt is
`artifacts/qm5_41139_magic_allocation_dry_run_20260824.json`.

The normal apply path aborted atomically before changing the directory,
registry, or resolver. Strict-default regeneration found three pre-existing
active registry IDs (`1001`, `1015`, and `1016`) whose EA directories are
absent, and correctly refused to remove their already baked resolver rows.
The abort receipt is
`artifacts/qm5_41139_magic_allocation_20260824.json`.

The reviewed allocations for `QM5_41133` through `QM5_41138` establish the
bounded non-dropping fallback for this unchanged legacy condition. Before
mutation, canonical regeneration with `--dry-run --keep-obsolete` retained
17,991 rows and reported zero drops.

The fallback then:

1. used the atomically reserved EA identity from commit `31e93f219`;
2. used the committed exact EA directory from `2ed1459e4`;
3. copied the exact approved card committed at `c90bce304` into
   `docs/strategy_card.md`;
4. added only the deterministic card-declared row
   `41139,wti-mdaily-hl-mom,0,XTIUSD.DWX,411390000,...,active`;
5. ran `framework/scripts/update_magic_resolver.py --keep-obsolete`, retaining
   17,992 rows with zero drops;
6. verified the resolver contains the exact `(ea_id, slot, symbol, magic)`
   mapping and embeds canonical-LF registry SHA-256
   `2F9CED42F5CFD66C24A6C3B887582A35DEC044E39443928EA697B37E08DFE594`;
7. regenerated a second time and obtained the identical resolver byte SHA-256
   `D76AA9E7AF6B1CAB96A9ED34C1368574AD8BF6B0F23B0DC1AADE3FF267921219`.

After allocation the registry file byte SHA-256 is
`E64651B1405A0EDA255299A7D18F2D72D5947115916295F7BB01BED54A54CBB6`.
The approved card and build-time copy share byte SHA-256
`941FA9E4DF396207D19F631F24F63FAD73D76F60A51C9F5967E9C96FF652793B`.

The post-allocation dedup receipt is
`artifacts/qm5_41139_wti_mdaily_hl_mom_postallocation_dedup_20260824.json`.
Its only exact matches are the just-reserved slug and strategy ID in EA ID
`41139`; the pre-allocation receipt remains the non-duplicate authority and
records only the manually resolved `QM5_41133` fuzzy neighbor.

This did not use `--allow-dropped`, create placeholder legacy directories,
retire or change any legacy identity, hand-edit the derived resolver, allocate
another EA, enqueue work, run a tester, or authorize live use.
