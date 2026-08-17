# Magic resolver indexed lookup — 2026-08-17

Task: `115c52a0-c811-490d-bde5-02242d1b4b77`

Verdict: `PASS_FOR_REVIEW`

## Outcome

`QM_MagicChecked` now resolves `(ea_id, symbol_slot)` once with a binary search
and uses that same row for both the registration check and the R-069 symbol
binding check. The generated registry remains allocation-free and fail-closed.
At the current 16,111 rows, lookup work falls from as many as two 16,111-row
linear scans to one binary search of at most 14 iterations. Open-position
collision scanning is unchanged.

No EA was mass-rebuilt. The include will enter production binaries through
their next governed scheduled build.

## Implementation

- `framework/scripts/update_magic_resolver.py` sorts rows explicitly by the
  composite key `ea_id * 10000 + symbol_slot`, rejects duplicate or non-strict
  ordering, and emits `QM_MagicRegistryFindIndex`.
- `framework/include/QM/QM_MagicResolver.mqh` binary-searches the existing
  parallel arrays without runtime allocation.
- `QM_MagicRegistered` and `QM_MagicRegisteredSymbol` retain their public
  behavior while using the index.
- `QM_MagicChecked` calls the index exactly once. Missing or magic-mismatched
  rows still return `-1` through `EA_MAGIC_NOT_REGISTERED`; a registered row
  bound to a different expected symbol still returns `-1` through the same
  `EA_MAGIC_RESOLUTION_FAILED` emission. Collision handling and successful
  return values are unchanged.
- `framework/scripts/benchmark_magic_resolver_lookup.py` provides a
  reproducible lookup-only before/after benchmark.

The generated include has 16,111 rows, embeds registry SHA-256
`C94ABB4486F958F4C9FD48D68F7E86738C9848028424A957C8D7125AF11F871C`,
and has file SHA-256
`D270EAEE437268F1BD97DDBB4F43E205D815D25E8B8A5B91296D4CCF0DD48614`.

## Equivalence and ordering verification

Command:

```text
python -m pytest -q framework/scripts/tests/test_magic_resolver_binary_search.py framework/scripts/tests/test_magic_resolver_symbol_fail_closed.py framework/scripts/tests/test_magic_resolver_strict_default.py framework/scripts/tests/test_magic_resolver_hash_newlines.py tools/strategy_farm/tests/test_host_slot_magic_resolution_static.py tools/strategy_farm/tests/test_magic_resolver_reconcile_newlines.py
```

Result: `19 passed in 1.32s`.

The new full-domain test checks the indexed result against the old linear-scan
result for every one of the 16,111 generated rows, including matching-symbol
and deliberate symbol-mismatch outcomes, plus more than 128 deterministic
unregistered pairs. It also verifies that an unsorted CSV is emitted in strict
composite-key order, that unsorted or duplicate renderer input fails, and that
`QM_MagicChecked` contains exactly one indexed lookup.

Running the generator twice produced the identical include SHA-256 above, so
the ordering invariant is deterministic and regeneration is byte-idempotent.

## Measured lookup timing

Command:

```text
python framework/scripts/benchmark_magic_resolver_lookup.py --calls 2000 --repeats 3
```

The deterministic workload used 2,000 calls per repeat, 80% registered and 20%
unregistered, over all 16,111 rows. It compares the old two-scan registry-only
shape with the new single binary lookup; unchanged collision scanning is
intentionally excluded.

| Lookup shape | Median total | Median per call |
|---|---:|---:|
| Linear double scan | 1,545,976,700 ns | 772,988.35 ns |
| Binary single lookup | 8,778,700 ns | 4,389.35 ns |

Measured lookup-only speedup: `176.105x`. All 2,000 outputs were identical.
This figure measures the isolated resolver operation, not whole-EA or whole-run
speedup.

## Strict compile evidence

To avoid rebinding any canonical EA binary or its work items, one representative
EA source (`QM5_1354_woodie-cci-dual-h1`) was copied to an isolated build probe
and compiled with the canonical framework includes using `compile_one.ps1
-Strict`. Only `metaeditor64.exe` was used; no terminal was started.

Result: `PASS`, `0 errors`, `0 warnings`, 6,022 ms compiler elapsed.

- Compile log:
  `D:/QM/build/resolver_compile_probe_115c52a0/build_logs/compile/20260817_034549/QM5_1354_woodie-cci-dual-h1.compile.log`
  (`0EA334BFBF0F53891FBD75A3BF95B554A4D08C220E8DDF62BC170D9E53AD1E2B`)
- Summary:
  `D:/QM/reports/compile/magic_resolver_probe_115c52a0/20260817_034549/summary.csv`
  (`EF659984A013B00CFBD72DA162864D3D70FEB294A789C9F181FC3B4CECD3D9BB`)
- Isolated EX5:
  `D:/QM/build/resolver_compile_probe_115c52a0/QM5_1354_woodie-cci-dual-h1.ex5`
  (`74DC99EF3942C1FE067B84A767EE090EA9E86BE1037D95656D00F8421F402E8B`)

The representative EA's focused build-guardrail scan also passed all nine
files with no findings and the enforced news-staleness maximum of 336 hours.

## Related registry-blocked cohort

The deterministic inventory in
`docs/ops/evidence/stranded_ea_inventory_2026-08-17.json` (SHA-256
`09EB04BD46114C274F7E90692718FB7BF77CDDC7DA6E69B365F9D44B38B4FA77`)
reports 651 approved EA identities in `blocked_on_registry`. This class means an
approved card lacks either its non-retired EA-ID registry identity, one or more
required deterministic magic rows for its target symbols, or the corresponding
generated resolver rows; classes can overlap.

`QM5_36005_nnfx-coral-trendlord-woodies-harvester` is explicitly in that class:
its approved card and active EA-ID row exist, but it has no magic rows or
resolver rows for `AUDNZD.DWX`, `EURJPY.DWX`, or `GBPJPY.DWX`. This resolver
performance fix does not invent those identities or move that EA into the build
lane.
