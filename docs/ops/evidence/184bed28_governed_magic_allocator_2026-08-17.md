# Governed magic allocator — task 184bed28

Date: 2026-08-17  
Branch: `agents/board-advisor`  
Router task: `184bed28-dcf5-42f7-b6e1-52042ff166dc`  
Verdict: `PASS_FOR_REVIEW`

## Outcome

Implemented `tools/strategy_farm/governed_magic_allocator.py`, a bounded and
idempotent allocator for the Century and fleet worklists. It uses one
non-blocking OS lock for the whole transaction and fails closed if either
`magic_numbers.csv` or `QM_MagicResolver.mqh` is dirty.

The governed sequence is enforced in code:

1. Create the canonical EA directory and copy the approved card to
   `docs/strategy_card.md`.
2. Write one active registry row per card-declared DWX symbol, with
   `magic = ea_id * 10000 + symbol_slot`.
3. Run the canonical resolver generator.
4. Parse the generated parallel arrays, prove strict composite-key order, and
   prove every new row survived. Any failure restores the original registry,
   resolver, and newly created directories.

Real runs default to five EAs. `--max-eas 0` is rejected for mutation and is
permitted only for full-inventory dry runs. Candidates are staged as compiled,
Century, sourced-not-compiled, then card-only. Existing allocations are
skipped; inactive IDs, obsolete paths, missing/malformed symbol declarations,
withheld `QM5_31003`, and prohibited grid/martingale/HFT/ML-labelled candidates
are reported and skipped.

## Symbol-declaration decision

No target universe is inferred. The allocator uses only `target_symbols` or
`target_symbols_from_card`. A missing declaration is skipped for card
amendment; malformed, placeholder, comma-packed, or non-DWX declarations are
also skipped. This resolves the 105-card specification gap without inventing
slots or symbols.

## Full-worklist dry run

Durable output:
`docs/ops/evidence/184bed28_magic_allocator_full_dry_run_2026-08-17.json`

- 371/516 eligible EAs were already allocated.
- 145 eligible EAs (487 rows) remained before the real batch.
- 88 entries were skipped for absent target symbols.
- 21 entries were skipped for malformed/non-DWX target symbols.
- 6 entries were skipped for prohibited technique labels.
- 31 historical retired rows were detected and reported. None intersected the
  selected first batch, so no unrelated registry history was deleted.

## First bounded real batch

Durable output:
`docs/ops/evidence/184bed28_magic_allocator_batch_001_2026-08-17.json`

Allocated 28 rows across exactly five EAs:

- `QM5_11895` — 10 rows
- `QM5_11900` — 10 rows
- `QM5_32007` — 2 rows
- `QM5_32008` — 3 rows
- `QM5_33001` — 3 rows

Registry rows increased from 16,143 to 16,171; generated resolver rows
increased from 16,112 to 16,140. All 28 rows survived regeneration, every
magic formula matched, and resolver composite keys remained strictly ordered.
Progress is now 376/516 eligible EAs.

## Verification

```text
python -m pytest tools/strategy_farm/tests/test_governed_magic_allocator.py \
  framework/scripts/tests/test_magic_resolver_binary_search.py \
  framework/scripts/tests/test_magic_resolver_strict_default.py -q
12 passed

python framework/scripts/update_magic_resolver.py --dry-run
PASS (16,140 rows kept; no drops)

Focused row verification
registry_rows=28 resolver_rows=28 formula=PASS strict_order=PASS

Approved-card SHA256 copy comparison
PASS for all five EAs

git diff --check -- <explicit task paths>
PASS
```

The tests include an explicit assertion that the EA directory and copied card
exist before the registry writer is invoked, plus dirty-registry abort,
idempotent skip, payoff-stage ordering, declaration-skip, and prohibited-label
coverage.

## Operating recommendation

Run this as a dedicated scheduled task, not inside the high-frequency pump.
Use a single scheduler instance with:

```text
python tools/strategy_farm/governed_magic_allocator.py --max-eas 5 --output <timestamped evidence path>
```

The fixed five-EA cap, process lock, dirty-path preflight, and transaction
rollback keep resolver regeneration serial and prevent a large allocation wave
from flooding the downstream build and terminal queues. No scheduler was
installed by this task; wiring remains an OWNER/close-out decision.

No EA was built or enqueued, no pipeline verdict was inferred, no factory or
gate state was changed, and neither T_Live nor AutoTrading was enabled.
