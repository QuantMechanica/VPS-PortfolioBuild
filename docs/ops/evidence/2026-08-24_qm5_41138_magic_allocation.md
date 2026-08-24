# QM5_41138 governed magic-allocation receipt

Date: 2026-08-24

Scope: non-live build identity for
`QM5_41138_xauxag-mdaily-hl-rv`, with `XAUUSD.DWX` slot 0 / magic
`411380000` and `XAGUSD.DWX` slot 1 / magic `411380001`.

The exact-card allocator dry run selected one eligible approved card, one new
EA directory, one card copy, and exactly two card-declared symbol rows. The
dry-run receipt is
`artifacts/qm5_41138_magic_allocation_dry_run_20260824.json`.

The normal apply path aborted atomically before changing the directory,
registry, or resolver. Strict-default regeneration found three pre-existing
active registry IDs (`1001`, `1015`, and `1016`) whose EA directories are
absent, and correctly refused to remove their already baked resolver rows.
The abort receipt is
`artifacts/qm5_41138_magic_allocation_20260824.json`.

The reviewed allocations for `QM5_41133` through `QM5_41137` establish the
bounded non-dropping fallback for this unchanged legacy condition. Before
mutation, read-only canonical regeneration with `--dry-run --keep-obsolete`
retained 17,989 rows and reported zero drops.

The fallback then:

1. used the already atomically reserved EA identity from commit `71d53a0e6`;
2. created only the exact approved EA directory in commit `22f216799`;
3. added only the two deterministic card-declared rows
   `41138,xauxag-mdaily-hl-rv,0,XAUUSD.DWX,411380000,...,active` and
   `41138,xauxag-mdaily-hl-rv,1,XAGUSD.DWX,411380001,...,active`;
4. ran `framework/scripts/update_magic_resolver.py --keep-obsolete`, retaining
   17,991 rows with zero drops;
5. verified the resolver contains both exact `(ea_id, slot, symbol, magic)`
   mappings and embeds canonical-LF registry SHA-256
   `EDF2077C4563B8F6454EA103257733A7B638D7E30355A9D6522B7AEE38CC35A8`;
6. regenerated a second time and obtained the identical resolver byte SHA-256
   `A7CCFD843B9F52E7F68F71EADD31CB1B28DF878114B92C3E74537B8F59FC869E`.

After allocation the registry file byte SHA-256 is
`2E55EBA65B44E0A80E4CDAB835658A4A1403BC8F4FC0105D49F88722B2EBECD1`.
The post-allocation dedup receipt is
`artifacts/qm5_41138_xauxag_mdaily_hl_rv_postallocation_dedup_20260824.json`.
Its only exact matches are the just-reserved slug and strategy ID in EA ID
`41138`; the pre-allocation receipt remains the non-duplicate authority and
records only the manually resolved `QM5_41135` fuzzy neighbor.

This did not use `--allow-dropped`, create placeholder legacy directories,
retire or change any legacy identity, hand-edit the derived resolver,
allocate another EA, enqueue work, run a tester, or authorize live use.
