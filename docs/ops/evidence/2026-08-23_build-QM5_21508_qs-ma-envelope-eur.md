# build-QM5_21508_qs-ma-envelope-eur — burn-window EA build evidence

Date executed: 2026-08-24

Worktree: `C:/QM/worktrees/rework-slot-16`

Scope: build-only implementation of the OWNER-approved `QM5_21508_qs-ma-envelope-eur` Strategy Card. No compile, backtest, enqueue, router task, verdict mutation, factory toggle, state-DB write, book action, or `T_Live` action was performed.

## Pre-flight evidence

- Approved source card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_21508_qs-ma-envelope-eur.md`; frontmatter contains `g0_status: APPROVED`, `target_symbols: [EURUSD.DWX]`, `single_symbol_only: true`, and `period: D1`. The build-time mirror is `framework/EAs/QM5_21508_qs-ma-envelope-eur/docs/strategy_card.md` and matched the approved source exactly after newline normalization.
- The deterministic EA allocation already existed and was not rewritten: `framework/registry/ea_id_registry.csv:4388` maps `21508` to `qs-ma-envelope-eur`, source `0b564ef2-810c-5b1d-9084-342ddb20575c`, status `active`.
- `EURUSD.DWX` is present in the governed symbol namespace at `framework/registry/dwx_symbol_matrix.csv:16`.
- Pre-allocation query over active `magic_numbers.csv` rows returned `preflight_matches=0` for EA 21508 or magic 215080000.

## What changed

### EA and documentation

- `framework/EAs/QM5_21508_qs-ma-envelope-eur/QM5_21508_qs-ma-envelope-eur.mq5:7-37` defines the current V5 framework/risk/two-axis-news/Friday/stress inputs and all six declared Strategy Card inputs. Backtest defaults are `RISK_FIXED=1000.0` and `RISK_PERCENT=0.0`.
- `...mq5:41-53` enforces the card's EURUSD.DWX, D1, parameter, and `strategy_ma_period + 5` completed-history contract.
- `...mq5:58-124` implements one-position-per-magic entry, the entry-only zero-spread-safe cap (`:72-81`), fixed-percentage SMA bands, strict-touch semantics, fresh lower/upper breaches (`:109`, `:117`), and a completed-signal-bar ATR hard stop (`:112`, `:120`). `req.tp` remains zero.
- `...mq5:128-168` adds no trailing/BE/partial/scale-in mechanics and implements the exact long/short SMA reversion exits (`:157`, `:159`) plus the completed-D1-bar max hold (`:163-164`).
- `...mq5:177-263` retains the skeleton's `QM_FrameworkInit`, first-statement MAE hook (`:208`), management/exit-before-news entry gate, two-axis news wiring (`:240`), single framework new-bar gate, equity stream hook, zero-initialized request, and framework trade lifecycle.
- `framework/EAs/QM5_21508_qs-ma-envelope-eur/SPEC.md:11-94` documents all seven required Q01 sections and the initial build revision.
- `framework/EAs/QM5_21508_qs-ma-envelope-eur/docs/strategy_card.md` mirrors the approved runtime card.

### Registry and resolver

- Appended `framework/registry/magic_numbers.csv:18027`: EA 21508, slot 0, `EURUSD.DWX`, magic `215080000`, reserved by `Codex burn-window build`, active.
- Regenerated `framework/include/QM/QM_MagicResolver.mqh` only through:

  `python framework/scripts/update_magic_resolver.py --keep-obsolete`

  Output: `[OK] wrote framework\include\QM\QM_MagicResolver.mqh — 17995 rows kept, 0 dropped, sha=DD7861730203725C...`

- Resolver evidence: `framework/include/QM/QM_MagicResolver.mqh:16` has SHA256 `DD7861730203725C0BFDF646126ED5AB3633958DB60B7F181C67BC8CB4C1C357`; `:18` has 17,995 rows.
- Post-regeneration query: `duplicate_active_magics=0`; EA 21508 has exactly one active row.

### Governed setfile and tests

- Generated only the approved symbol/timeframe via:

  `pwsh -NoProfile -File framework/scripts/gen_setfile.ps1 -EaSlug QM5_21508_qs-ma-envelope-eur -Symbol EURUSD.DWX -TF D1 -Env backtest`

  Output status was `ok`; setfile SHA256 was `A82C3A5A406F99674C049AD51A2394634D73A1644A63657AA93B2EA376128A3E`.
- `framework/EAs/QM5_21508_qs-ma-envelope-eur/sets/QM5_21508_qs-ma-envelope-eur_EURUSD.DWX_D1_backtest.set:3-29` binds EA 21508, EURUSD.DWX, D1, backtest/FIXED risk, and all six approved defaults.
- Added focused pytest coverage at `tools/strategy_farm/tests/test_qm5_21508_qs_ma_envelope_eur.py:16-120` for card semantics, framework wiring, registry identity/magic, documentation, and setfile defaults.

## Validation evidence

### Focused EA tests

Command:

`python -m pytest -q tools/strategy_farm/tests/test_qm5_21508_qs_ma_envelope_eur.py`

Output:

```text
....                                                                     [100%]
4 passed in 2.42s
```

### Deterministic guards

- `python tools/strategy_farm/build_gate_hardening.py --repo-root . --ea-label QM5_21508_qs-ma-envelope-eur`
  - schema: `qm.build-gate-hardening/v1`
  - files scanned: 1
  - failures: 0
  - warnings: 0
- `python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_21508_qs-ma-envelope-eur`
  - verdict: PASS
  - files checked: 2
  - findings: none
- `python framework/scripts/skill_build_ea_guard.py --ea-id 21508 --ea-label QM5_21508_qs-ma-envelope-eur`
  - status: ok
  - `ea_registry_row=true`, `magic_registry_rows=true`, `ea_dir_exists=true`
- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_21508_qs-ma-envelope-eur`
  - `PASS QM5_21508_qs-ma-envelope-eur`; summary `1 PASS, 0 FAIL`.
