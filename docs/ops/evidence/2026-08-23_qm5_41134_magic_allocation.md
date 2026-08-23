# QM5_41134 governed magic-allocation receipt

Date: 2026-08-23

Scope: non-live build identity for
`QM5_41134_wti-mdaily-iqrmean-mom / XTIUSD.DWX / slot 0 / magic 411340000`.

The exact-card allocator dry run selected one eligible approved card, one new
EA identity, one new directory, one card copy, and one card-declared symbol
row. Its receipt is
`artifacts/qm5_41134_magic_allocation_dry_run_20260823.json`.

The normal apply path aborted atomically before changing the directory,
registry, or resolver. Strict-default regeneration found three pre-existing
active registry IDs (`1001`, `1015`, and `1016`) whose EA directories are
absent, and correctly refused to remove their already baked resolver rows.
The abort receipt is
`artifacts/qm5_41134_governed_magic_allocation_20260823.json`.

The immediately preceding reviewed WTI allocation for `QM5_41133` established
the bounded fallback for this unchanged legacy condition. A read-only
canonical regeneration with documented `--dry-run --keep-obsolete` retained
17,834 rows, reported zero drops, preserved registry SHA-256
`7DD5F0CD5B9174397D411C0C38998E26D6F63FB1154C30F3B28A261B8526A21E`,
and preserved resolver byte SHA-256
`C5B1159DDAACCD6C7460552ADC5D834B8652B5F66AD28453A1FD6DB79C5403E5`.

The fallback then:

1. created only the exact approved EA directory and reserved the exact EA
   identity in commit `77cd62bbc`;
2. added only the deterministic card-declared row
   `41134,wti-mdaily-iqrmean-mom,0,XTIUSD.DWX,411340000,...,active`;
3. ran `framework/scripts/update_magic_resolver.py --keep-obsolete`, retaining
   17,835 rows with zero drops;
4. verified the resolver embeds the canonical-LF registry SHA-256
   `3F709B0FD5C238D964CC58651CB133F5DB81240FD70288DDEC549CE373B41599`;
5. regenerated a second time and obtained the same resolver byte hash
   `3F2F4A8674A9C592F4DC60956268A7EF531C1E0003EE109B28C1AFED0C8C2A36`.

The post-allocation dedup receipt is
`artifacts/qm5_41134_wti_mdaily_iqrmean_mom_postallocation_dedup_20260823.json`.
Its only exact matches are the just-reserved slug and strategy ID in EA ID
`41134`; no earlier registry identity, card, or wiki node is reported.

This did not use `--allow-dropped`, create placeholder legacy directories,
retire or change any legacy identity, hand-edit the derived resolver,
allocate another EA, enqueue work, run a tester, or authorize live use.
