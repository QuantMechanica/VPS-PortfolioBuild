# QM5_41130 governed magic-allocation receipt

Date: 2026-08-23

Scope: non-live build identity for
`QM5_41130_wti-mopen-residence-mom / XTIUSD.DWX / slot 0 / magic 411300000`.

The exact-card allocator dry run selected one eligible card, one registered EA
identity, one new directory, one card copy, and one symbol row. Its receipt is
`artifacts/qm5_41130_magic_allocation_dry_run_20260823.json`.

The normal apply path aborted atomically before changing the directory,
registry, or resolver. Strict-default regeneration found three pre-existing
active registry IDs (`1001`, `1015`, and `1016`) whose EA directories are
absent, and correctly refused to remove their already baked resolver rows. The
abort receipt is `artifacts/qm5_41130_magic_allocation_20260823.json`.

Read-only equivalence proof then ran the canonical regenerator with documented
`--dry-run --keep-obsolete`. It retained 17,830 rows, reported zero drops, and
matched the checked-in resolver byte-for-byte at registry hash prefix
`E329A438F34C4DAE`. Therefore the bounded fallback is:

1. create the exact approved EA directory before allocation;
2. add only the deterministic card-declared row
   `41130,wti-mopen-residence-mom,0,XTIUSD.DWX,411300000,...,active`;
3. run `framework/scripts/update_magic_resolver.py --keep-obsolete` so every
   currently baked legacy-active row is preserved;
4. verify the new row survives, resolver order remains strict, the embedded
   registry hash matches canonical LF bytes, and a second regeneration is
   byte-identical.

This does not use `--allow-dropped`, create placeholder legacy directories,
retire or change any legacy identity, hand-edit the derived resolver, allocate
another EA, enqueue work, run a tester, or authorize live use.
