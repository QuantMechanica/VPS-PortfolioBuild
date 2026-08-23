# QM5_41133 governed magic-allocation receipt

Date: 2026-08-23

Scope: non-live build identity for
`QM5_41133_wti-mdaily-median-mom / XTIUSD.DWX / slot 0 / magic 411330000`.

The exact-card allocator dry run selected one eligible card, one registered EA
identity, one new directory, one card copy, and one symbol row. Its receipt is
`artifacts/qm5_41133_magic_allocation_dry_run_20260823.json`.

The normal apply path aborted atomically before changing the directory,
registry, or resolver. Strict-default regeneration found three pre-existing
active registry IDs (`1001`, `1015`, and `1016`) whose EA directories are
absent, and correctly refused to remove their already baked resolver rows. The
abort receipt is
`artifacts/qm5_41133_governed_magic_allocation_20260823.json`.

The immediately preceding reviewed WTI allocations (`QM5_41130` through
`QM5_41132`) established a bounded fallback for this unchanged legacy
condition. A read-only canonical regeneration with documented
`--dry-run --keep-obsolete` retained 17,833 rows, reported zero drops, and
preserved the checked-in registry hash
`452A319F699F7FC6FE65C697057C7BFDB6C356A393863FD89F73DE7DF64F1008`.

The fallback then:

1. created only the exact approved EA directory;
2. added only the deterministic card-declared row
   `41133,wti-mdaily-median-mom,0,XTIUSD.DWX,411330000,...,active`;
3. ran `framework/scripts/update_magic_resolver.py --keep-obsolete`, retaining
   17,834 rows with zero drops;
4. verified the resolver embeds the canonical-LF registry SHA-256
   `7DD5F0CD5B9174397D411C0C38998E26D6F63FB1154C30F3B28A261B8526A21E`;
5. regenerated a second time and obtained the same resolver byte hash
   `C5B1159DDAACCD6C7460552ADC5D834B8652B5F66AD28453A1FD6DB79C5403E5`.

The post-allocation dedup receipt is
`artifacts/qm5_41133_wti_mdaily_median_mom_postallocation_dedup_20260823.json`.
Its only exact matches are the just-reserved slug and strategy ID in EA ID
`41133`; no earlier card, wiki node, or different EA identity matches.

This did not use `--allow-dropped`, create placeholder legacy directories,
retire or change any legacy identity, hand-edit the derived resolver, allocate
another EA, enqueue work, run a tester, or authorize live use.
