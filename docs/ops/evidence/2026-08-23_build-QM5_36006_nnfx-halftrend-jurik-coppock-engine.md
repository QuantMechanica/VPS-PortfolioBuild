# build-QM5_36006_nnfx-halftrend-jurik-coppock-engine — burn-window EA build evidence

## Authority and scope

- Ticket: `build-QM5_36006_nnfx-halftrend-jurik-coppock-engine`.
- Approved runtime card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_36006_nnfx-halftrend-jurik-coppock-engine.md` with `g0_status: APPROVED`.
- Durable build mirror: `framework/EAs/QM5_36006_nnfx-halftrend-jurik-coppock-engine/docs/strategy_card.md:10,33,38`.
- The branch already contained an earlier tracked EA implementation and registry allocation despite the ticket's creation-time statement that the EA did not exist. The build was therefore reconciled in place under the canonical label; no parallel `_v2` identity was created.
- No compile, smoke test, backtest enqueue/delete, router task, verdict mutation, gate threshold change, factory toggle, or `C:/QM/mt5/T_Live` access occurred.

## Preflight and registry evidence

- EA namespace row already existed and matched the card slug: `framework/registry/ea_id_registry.csv:4461`.
- The required active symbol allocations already existed, so they were reused rather than duplicated or given false new reservation provenance:
  - EURUSD.DWX slot 0 / magic 360060000: `framework/registry/magic_numbers.csv:17445`.
  - GBPUSD.DWX slot 1 / magic 360060001: `framework/registry/magic_numbers.csv:17446`.
  - USDJPY.DWX slot 2 / magic 360060002: `framework/registry/magic_numbers.csv:17447`.
- Resolver regeneration:

  ```text
  python framework/scripts/update_magic_resolver.py --keep-obsolete
  [OK] wrote framework\include\QM\QM_MagicResolver.mqh — 17994 rows kept, 0 dropped, sha=1CE571EF91F15A3B...
  ```

  The generated contract is visible at `framework/include/QM/QM_MagicResolver.mqh:16,18`. Regeneration was idempotent, so the two registry CSVs and resolver have no content diff in this commit.
- Duplicate-active-magic audit:

  ```text
  {'active_rows': 16560, 'duplicate_active_magics': 0, 'duplicates': {}}
  ```

## What changed

1. Reconciled the EA with the approved mechanism in `framework/EAs/QM5_36006_nnfx-halftrend-jurik-coppock-engine/QM5_36006_nnfx-halftrend-jurik-coppock-engine.mq5`.
   - A single closed-D1 cache refresh implements the card's HalfTrend, Jurik Velocity, Coppock, CMF, and ATR inputs with one sanctioned raw series call and explicit copied-count/`ArraySize` proofs (`:148-266`; raw call at `:163`).
   - Entry wires all four directional predicates and places the declared 1 ATR stop without a whole-position broker TP (`:293-345`).
   - TP1 closes 50% once, then separately retries the Entry +/- 1 pip protective stop while leaving the HalfTrend runner open (`:348-449`; partial close at `:414`, one-shot state at `:416`, protective stop at `:439`).
   - The 2.0% realized-loss entry halt and 5.0% initial-equity drawdown trip are explicit (`:121-146`); framework daily/total/risk caps are initialized at `:508-513`.
   - The D1 execution contract and card-declared 3-tick deviation are wired through the framework (`:503-506`, `:515-529`).
   - MAE sampling is the first tick lifecycle call; management stays reachable before the D1/new-entry/news/no-trade gates, and the closed-bar HalfTrend exit precedes entry filtering (`:543-585`).
2. Updated `SPEC.md` with the bounded cache, slippage input, exact D1 bar gate, evidence-safe expected behaviour, risk diagnostic, and revision history (`framework/EAs/QM5_36006_nnfx-halftrend-jurik-coppock-engine/SPEC.md:35,61,86,99-102,125,129-133`).
3. Added the approved-card mirror at `framework/EAs/QM5_36006_nnfx-halftrend-jurik-coppock-engine/docs/strategy_card.md`.
4. Regenerated all governed D1 backtest setfiles with scoped `gen_setfile.ps1` calls for EURUSD.DWX, GBPUSD.DWX, and USDJPY.DWX. Every set is source-hash-bound to `cf6c08d21b17e86c46ff97dfcb8987dd867c3aa80c6076fad1dbcb733943ee50`, uses `RISK_FIXED=1000` / `RISK_PERCENT=0`, and carries `strategy_max_slippage_ticks=3.0` (`sets/*.set:13,19-20,42`).
5. Added five focused unit/static tests covering approval/registry/resolver/card-mirror binding, indicator math and bounds, TP1/BE/runner lifecycle, lifecycle ordering/risk/slippage wiring, every-input use, setfile universe and source hashes (`tools/strategy_farm/tests/test_qm5_36006_review_rework.py:50-201`).

## Validation evidence

### Focused EA tests

```text
python -m pytest tools/strategy_farm/tests/test_qm5_36006_review_rework.py -q
.....                                                                    [100%]
5 passed in 1.08s
```

### Related/touched guardrail regression

```text
python -m pytest tools/strategy_farm/tests/test_qm5_36006_review_rework.py tools/strategy_farm/tests/test_build_gate_hardening.py tools/strategy_farm/tests/test_build_guardrails.py tools/strategy_farm/tests/test_killswitch_state_lifecycle_static.py tools/strategy_farm/tests/test_setfile_canonicalization.py -q
..................................................................       [100%]
66 passed in 442.70s (0:07:22)
```

### EA-scoped hardening and deterministic validators

```text
python tools/strategy_farm/build_gate_hardening.py --repo-root . --ea-label QM5_36006_nnfx-halftrend-jurik-coppock-engine
schema=qm.build-gate-hardening/v1 files_scanned=1 failures=0 warnings=0

python framework/scripts/validate_spec_doc.py framework/EAs/QM5_36006_nnfx-halftrend-jurik-coppock-engine
PASS QM5_36006_nnfx-halftrend-jurik-coppock-engine
Summary: 1 PASS, 0 FAIL (of 1)

python tools/strategy_farm/validate_build_guardrails.py <EA source and three setfiles>
verdict=PASS; 4 paths; zero findings

python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_36006_nnfx-halftrend-jurik-coppock-engine --fail-on-leak --verbose
SINGLE_SYMBOL_OK; n_violations=0

python framework/scripts/skill_build_ea_guard.py --ea-id 36006 --ea-label QM5_36006_nnfx-halftrend-jurik-coppock-engine
status=ok; ea_registry_row=true; magic_registry_rows=true; ea_dir_exists=true
```

### Scoped build-check interlock

The required scoped, non-compiling invocation was attempted:

```text
pwsh -NoProfile -File framework/scripts/build_check.ps1 -EALabel QM5_36006_nnfx-halftrend-jurik-coppock-engine -SkipCompile
BUILD_CHECK_LIVE_FACTORY_COMPILE_REFUSED
failure_class=LIVE_FACTORY_AD_HOC_COMPILE_REFUSED
```

`build_check.ps1` executes its compile-pipeline guard even with `-SkipCompile` while factory terminals are alive. Per ticket boundaries, the guard was not bypassed, no terminal/factory state was changed, and no governed `COMPILE_EA` item was enqueued. The independent EA-scoped hardening and Python guardrail surfaces above are clean; fresh compile/build-check evidence remains for the governed compile lane.

## Literal-reading notes and risks

- The card names JMA(14) without phase/power. The implementation fixes the conventional open recurrence to phase 0 (phase ratio 1.5) and power 2; these values are not adaptive.
- The card names Coppock but omits its periods. The implementation uses the conventional ROC(14) + ROC(11), WMA(10) definition and exposes all three as bounded strategy inputs.
- The lifecycle diagram mentions generic BE/trailing states but supplies no trailing trigger or distance. The explicit exit contract governs: TP1 at +1 ATR, then Entry +/- 1 pip protection, with the remaining position exiting only on a HalfTrend direction flip. No undeclared trailing rule was invented.
- These are review-visible literal mappings, not ML/adaptive behaviour. If OWNER intended different Jurik or Coppock constants, the Strategy Card should freeze them before Q02 evidence is treated as comparable.
- The only operational gap is fresh compile/build-check evidence; the ticket explicitly forbids compiling, so this belongs to the governed `COMPILE_EA` lane.

## Rollback

Use `git revert <ticket-commit>`. This restores the prior tracked MQ5, SPEC, and three setfiles and removes the card mirror, focused test, and this evidence note. Registry CSVs and resolver bytes are unchanged by the ticket, and no database, queue, verdict, factory, backtest, or live rollback is required.
