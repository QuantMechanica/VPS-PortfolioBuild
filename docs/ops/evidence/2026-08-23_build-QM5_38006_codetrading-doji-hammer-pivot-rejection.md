# Build evidence — QM5_38006 codetrading doji/hammer pivot rejection

**Ticket:** `build-QM5_38006_codetrading-doji-hammer-pivot-rejection`

**Execution date:** 2026-08-24

**Result:** Build source, approved-card mirror, specification, governed backtest setfiles, registry attribution, regenerated resolver, and regression tests are complete. Compilation and backtest enqueue were intentionally not performed.

## Preconditions and scope

- The durable approved card is `D:/QM/strategy_farm/artifacts/cards_approved/QM5_38006_codetrading-doji-hammer-pivot-rejection.md`; its approval is mirrored at `framework/EAs/QM5_38006_codetrading-doji-hammer-pivot-rejection/docs/strategy_card.md:10` and its targets at `:33`.
- The worktree already contained a tracked EA source, specification, and three setfiles when this ticket began. This change completes and hardens that existing implementation rather than creating a second EA.
- `framework/registry/ea_id_registry.csv:4477` already contained active EA ID `38006`, so no synthetic or duplicate row was added.
- No state-database write or read was needed. No compile, backtest enqueue/delete, router task, verdict mutation, factory toggle, gate change, or `T_Live` access was performed.

## Changes and traceability

- `framework/EAs/QM5_38006_codetrading-doji-hammer-pivot-rejection/QM5_38006_codetrading-doji-hammer-pivot-rejection.mq5:77` validates the approved parameter ranges and the canonical backtest/live risk-mode split. Framework initialization and the canonical 1% safety ceiling are at `:328` and `:358`; the MAE hook is at `:378`; managed exits execute before new-entry admission at `:393`; news admission is wired at `:420`; the closed-bar signal, spread recheck, and broker open are at `:428`, `:432`, and `:436`.
- `framework/EAs/QM5_38006_codetrading-doji-hammer-pivot-rejection/SPEC.md:13` records the exact executable patterns without inventing a separate doji rule; `:47` documents the card-to-framework risk-input mapping; `:96` records the approved source; `:120` records this build revision.
- `framework/EAs/QM5_38006_codetrading-doji-hammer-pivot-rejection/docs/strategy_card.md:1` is an exact text mirror of the repository-approved card, verified by unit test.
- `framework/registry/magic_numbers.csv:17500-17502` reserves slots 0/1/2 for `EURUSD.DWX`, `GBPUSD.DWX`, and `USDJPY.DWX` with magics `380060000`, `380060001`, and `380060002`, attributed to `Codex burn-window build`.
- `framework/include/QM/QM_MagicResolver.mqh:16` carries regenerated registry SHA-256 `82BD5671F97FF1FFE010924DB6C5AC611F3AF10856A0885EF25BC6F8A096F310`; `:18` reports 17,994 retained rows.
- The governed setfile generator produced the three H1 backtest files. Each has `build_hash: pending` at line 13 (the governed compile lane seals provenance), slot offset at line 18, `RISK_FIXED=1000` at line 19, and `RISK_PERCENT=0` at line 20.
- `tools/strategy_farm/tests/test_qm5_38006_rework_static.py:61` verifies the card mirror; `:129` verifies card parameter/risk constraints; `:145` verifies registry slots and attribution; `:158` onward verifies framework wiring and setfile policy.

## Governed commands and results

Resolver regeneration:

```text
python framework/scripts/update_magic_resolver.py --keep-obsolete
[OK] wrote framework/include/QM/QM_MagicResolver.mqh — 17994 rows kept, 0 dropped, sha=82BD5671F97FF1FFE010924DB6C5AC611F3AF10856A0885EF25BC6F8A096F310
```

The same command with `--dry-run --keep-obsolete` was idempotent: 17,994 kept, 0 dropped, identical SHA. A read-only CSV check found 16,560 active rows and **0 duplicate active magics**; the three target rows resolved to the card symbols, slots, and magics above.

Scoped setfile generation was run once per card symbol:

```text
pwsh -NoProfile -File framework/scripts/gen_setfile.ps1 -EaSlug QM5_38006_codetrading-doji-hammer-pivot-rejection -Symbol <EURUSD.DWX|GBPUSD.DWX|USDJPY.DWX> -TF H1 -Env backtest -RiskFixed 1000 -RiskPercent 0 -PortfolioWeight 1
status: ok (all three symbols)
```

Hardening and specification validation:

```text
python tools/strategy_farm/build_gate_hardening.py --repo-root . --ea-label QM5_38006_codetrading-doji-hammer-pivot-rejection
failures: []
warnings: []
files_scanned: 1

python framework/scripts/validate_spec_doc.py framework/EAs/QM5_38006_codetrading-doji-hammer-pivot-rejection
Summary: 1 PASS, 0 FAIL
```

Unit and touched-module tests:

```text
python -m pytest -q tools/strategy_farm/tests/test_qm5_38006_rework_static.py
9 passed in 13.40s

python -m pytest -q tools/strategy_farm/tests/test_gen_setfile.py tools/strategy_farm/tests/test_build_guardrails.py
21 passed in 11.31s
```

The broader resolver/hardening selection returned `43 passed, 1 failed in 449.59s`. The sole failure was `framework/scripts/tests/test_magic_resolver_binary_search.py::test_binary_lookup_is_equivalent_over_every_generated_row_and_misses`: its default `keep_obsolete=False` assertion expected no dropped IDs but the current global registry/tree drops unrelated legacy IDs `1001`, `1015`, and `1016`. The ticket-mandated `--keep-obsolete` generation is green and dropped zero rows; other EAs were deliberately left untouched.

## Build-check boundary and residual risk

The exact scoped command was attempted:

```text
pwsh -NoProfile -File framework/scripts/build_check.ps1 -EALabel QM5_38006_codetrading-doji-hammer-pivot-rejection -SkipCompile
LIVE_FACTORY_AD_HOC_COMPILE_REFUSED: terminal64 processes are alive; use the governed enqueue-compile lane
```

No bypass or compile was attempted because this ticket explicitly forbids compilation and queue mutation. Static hardening, specification validation, governed set generation, focused tests, and registry/resolver checks passed. Binary compilation and replacement of `build_hash: pending` therefore remain owned by the governed `COMPILE_EA` lane.

## Rollback

Revert the single ticket commit with `git revert <ticket-commit-sha>`. This restores the EA source/spec/setfiles, magic-row attribution, resolver hash, test, evidence, and card mirror together. The EA-ID registry was not changed. No runtime or queue rollback is required because this ticket performed no runtime mutation.
