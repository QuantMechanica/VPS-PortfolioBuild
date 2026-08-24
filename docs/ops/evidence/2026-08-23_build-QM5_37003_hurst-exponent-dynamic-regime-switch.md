# build-QM5_37003_hurst-exponent-dynamic-regime-switch — execution evidence

- Ticket: `build-QM5_37003_hurst-exponent-dynamic-regime-switch`
- EA: `QM5_37003_hurst-exponent-dynamic-regime-switch`
- Worktree: `C:/QM/worktrees/rework-slot-18`
- Executed: 2026-08-24
- Scope: one-EA burn-window build completion only. No compile, backtest, queue/router task, verdict-row, factory, runtime-DB, or `T_Live` mutation.

## Preflight and inherited state

The runtime approved card at
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_37003_hurst-exponent-dynamic-regime-switch.md`
has `status: APPROVED`, `g0_status: APPROVED`, `r2_mechanical: PASS`,
`r3_data_available: PASS`, and `r4_ml_forbidden: PASS`. Its text matches the
repository approved card line-for-line after newline/trailing-space normalization.

This branch already contained an inherited EA implementation and prior rework;
the stale ticket premise that the EA directory did not exist was therefore not
used to overwrite working files or duplicate registry allocations. Registry
preconditions were already satisfied:

- `framework/registry/ea_id_registry.csv:4466` — one active matching EA-ID/slug row.
- `framework/registry/magic_numbers.csv:17459-17461` — active slots 0/1/2 for
  EURUSD.DWX, GBPJPY.DWX, and SP500.DWX, with magics
  370030000/370030001/370030002.
- The rows retain their original `reserved_by=Gemini` provenance. Appending new
  active rows merely to replace that attribution would create duplicate
  `(ea_id, symbol_slot)`/magic identities and was correctly refused.

## What changed

- `framework/EAs/QM5_37003_hurst-exponent-dynamic-regime-switch/QM5_37003_hurst-exponent-dynamic-regime-switch.mq5:74-88`
  now enforces the Strategy Card's declared Hurst lookback, trend threshold,
  revert threshold, and active-live `RISK_PERCENT` ranges fail-closed during
  initialization. Backtest `RISK_PERCENT=0` remains valid and
  `RISK_FIXED=1000` remains the active governed mode.
- The existing mechanism remains wired at `.mq5:105-319`: bounded closed-bar
  R/S Hurst calculation, Hurst regime switch, preceding-20-bar Donchian
  breakout, Bollinger mean reversion/midline exit, ATR stop, 2R trend target,
  spread/rollover/daily-loss/max-position filters, and per-tick mean-reversion
  management.
- Framework contracts remain explicit at `.mq5:374-456`: canonical entry
  configuration/slippage, execution contract, kill switch, MAE hook, two-axis
  news gate, one H1 new-bar gate, and framework entry path.
- `framework/EAs/QM5_37003_hurst-exponent-dynamic-regime-switch/docs/strategy_card.md:1`
  is the required local mirror of the approved card.
- `framework/EAs/QM5_37003_hurst-exponent-dynamic-regime-switch/SPEC.md:17`
  documents the literal treatment of the card's unspecified Bollinger and
  lifecycle details; `SPEC.md:43` documents the card range applied to the
  framework `RISK_PERCENT` input.
- The three H1 backtest presets were regenerated with scoped
  `gen_setfile.ps1 -EaSlug QM5_37003_hurst-exponent-dynamic-regime-switch`
  invocations. Each retains `RISK_FIXED=1000`, `RISK_PERCENT=0`, the correct
  magic slot, every strategy input, and canonical-LF MQ5 SHA-256
  `ddcd564c46868370f7dbf3581c524e64cf4565f5a276c876f72770a5ffc0b250`.
- `tools/strategy_farm/tests/test_qm5_37003_rework_static.py:59-114` now proves
  the approved-card mirror and all four card-declared parameter range guards.

## Registry and resolver evidence

The required resolver command was run after confirming the EA directory and
existing CSV rows:

```text
python framework/scripts/update_magic_resolver.py --keep-obsolete
[OK] wrote framework\include\QM\QM_MagicResolver.mqh — 17994 rows kept, 0 dropped, sha=64147D37E6ADF30E...
```

It was idempotent: neither registry CSV nor the generated resolver differs from
HEAD. A deterministic active-row census returned:

```text
active_rows=16560
duplicate_active_magics=0
```

## Validation output

EA-focused unit and static gates:

```text
python -m pytest -q tools/strategy_farm/tests/test_qm5_37003_rework_static.py
8 passed in 1.59s

