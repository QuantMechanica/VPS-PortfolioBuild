# DL-089 `_opt` measurement-sibling build recipe

This is the construction contract for a new DL-089 measurement sibling. It
does not authorize a pipeline phase, live use, or retroactive mutation of an
already bound package.

## Setfile-first, unbound sequence

1. Reserve the sibling EA identity and its active magic row for the declared
   host symbol. The registry slot, EA source host mapping, approved card, and
   setfile `qm_magic_slot_offset` must identify the same symbol and slot.
2. Create the sibling source and approved card. Preserve the parent mechanics;
   add exactly the six neutral pattern inputs `opt_pp_buy1..3` and
   `opt_pp_sell1..3`, all defaulting to zero.
3. Generate the sibling's own setfile from scratch with
   `framework/scripts/gen_setfile.ps1` before its first compile. Use
   `RISK_FIXED=1000`, `RISK_PERCENT=0`, and verify `build_hash: pending`. Never
   create a sibling setfile by copying a parent's setfile or an already bound
   sibling setfile.
4. Enroll the sibling through canonical `COMPILE_EA`, then release only its
   exact held row through `release_compile_wave.py`. The governed worker binds
   the fresh setfile to the sibling build and must return a source-hash-matched
   `COMPILE_OK` receipt with zero compiler errors and zero warnings.
5. Only after that receipt exists may the governed DL-089 service evaluate the
   declaration's remaining Q-only prerequisites and materialize cells.

## Already-bound construction defects

Do not delete, overwrite, rename, move, clear, or otherwise disguise an
inherited bound setfile. Preserve its bytes as historical evidence. A rebuild
requires an OWNER-approved task/EA-exact append-only ceremony that:

- generates a new unbound file under a task-specific nested `sets/` directory;
- records the historical path, SHA-256, and embedded build hash before enqueue;
- waives `BOUND_SETFILE_HASH_EXISTS` only for the exact task and EA labels;
- makes the worker bind and validate only the fresh task-specific file; and
- rechecks the historical hashes after compile.

The ordinary enrollment guard and ordinary recursive build-check behavior
remain unchanged for every non-ceremony path.
