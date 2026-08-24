# Evidence: build-QM5_39002_forexfactory-sonic-r-system

Date: 2026-08-24

Worktree: `C:\QM\worktrees\rework-slot-15`

Ticket: `build-QM5_39002_forexfactory-sonic-r-system`

## Outcome

The ticket premise that the EA did not exist was stale in this worktree. The approved-card implementation was already present and had prior focused remediation in commits `e56c2c8b9` and `0edb32639`. This ticket audited that implementation against the approved runtime card and binding build SOP, preserved the reviewed executable logic, added the required verbatim card mirror, completed the specification, regenerated governed setfiles, normalized the reserved-by registry evidence, and regenerated the magic resolver.

No MT5 compile was attempted. No backtest was enqueued or deleted, no router task was created, no factory state was changed, no verdict row or gate criterion was changed, and `C:/QM/mt5/T_Live` was not touched. The farm state database was not written.

## Changed artifacts

- `framework/EAs/QM5_39002_forexfactory-sonic-r-system/QM5_39002_forexfactory-sonic-r-system.mq5:9-10` links the executable source to its approved-card mirror and exact signal contract. The existing card implementation remains at the strategy input block (`:38`), deterministic state acquisition (`:111`), entry-admission gates (`:152`), signal/entry construction (`:175`), restart-safe break-even management (`:231`), and lifecycle wiring (`:285`, `:322`, `:330`, `:351`).
- `framework/EAs/QM5_39002_forexfactory-sonic-r-system/docs/strategy_card.md:1` mirrors `D:/QM/strategy_farm/artifacts/cards_approved/QM5_39002_forexfactory-sonic-r-system.md`, with only line-ending and blank-line whitespace normalized; `git diff --no-index --ignore-space-at-eol` returned exit 0.
- `framework/EAs/QM5_39002_forexfactory-sonic-r-system/SPEC.md:29` documents why thesis-only volume/pinbar/RSI language is not invented as an executable predicate; `:41` records concrete governed parameters; `:134` records this burn-window audit.
- The three governed backtest setfiles under `framework/EAs/QM5_39002_forexfactory-sonic-r-system/sets/` were regenerated for EURUSD.DWX/slot 0, GBPUSD.DWX/slot 1, and USDJPY.DWX/slot 2. Each records `RISK_FIXED=1000` and `RISK_PERCENT=0` at lines 19-20. Their build hashes remain `pending` because the ticket explicitly excludes compilation.
- `framework/registry/ea_id_registry.csv:4481` already contained the single active ID row, so no duplicate row was appended.
- `framework/registry/magic_numbers.csv:17509-17511` contains the three active rows, magics `390020000` through `390020002`, with `reserved_by=Codex burn-window build`.
- `framework/include/QM/QM_MagicResolver.mqh:16-18` was regenerated with `--keep-obsolete`; registry SHA-256 is `1CE571EF91F15A3BF6620527444E392457E935384859AFC05A107BA841388952` and row count is 17,994.

## Registry proof

Command: active-row projection of `framework/registry/magic_numbers.csv`, grouped by `magic` and by `ea_id|symbol_slot`, plus an exact `ea_id=39002` projection and `ea_id_registry.csv` count.

```text
active_rows=16560
duplicate_active_magics=0
duplicate_active_ea_slots=0
target_rows=3
ea_id_rows=1
39002 slot=0 EURUSD.DWX magic=390020000 reserved_by=Codex burn-window build status=active
39002 slot=1 GBPUSD.DWX magic=390020001 reserved_by=Codex burn-window build status=active
39002 slot=2 USDJPY.DWX magic=390020002 reserved_by=Codex burn-window build status=active
```

Resolver verification:

```text
python framework/scripts/update_magic_resolver.py --keep-obsolete --dry-run
[dry-run] 17994 rows kept, 0 dropped
sha=1CE571EF91F15A3BF6620527444E392457E935384859AFC05A107BA841388952
```

## Validation evidence

```text
python -m pytest -q tools/strategy_farm/tests/test_qm5_39002_rework_static.py
6 passed in 0.61s

python -m pytest -q tools/strategy_farm/tests/test_build_gate_hardening.py
30 passed in 169.42s (0:02:49)

python tools/strategy_farm/build_gate_hardening.py --repo-root . --ea-label QM5_39002_forexfactory-sonic-r-system
files_scanned=1; failures=[]; warnings=[]; symbols_observed=3

python tools/strategy_farm/validate_build_guardrails.py --max-news-stale-hours 336 framework/EAs/QM5_39002_forexfactory-sonic-r-system
files_checked=4; findings=[]; verdict=PASS

python framework/scripts/validate_spec_doc.py framework/EAs/QM5_39002_forexfactory-sonic-r-system
PASS QM5_39002_forexfactory-sonic-r-system
Summary: 1 PASS, 0 FAIL (of 1)

git diff --check
exit 0
```

The required scoped build-check invocation was attempted without compile authorization:

```text
pwsh -NoProfile -File framework/scripts/build_check.ps1 -EALabel QM5_39002_forexfactory-sonic-r-system -SkipCompile
exit 1: LIVE_FACTORY_AD_HOC_COMPILE_REFUSED
```

The guard refused while live factory `terminal64` processes were present. The governed hint would require a compile-lane enqueue, which this ticket explicitly forbids. Setfile generation and all compile-independent scoped checks above completed; compilation remains for the governed `COMPILE_EA` lane.

## Rollback

Revert the single commit created for this ticket with `git revert <ticket-commit>`. This restores the prior SPEC, setfiles, magic reservation attribution, resolver hash, and source annotations, and removes the card mirror and this evidence record. No runtime, queue, database, or live-terminal rollback is required because none was changed.