python -m pytest -q tools/strategy_farm/tests/test_build_guardrails.py tools/strategy_farm/tests/test_validate_symbol_scope.py tools/strategy_farm/tests/test_qm5_37003_rework_static.py
31 passed in 1.55s

python -m pytest -q tools/strategy_farm/tests/test_build_gate_hardening.py
30 passed in 452.76s

python tools/strategy_farm/build_gate_hardening.py --repo-root . --ea-label QM5_37003_hurst-exponent-dynamic-regime-switch
files_scanned=1; failures=[]; warnings=[]

python tools/strategy_farm/validate_build_guardrails.py --max-news-stale-hours 336 framework/EAs/QM5_37003_hurst-exponent-dynamic-regime-switch
PASS; files_checked=4; findings=[]

python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_37003_hurst-exponent-dynamic-regime-switch --fail-on-leak
SINGLE_SYMBOL_OK; n_violations=0

python framework/scripts/validate_spec_doc.py framework/EAs/QM5_37003_hurst-exponent-dynamic-regime-switch
Summary: 1 PASS, 0 FAIL (of 1)
```

The broader generator/resolver suite completed with `14 passed, 1 failed in
2.88s`. The sole failure was
`framework/scripts/tests/test_magic_resolver_binary_search.py::test_binary_lookup_is_equivalent_over_every_generated_row_and_misses`,
whose `keep_obsolete=False` fixture observes pre-existing missing-directory IDs
`[1001, 1015, 1016]`. This EA added none of those rows/directories, and the
ticket-required `--keep-obsolete` regeneration itself kept all rows and dropped
zero. No unrelated EA or registry policy was changed to mask that census drift.

## Scoped build-check interlock

The required scoped static wrapper was attempted without compilation:

```text
pwsh -NoProfile -File framework/scripts/build_check.ps1 -EALabel QM5_37003_hurst-exponent-dynamic-regime-switch -SkipCompile
BUILD_CHECK_LIVE_FACTORY_COMPILE_REFUSED
failure_class=LIVE_FACTORY_AD_HOC_COMPILE_REFUSED
detail=terminal64 processes are alive; use the governed COMPILE_EA lane
```

The script's compile-pipeline guard executes even with `-SkipCompile` and
refused before its remaining stages. The ticket forbids compilation, compile
enqueue, factory toggles, and terminal intervention, so the guard was not
bypassed. The independent Python hardening/guardrail/spec/symbol gates above
provide the requested non-compile validation, but no compile or runtime PASS is
claimed.

## Rollback

After commit, run `git revert --no-edit <ticket-commit>`. This removes the local
card mirror and focused range regression, restores the prior MQ5/SPEC and three
backtest preset headers, and leaves the pre-existing registry/resolver rows
unchanged. No runtime DB, queue, factory, terminal, backtest, verdict, or live
state requires rollback.

## Risks and open questions

- The approved card names Bollinger bands without period/deviation. The build
  retains the inherited explicit 20-bar/2.0-deviation convention pending an
  upstream card clarification.
- The lifecycle diagram names `BE_Trigger` and `Trailing Trigger` without
  thresholds. They remain inactive; only the exact Section 3.4 SL/TP rules are
  executable. Inventing thresholds would violate the no-improvisation rule.
- Governed compilation and runtime smoke remain the COMPILE_EA lane's work and
  were explicitly out of scope for this ticket.
