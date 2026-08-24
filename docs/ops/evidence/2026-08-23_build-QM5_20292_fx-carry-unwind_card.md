# Build evidence: QM5_20292_fx-carry-unwind_card

- Ticket: `build-QM5_20292_fx-carry-unwind_card`
- Execution date: 2026-08-24
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_20292_fx-carry-unwind_card.md`
- Build SOP: `tools/strategy_farm/prompts/codex_build_ea.md`
- Scope: build only. No compile, backtest enqueue, router task, factory change,
  state-DB write, threshold change, verdict overwrite, or `T_Live` access was
  performed.

## What changed

1. Added the framework EA at
   `framework/EAs/QM5_20292_fx-carry-unwind_card/QM5_20292_fx-carry-unwind_card.mq5`.
   The declared strategy inputs and fixed backtest risk contract are at lines
   20-57. The 21/252 completed-D1 realized-volatility ratio is implemented at
   line 164, the seven-symbol median breadth calculation at line 294, and the
   broker-swap/ATR carry score at line 643. Every dynamic buffer has explicit
   resize/copy-count and `ArraySize` bounds evidence before indexed use.
2. Implemented deterministic carry ranking and symbol tie-breaks (line 704),
   reverse-carry leg preparation with frozen 2.5 ATR stops and risk splitting
   (line 756), and prepare-all-before-open package semantics with rollback on
   a failed leg (line 853).
3. Implemented fail-closed parameter/P3 validation (line 901), the weekly
   entry decision (line 943), orphan/stress/time management (line 969), and
   target-wide entry-only news wiring (line 999). The durable weekly attempt
   marker is loaded/written through terminal globals at lines 131-159 and is
   consumed before signal/history evaluation in `Strategy_AdvanceStateOnNewBar`
   at line 316.
4. Wired the V5 corset through `QM_FrameworkInit` at line 1038, target and
   signal history warm-up at lines 1068-1073, and the MAE hook before all tick
   early returns at line 1092.
5. Added `SPEC.md`, the exact normalized approved-card mirror at
   `docs/strategy_card.md`, and `basket_manifest.json`. The manifest declares
   `AUDCHF.DWX` as the logical D1 host and all six registered target legs.
6. Generated six governed backtest setfiles with scoped invocations of
   `framework/scripts/gen_setfile.ps1 -EaSlug
   QM5_20292_fx-carry-unwind_card -Symbol <target> -TF D1 -Env backtest
   -RiskFixed 1000 -RiskPercent 0 -PortfolioWeight 1`. Each setfile seals the
   approved baseline and its deterministic symbol slot. `build_hash=pending`
   is intentional until the governed compile lane runs.
7. Added `tools/strategy_farm/tests/test_qm5_20292_fx_carry_unwind_build.py`.
   The nine tests cover the card mirror/manifest, registry formula and
   uniqueness, all six setfiles, strategy-input use/P3 bounds, durable weekly
   consumption, stress/carry direction, atomic package behavior,
   orphan/exit behavior, and framework/news ordering (tests begin at lines
   83, 94, 118, 142, 166, 180, 214, 234, and 245).

## Registry and resolver evidence

The required registry allocations already existed and were correct, so they
were not duplicated or rewritten:

- `framework/registry/ea_id_registry.csv:4366` contains the active EA ID and
  canonical slug.
- `framework/registry/magic_numbers.csv:15907-15912` contains slots 0-5 for
  the six target symbols with magics `202920000` through `202920005`, exactly
  `ea_id * 10000 + slot`.
- Read-only CSV audit: `active_rows=16560`,
  `duplicate_active_magics=0`, `duplicate_active_ea_slots=0`, and
  `target_rows=6`.

After the EA directory existed, the resolver was regenerated with:

```text
python framework/scripts/update_magic_resolver.py --keep-obsolete
[OK] wrote framework/include/QM/QM_MagicResolver.mqh — 17994 rows kept, 0 dropped, sha=82BD5671F97FF1FF...
```

The generated resolver was byte-identical to the tracked file. Consequently,
the two registry CSVs and resolver have no content diff in this commit; this
preserves the original 2026-08-12 allocation provenance and avoids duplicate
active rows.

## Validation evidence

```text
python tools/strategy_farm/build_gate_hardening.py --repo-root . --ea-label QM5_20292_fx-carry-unwind_card
files_scanned=1; failures=[]; warnings=[]; symbols_observed=6; matrix_valid=true

python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_20292_fx-carry-unwind_card
verdict=PASS; files_checked=7; findings=[]; max_news_stale_hours=336

python framework/scripts/validate_spec_doc.py framework/EAs/QM5_20292_fx-carry-unwind_card
PASS QM5_20292_fx-carry-unwind_card; Summary: 1 PASS, 0 FAIL

python -m pytest -q tools/strategy_farm/tests/test_qm5_20292_fx_carry_unwind_build.py
......... [100%]
9 passed in 1.29s

python -m pytest -q tools/strategy_farm/tests/test_build_gate_hardening.py tools/strategy_farm/tests/test_build_guardrails.py -k "not canonical_eas" --durations=10
49 passed, 1 deselected in 9.12s
```

Additional governed setfile/magic/resolver tests produced `24 passed, 1
failed in 21.66s`. The failing existing corpus test was
`framework/scripts/tests/test_magic_resolver_binary_search.py::test_binary_lookup_is_equivalent_over_every_generated_row_and_misses`:
strict (non-`--keep-obsolete`) generation drops unrelated IDs 1001, 1015, and
1016 because their EA directories are absent. The ticket-mandated
`--keep-obsolete` regeneration kept all 17,994 rows and dropped zero; the
ticket's own resolver/registry test passes.

The full scoped wrapper was also attempted exactly as:

```text
pwsh -File framework/scripts/build_check.ps1 -EALabel QM5_20292_fx-carry-unwind_card -SkipCompile
```

Its include-mirror preflight refused while MT5 `terminal64` processes were
alive (`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`). The authorized alternatives are
to stop/toggle factory state or enqueue the governed compile lane, both
explicitly forbidden by this ticket. This infrastructure refusal is separate
from the scoped hardening result above, which completed with zero failures.
No compiler was invoked and no `.ex5` was created.

## Risks and rollback

- Compile validity remains intentionally unverified until `COMPILE_EA` owns
  the governed lane; generated setfiles therefore retain `build_hash=pending`.
- The requested build label ends in `_card`, while the approved card's
  canonical strategy slug is `fx-carry-unwind`. `SPEC.md` records both, and
  hardening resolved the approved runtime card by EA ID with zero failures.
- The logical basket must run from its declared `AUDCHF.DWX` host; the other
  five setfiles preserve target saturation/registry evidence and are not
  authorization to interpret individual legs as standalone strategies.

Rollback is a single `git revert <commit-containing-this-evidence>`. That
removes this newly added EA package, its six setfiles, its focused unit test,
and this evidence file. Registry CSVs and the resolver are unchanged and need
no rollback.
