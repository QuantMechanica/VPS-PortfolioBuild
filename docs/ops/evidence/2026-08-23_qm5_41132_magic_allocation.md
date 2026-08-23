# QM5_41132 governed magic-allocation receipt

Date: 2026-08-23

Scope: non-live build identity for
`QM5_41132_wti-mweekday-med-mom / XTIUSD.DWX / slot 0 / magic 411320000`.

The exact-card allocator dry run selected one eligible card, one registered EA
identity, one new directory, one card copy, and one symbol row. Its receipt is
`artifacts/qm5_41132_magic_allocation_dry_run_20260823.json`.

The normal apply path aborted atomically before changing the directory,
registry, or resolver. Strict-default regeneration found three pre-existing
active registry IDs (`1001`, `1015`, and `1016`) whose EA directories are
absent, and correctly refused to remove their already baked resolver rows. The
abort receipt is
`artifacts/qm5_41132_governed_magic_allocation_20260823.json`.

The immediately preceding reviewed WTI allocations (`QM5_41130` and
`QM5_41131`) established a bounded fallback for this unchanged legacy
condition. A read-only canonical regeneration with documented
`--dry-run --keep-obsolete` retained 17,832 rows, reported zero drops, and
preserved the checked-in registry hash
`2516A77673DF806F182B85E8905DB3005197A13A2D04F41D4975AF5CA74D25FE`.

The fallback then:

1. created only the exact approved EA directory;
2. added only the deterministic card-declared row
   `41132,wti-mweekday-med-mom,0,XTIUSD.DWX,411320000,...,active`;
3. ran `framework/scripts/update_magic_resolver.py --keep-obsolete`, retaining
   17,833 rows with zero drops;
4. verified the resolver embeds the canonical-LF registry SHA-256
   `452A319F699F7FC6FE65C697057C7BFDB6C356A393863FD89F73DE7DF64F1008`;
5. regenerated a second time and obtained the same resolver byte hash
   `BC73570FD9B5AA1964CC358801A969F8B05F625ABD2839B7E92CA2C7E34D85B9`.

The post-allocation dedup receipt is
`artifacts/qm5_41132_wti_mweekday_med_mom_postallocation_dedup_20260823.json`.
Its only exact matches are the just-reserved slug and strategy ID in EA ID
`41132`; no earlier card, wiki node, or different EA identity matches.

This did not use `--allow-dropped`, create placeholder legacy directories,
retire or change any legacy identity, hand-edit the derived resolver, allocate
another EA, enqueue work, run a tester, or authorize live use.
