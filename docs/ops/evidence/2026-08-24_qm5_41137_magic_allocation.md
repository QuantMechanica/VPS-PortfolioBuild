# QM5_41137 governed magic-allocation receipt

Date: 2026-08-24

Scope: non-live build identity for
`QM5_41137_wti-mmedian-shift-mom / XTIUSD.DWX / slot 0 / magic 411370000`.

The exact-card allocator dry run selected one eligible approved card, one new
EA identity, one new directory, one card copy, and one card-declared symbol
row.

The normal apply path aborted atomically before changing the directory,
registry, or resolver. Strict-default regeneration found three pre-existing
active registry IDs (`1001`, `1015`, and `1016`) whose EA directories are
absent, and correctly refused to remove their already baked resolver rows.
The abort receipt is
`artifacts/qm5_41137_governed_allocation_20260824.json`.

The reviewed allocations for `QM5_41133` through `QM5_41136` establish the
bounded non-dropping fallback for this unchanged legacy condition. Before
mutation, read-only canonical regeneration with `--dry-run --keep-obsolete`
retained 17,988 rows and reported zero drops.

The fallback then:

1. created only the exact approved EA directory and atomically reserved the
   exact EA identity in commit `02ed444f7`;
2. added only the deterministic card-declared row
   `41137,wti-mmedian-shift-mom,0,XTIUSD.DWX,411370000,...,active`;
3. ran `framework/scripts/update_magic_resolver.py --keep-obsolete`,
   retaining 17,989 rows with zero drops;
4. verified the resolver contains exactly
   `(41137, 0, XTIUSD.DWX, 411370000)` and embeds canonical-LF registry
   SHA-256
   `6BAC3958F045937ACC06F2A32051EA1352039F4AAFD224022DDA1BFEDDEC9754`;
5. regenerated a second time and obtained the identical resolver byte
   SHA-256
   `E4E636C85F989AEBCF95318C89D3CF9399E7DAC0F5174EA36050C2B3A39D506B`.

After allocation the registry file byte SHA-256 is
`1A30B5DF1986A641CB0F3BB6BE57D643CC003DCB3EC77ACA17C4636CCF930B1E`.
The post-allocation dedup receipt is
`artifacts/qm5_41137_wti_mmedian_shift_mom_postallocation_dedup_20260824.json`.
Its only exact matches are the just-reserved slug and strategy ID in EA ID
`41137`; no earlier registry identity is reported.

This did not use `--allow-dropped`, create placeholder legacy directories,
retire or change any legacy identity, hand-edit the derived resolver,
allocate another EA, enqueue work, run a tester, or authorize live use.
