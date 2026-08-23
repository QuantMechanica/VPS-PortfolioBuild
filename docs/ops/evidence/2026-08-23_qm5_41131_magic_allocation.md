# QM5_41131 governed magic-allocation receipt

Date: 2026-08-23

Scope: non-live build identity for
`QM5_41131_wti-mdaily-tailtrim-mom / XTIUSD.DWX / slot 0 / magic 411310000`.

The exact-card allocator dry run selected one eligible card, one registered EA
identity, one new directory, one card copy, and one symbol row. Its receipt is
`artifacts/qm5_41131_magic_allocation_dry_run_20260823.json`.

The normal apply path aborted atomically before changing the directory,
registry, or resolver. Strict-default regeneration found three pre-existing
active registry IDs (`1001`, `1015`, and `1016`) whose EA directories are
absent, and correctly refused to remove their already baked resolver rows. The
abort receipt is
`artifacts/qm5_41131_governed_magic_allocation_20260823.json`.

The immediately preceding reviewed WTI allocation (`QM5_41130`) established a
bounded fallback for this unchanged legacy condition. A read-only canonical
regeneration with documented `--dry-run --keep-obsolete` retained 17,831 rows,
reported zero drops, and preserved the checked-in registry hash
`B38C6DF3A93355F2`.

The fallback then:

1. created only the exact approved EA directory;
2. added only the deterministic card-declared row
   `41131,wti-mdaily-tailtrim-mom,0,XTIUSD.DWX,411310000,...,active`;
3. ran `framework/scripts/update_magic_resolver.py --keep-obsolete`, retaining
   17,832 rows with zero drops;
4. verified the resolver embeds the canonical-LF registry SHA-256
   `2516A77673DF806F182B85E8905DB3005197A13A2D04F41D4975AF5CA74D25FE`;
5. regenerated a second time and obtained the same resolver byte hash
   `7489E2D45C62CE28ACB1AABFD1A75CF3B25C6295D1A751FEEA99F958D6E27FC2`.

This did not use `--allow-dropped`, create placeholder legacy directories,
retire or change any legacy identity, hand-edit the derived resolver, allocate
another EA, enqueue work, run a tester, or authorize live use.
