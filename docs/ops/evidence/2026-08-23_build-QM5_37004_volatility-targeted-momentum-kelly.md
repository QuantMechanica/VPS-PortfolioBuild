# build-QM5_37004_volatility-targeted-momentum-kelly — burn-window build evidence

Date: 2026-08-24
Ticket: `build-QM5_37004_volatility-targeted-momentum-kelly`
Branch: `rework-slot-17`
Disposition: `SOURCE_BUILD_COMPLETE_STATIC_PASS_COMPILE_DEFERRED`

## Scope and preflight

- The runtime source of truth is `D:/QM/strategy_farm/artifacts/cards_approved/QM5_37004_volatility-targeted-momentum-kelly.md`; it declares `g0_status: APPROVED`, D1, no ML, and the four-symbol universe SP500.DWX / NDX.DWX / XTIUSD.DWX / XAUUSD.DWX. The committed mirror at `framework/EAs/QM5_37004_volatility-targeted-momentum-kelly/docs/strategy_card.md:1` is content-equivalent after trimming trailing whitespace (approval at `:10`, symbols at `:33`, timeframe at `:38`).
- The ticket premise that the EA did not exist was stale in this worktree. Source, SPEC, four presets, and focused tests were already tracked through commits `2553a380e` and `4f9cb624b`; this ticket audited and completed the missing governed artifacts rather than creating a duplicate EA or duplicate allocations.
- The allocated identity already existed and was preserved: `framework/registry/ea_id_registry.csv:4467`.
- No compile, backtest, router enqueue, verdict mutation, factory toggle, or T_Live access occurred.

## Executable card mapping

- Final MQ5 SHA-256: `91D530ED141B9F064242166BD72531AE9C5A56DB6C645871E30D70198791FA64`.
- Framework/corset wiring: `QM_Common` is included at `framework/EAs/QM5_37004_volatility-targeted-momentum-kelly/QM5_37004_volatility-targeted-momentum-kelly.mq5:7`; declared card inputs begin at `:45`; parameter validation begins at `:77`; framework initialization is at `:373`; the card's kill-switch rails are wired at `:391`; three-tick slippage is configured at `:406`.
- Bounded closed-bar mechanics: state advances at `.mq5:96`; the single sanctioned `CopyClose` read is bounded to at most 301 closed D1 prices and marked `perf-allowed` at `:118`; the exponential-momentum loop, 20-day volatility loop, and explicit `ArraySize`/term-count guards are at `:136-186`; annualized inverse-volatility and fractional-Kelly weighting is at `:198`.
- Card entry/no-trade/management: the spread, GMT rollover, account realized-loss, and one-position filters begin at `.mq5:221`; fixed/live risk scaling is at `:249`; total-drawdown enforcement is at `:270`; long/short momentum-plus-SMA entry and 2 ATR initial stops begin at `:290`; 3 ATR trailing management is at `:339-350`.
- Per-tick ordering keeps MAE first (`.mq5:430`), total/daily protection and management ahead of entry-only filters, uses one D1 new-bar gate (`:456`), applies the two-axis news filter (`:470`), then evaluates the no-trade filter and entry (`:476-487`).
- `SPEC.md` now points to the approved runtime mirror at `framework/EAs/QM5_37004_volatility-targeted-momentum-kelly/SPEC.md:86` and records this completion at `:111`.
- The focused regression test locks the approved-card mirror, hardening, formula wiring, loss rails, ordering, input use, framework identity, no-ML/performance rules, and preset contracts at `tools/strategy_farm/tests/test_qm5_37004_rework_static.py:60-177`.

## Registry and resolver

- Existing active rows were retained in their deterministic slots and reservation provenance was set to `Codex burn-window build`: `framework/registry/magic_numbers.csv:17462-17465`.
- Active/reserved registry query: `active_rows=17994`, `duplicate_active_magics=0`, `duplicate_active_slots=0`, `ticket_rows=4`, magics `370040000,370040001,370040002,370040003`.
- Command: `python framework/scripts/update_magic_resolver.py --keep-obsolete`.
- Output: `[OK] wrote framework\include\QM\QM_MagicResolver.mqh — 17994 rows kept, 0 dropped, sha=F1DCE81CDEC332FC...`.
- Derived contract: `framework/include/QM/QM_MagicResolver.mqh:16` contains SHA-256 `F1DCE81CDEC332FC43AC9D4795158234620DFE5DFEDE910DA3F252BCDB65E2C9`; row count 17,994 is at `:18`.
- `python framework/scripts/validate_registries.py --json` remains repository-wide FAIL on pre-existing legacy malformed ID/slug rows and retired/history duplication. The required current-row uniqueness was therefore verified independently with the status-scoped query above; this ticket did not alter unrelated registry debt.

