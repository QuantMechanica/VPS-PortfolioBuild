# build-QM5_37008_garch-volatility-forecast-breakout — burn-window build evidence

## Scope and preflight

- Ticket: `build-QM5_37008_garch-volatility-forecast-breakout`.
- Approved runtime card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_37008_garch-volatility-forecast-breakout.md`; `g0_status: APPROVED`, targets `SP500.DWX`, `NDX.DWX`, and `XAUUSD.DWX`, timeframe `D1`.
- The current branch already contained an earlier implementation and allocation, contrary to the ticket's stale statement that the EA did not exist. This change completes the inherited build instead of creating a duplicate identity.
- EA registry identity already existed at `framework/registry/ea_id_registry.csv:4471`.
- Active magic rows already existed at `framework/registry/magic_numbers.csv:17482-17484`: slots 0/1/2 map to `SP500.DWX`/`NDX.DWX`/`XAUUSD.DWX`, magics 370080000/370080001/370080002. Their historical `reserved_by=Gemini` provenance was preserved; appending duplicate active rows or rewriting allocation history would violate the collision/append-only rules.
- Scope remained build-only. No compile, smoke, backtest enqueue/delete, router task, verdict mutation, factory toggle, or `C:/QM/mt5/T_Live` access occurred.

## What changed

1. Completed the fail-closed symbol contract. `Strategy_SymbolSlot` now rejects unknown chart symbols and mismatched setfile slots, and `Strategy_ConfigValid` aborts before framework initialization on either mismatch (`framework/EAs/QM5_37008_garch-volatility-forecast-breakout/QM5_37008_garch-volatility-forecast-breakout.mq5:77`, `:91-94`).
2. Declared the approved D1 execution timeframe immediately after `QM_FrameworkInit` and explicitly recorded the framework Friday-close safety override because the card contains no Friday rule (`...mq5:379-383`). This closes the review finding that chart timeframe and Friday-close mode were previously undeclared.
3. Preserved the card mechanism already present in the inherited source: bounded GARCH forecast (`...mq5:121-165`), refreshed closed-D1 state with explicit buffer guards (`...mq5:168-195`), ATR spread/rollover/daily-loss/one-position admission (`...mq5:198-246`), exact long/short cone entries plus one-sigma SL and 2R TP (`...mq5:249-298`), tightening-only one-sigma cone trail (`...mq5:301-339`), framework MAE/news/Friday/risk wiring (`...mq5:356-476`), and no ML/raw `CopyBuffer`.
4. Mirrored the approved card content (line endings and trailing blank-line whitespace normalized) at `framework/EAs/QM5_37008_garch-volatility-forecast-breakout/docs/strategy_card.md:1-226` and documented the fail-closed contract in `SPEC.md:20-26` and revision history at `SPEC.md:125`.
5. Regenerated all three governed D1 backtest presets through `framework/scripts/gen_setfile.ps1`. Each has `RISK_FIXED=1000`, `RISK_PERCENT=0`, the registered slot, and current source SHA-256 `ce0f6c55d8f6d4576a214bb73d17e35b24186080d3a9192aa2dd4613e5fcdae6` (`sets/*_D1_backtest.set:6-20`).
6. Extended the focused pytest guard to require an approved-card content mirror, fail-closed symbol/slot validation, and correctly ordered D1 execution-contract declaration (`tools/strategy_farm/tests/test_qm5_37008_review_rework_static.py:55-68`, `:135-157`).

## Registry and resolver evidence

- `python framework/scripts/update_magic_resolver.py --keep-obsolete`
  - exit 0: `17994 rows kept, 0 dropped, sha=A271541CEA278762...`.
- A second `--keep-obsolete --dry-run` reported the same 17,994 rows and SHA; `git diff --exit-code -- framework/include/QM/QM_MagicResolver.mqh` returned 0, so regeneration was idempotent and produced no content delta.
- Read-only CSV census: `active_rows=16560`, `duplicate_active_magics=0`, `duplicate_active_ea_slots=0`; the target rows were exactly slots 0/1/2 and their registered symbols/magics.

## Validation evidence

- Focused unit tests:
  - `python -m pytest tools/strategy_farm/tests/test_qm5_37008_review_rework_static.py -q`
  - result: `5 passed in 0.88s`.
- Relevant guardrail/unit suite:
  - `python -m pytest tools/strategy_farm/tests/test_qm5_37008_review_rework_static.py tools/strategy_farm/tests/test_build_gate_hardening.py tools/strategy_farm/tests/test_build_guardrails.py tools/strategy_farm/tests/test_validate_symbol_scope.py -q`
  - result: `58 passed in 257.04s`.
- EA-scoped hardening:
  - `python tools/strategy_farm/build_gate_hardening.py --repo-root . --ea-label QM5_37008_garch-volatility-forecast-breakout`
  - exit 0: one source scanned, `failures=[]`, `warnings=[]`; D2/D4/D5/D7-D11/D17-D18 checks passed.
- Python guardrails:
  - `python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_37008_garch-volatility-forecast-breakout`
  - exit 0: `PASS`, four files checked, no findings.
- Skill/spec/symbol checks:
  - `python framework/scripts/skill_build_ea_guard.py --ea-id 37008 --ea-label QM5_37008_garch-volatility-forecast-breakout` -> exit 0, all three prerequisites true.
  - `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_37008_garch-volatility-forecast-breakout` -> `1 PASS, 0 FAIL`.
  - `python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_37008_garch-volatility-forecast-breakout --json --fail-on-leak` -> exit 0, `SINGLE_SYMBOL_OK`, zero violations.
- `git diff --check` over the authorized EA/test/registry/resolver paths returned exit 0 (Git emitted only line-ending notices).

## Governed build-check and broader-suite observations

- The required scoped command was attempted exactly as `pwsh -NoProfile -File framework/scripts/build_check.ps1 -EALabel QM5_37008_garch-volatility-forecast-breakout -RepoRoot . -SkipCompile`.
- It failed closed before validation with `BUILD_CHECK_LIVE_FACTORY_COMPILE_REFUSED` because `terminal64` processes were alive. No bypass or retry was used, and the ticket forbids the suggested compile enqueue. The directly invoked authoritative Python hardening and guardrail checks above both pass with zero findings.
- `python -m pytest tools/strategy_farm/tests/test_execution_contract_lint.py -q` produced `53 passed, 2 failed in 42.32s`. Both failures are unrelated deployed news-calendar fixture drift: expected coverage ended 2026-08-21 with old hashes, while current contracts reference coverage ending 2026-08-29 with new hashes. No calendar/contract file was touched.

## Known risks and open question

- No `.ex5` was compiled or smoke-tested, by explicit ticket instruction. The governed `COMPILE_EA` lane remains responsible for binary evidence.
- The approved card names `BE_Trigger` in its illustrative state diagram but provides no numeric trigger. No separate break-even threshold was invented; the deterministic one-sigma ratchet can naturally advance beyond entry. OWNER/Research may clarify this only through a card revision, not an EA-side guess.
- The card does not specify a finite GARCH warmup length or variance seed. The inherited bounded implementation uses at most 100 D1 closes and a 30-return initial sample, documented in the SPEC and guarded by tests; downstream review should treat this literal implementation choice as explicit rather than inferred source evidence.

## Rollback

After commit, run `git revert <this-commit>` from a clean worktree. That reverts only this EA's source/SPEC/setfiles/card mirror, the focused regression assertions, and this evidence note. Registry CSV contents and the resolver have no content delta, and no DB/factory/backtest/live rollback is required.