- `git diff --check`
  - no whitespace errors (only the repository's LF→CRLF working-copy warnings).

### Touched-module pytest batch

Command covered the focused EA test, `test_build_gate_hardening.py`, `test_gen_setfile.py`, four magic-resolver suites, and `test_health_registry_uniqueness.py`.

```text
56 passed, 1 failed in 475.84s
```

The sole failure was `framework/scripts/tests/test_magic_resolver_binary_search.py:86`, where `load_rows(keep_obsolete=False)` returned pre-existing obsolete-only EA IDs `[1001, 1015, 1016]` while the fixture expects `[]`. It is unrelated to EA 21508: the ticket-required `--keep-obsolete` regeneration kept all 17,995 rows and dropped zero. No obsolete EA, fixture, or resolver policy was changed to mask the failure.

### Scoped build-check interlock

Attempted exactly scoped and non-compiling:

`pwsh -NoProfile -File framework/scripts/build_check.ps1 -EALabel QM5_21508_qs-ma-envelope-eur -SkipCompile`

It refused before executing checks because live factory `terminal64` processes were present: `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`, with the governed compile-enqueue lane as its suggested action. This ticket explicitly forbids compilation and enqueue, so the interlock was not bypassed and no enqueue was created. The ticket-authorized Python hardening alternative passed with zero failures as shown above.

## Artifact hashes

| Artifact | SHA256 |
|---|---|
| MQ5 source | `D4186206E9D0E16BDD909708E69A2B1871176F9736E86210F06A56260D2C5DC8` |
| Backtest setfile | `A82C3A5A406F99674C049AD51A2394634D73A1644A63657AA93B2EA376128A3E` |
| Strategy Card mirror | `58311096FB7FBBB188B69084876C8F09A9B9C2CB2FBFB381E7F7C02DC59F693F` |

## Risks and open questions

- The EA is intentionally not compiled in this ticket; the governed `COMPILE_EA` lane remains responsible for MQL5 compilation and binary evidence.
- The generated setfile retains `build_hash: pending` until that governed lane seals the build identity.
- The unrelated obsolete-only resolver fixture remains red as documented above.
- Open questions: none. The approved card is mechanically complete; the frontmatter `g0_status: APPROVED` and approved-reservoir location are the build authority.

## Rollback

Revert the ticket commit with `git revert <ticket-commit>`. This removes the EA source/spec/card mirror/setfile/test, removes the appended magic row, and restores the prior generated resolver. The pre-existing EA-ID registry row remains unchanged. No runtime DB, queue, verdict, factory, backtest, router, book, or live rollback is required because none was mutated.