## Governed setfiles

The governed generator ran once for each approved `(symbol, D1, backtest)` tuple:

```text
pwsh -File framework/scripts/gen_setfile.ps1 -EaSlug QM5_37004_volatility-targeted-momentum-kelly -Symbol <SYMBOL> -TF D1 -Env backtest
SP500.DWX status=ok sha256=b3dd462107f977e0fdb3e11cee48d74909637e69677cddd6e65fcd66503cbc41
NDX.DWX   status=ok sha256=9cb315428ed5ea708201af4488ef49f5beb2385dfc77dee548b4bd358a856dd7
XTIUSD.DWX status=ok sha256=db936e40d82c41b5f8e39e90e8c4c793e512daab7bc1fb806a3a10c0ce83c10a
XAUUSD.DWX status=ok sha256=135a50b2579ca0b75758ab94755a310e8530531561a825a061b611138ccc5663
```

All presets have version `s20260824-001`, the allocated symbol slot, `RISK_FIXED=1000`, `RISK_PERCENT=0`, and all 13 declared `strategy_*` inputs. Representative SP500 evidence is at `framework/EAs/QM5_37004_volatility-targeted-momentum-kelly/sets/QM5_37004_volatility-targeted-momentum-kelly_SP500.DWX_D1_backtest.set:6-36`. The build hash remains `pending` at `:13` because compilation is explicitly forbidden by this ticket.

The required scoped check was attempted without compilation:

```text
pwsh -File framework/scripts/build_check.ps1 -EALabel QM5_37004_volatility-targeted-momentum-kelly -SkipCompile
exit=1
failure_class=LIVE_FACTORY_AD_HOC_COMPILE_REFUSED
detail=terminal64 processes are alive; ad-hoc compile/build_check is refused
```

The refusal occurred in the compile-pipeline preflight before static checks. The guard was not bypassed, the factory and terminals were not changed, and the suggested compile enqueue was not issued because the ticket forbids compile and router-task creation.

## Validation output

EA-focused and governed-tool pytest suite:

```text
python -m pytest tools/strategy_farm/tests/test_qm5_37004_rework_static.py tools/strategy_farm/tests/test_gen_setfile.py tools/strategy_farm/tests/test_magic_resolver_reconcile_newlines.py tools/strategy_farm/tests/test_governed_magic_allocator.py tools/strategy_farm/tests/test_host_slot_magic_resolution_static.py -q
........................                                                 [100%]
24 passed in 11.39s
```

Other scoped deterministic checks:

```text
python tools/strategy_farm/build_gate_hardening.py --repo-root . --ea-label QM5_37004_volatility-targeted-momentum-kelly
files_scanned=1 failures=0 warnings=0 symbols_observed=4

python framework/scripts/skill_build_ea_guard.py --ea-id 37004 --ea-label QM5_37004_volatility-targeted-momentum-kelly
status=ok; EA registry row, four magic rows, and EA directory present

python framework/scripts/validate_spec_doc.py framework/EAs/QM5_37004_volatility-targeted-momentum-kelly
Summary: 1 PASS, 0 FAIL (of 1)

python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_37004_volatility-targeted-momentum-kelly
verdict=PASS files_checked=5 findings=[] max_news_stale_hours=336

python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_37004_volatility-targeted-momentum-kelly --fail-on-leak --json
SINGLE_SYMBOL_OK n_violations=0

git diff --check
PASS (Git emitted only configured LF-to-CRLF conversion notices)
```

## Risks and open questions

- Compile/runtime behavior remains deliberately unclaimed. The governed COMPILE_EA lane must create the `.ex5`; this ticket neither compiled nor smoked the EA.
- The approved card labels the 3 ATR Chandelier stop as “TP” and shows lifecycle break-even states without a numeric break-even trigger. The implementation follows the exact quantitative exit rule (2 ATR initial server SL plus 3 ATR trailing stop) and does not invent an unparameterized break-even rule.
- Repository-wide legacy registry validation debt remains outside this ticket; active/reserved magic and slot uniqueness is clean.

## Rollback

Revert the ticket commit with `git revert <ticket-commit-sha>`. This restores the prior MQ5 bounds form, SPEC, four preset versions/provenance, magic reservation provenance, and resolver hash, and removes the committed card mirror, regression-test assertions, and evidence file. The EA ID allocation, magic values/slots, factory state, queue, verdict rows, backtests, and T_Live are not mutated by this ticket and require no rollback.
