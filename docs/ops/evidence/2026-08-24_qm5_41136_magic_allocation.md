# QM5_41136 governed magic-allocation receipt

Date: 2026-08-24

Scope: non-live build identity for
`QM5_41136_xng-mdaily-iqrmean-mom / XNGUSD.DWX / slot 0 / magic 411360000`.

The exact-card allocator dry run selected one eligible approved card, one new
EA identity, one new directory, one card copy, and one card-declared symbol
row.

The normal apply path aborted atomically before changing the directory,
registry, or resolver. Strict-default regeneration found three pre-existing
active registry IDs (`1001`, `1015`, and `1016`) whose EA directories are
absent, and correctly refused to remove their already baked resolver rows.
The abort receipt is
`artifacts/qm5_41136_magic_allocation_20260824.json`.

The reviewed allocations for `QM5_41133`, `QM5_41134`, and `QM5_41135`
established the bounded non-dropping fallback for this unchanged legacy
condition. Before mutation, a read-only canonical regeneration with
`--dry-run --keep-obsolete` retained 17,987 rows and reported zero drops. The
pre-allocation registry file SHA-256 was
`716F82D1F48A0C5E1680BFD1BDF576291C68D7363B200B929A8A45946514E144`
and the checked-in resolver byte SHA-256 was
`892196EA5F08F675C273AD799760D27985DA483314931EBCBEA45814F59A8119`.

The fallback then:

1. created only the exact approved EA directory and atomically reserved the
   exact EA identity in commit `6af250fbc`;
2. added only the deterministic card-declared row
   `41136,xng-mdaily-iqrmean-mom,0,XNGUSD.DWX,411360000,...,active`;
3. ran `framework/scripts/update_magic_resolver.py --keep-obsolete`,
   retaining 17,988 rows with zero drops;
4. verified the resolver contains exactly
   `(41136, 0, XNGUSD.DWX, 411360000)` and embeds canonical-LF registry
   SHA-256
   `F104BCF8D530B5AF7A2CEF7152AE8157E5530F9B22228B4774387A0D721C684C`;
5. regenerated a second time and obtained the identical resolver byte
   SHA-256
   `336AF5094097AC45F40C9A4B3A1512A09F18DB105D1D1960D357814D56A3895D`.

After allocation the registry file SHA-256 is
`E5072447FE5C7EF31E8F64807285D59FA973FE466E4AA9DFA0CBEF8B756A6911`.
The post-allocation dedup receipt is
`artifacts/qm5_41136_xng_mdaily_iqrmean_mom_postallocation_dedup_20260824.json`.
Its only exact matches are the just-reserved slug and strategy ID in EA ID
`41136`; no earlier registry identity is reported.

This did not use `--allow-dropped`, create placeholder legacy directories,
retire or change any legacy identity, hand-edit the derived resolver,
allocate another EA, enqueue work, run a tester, or authorize live use.
