# build-QM5_38005_codetrading-ascending-triangle-breakout — burn-window build evidence

Date: 2026-08-24
Ticket: `build-QM5_38005_codetrading-ascending-triangle-breakout`
Branch: `rework-slot-17`
Disposition: `SOURCE_BUILD_COMPLETE_STATIC_PASS_COMPILE_DEFERRED`

## Scope and preflight

- The runtime source of truth is `D:/QM/strategy_farm/artifacts/cards_approved/QM5_38005_codetrading-ascending-triangle-breakout.md`; it declares `g0_status: APPROVED`, H1, no ML, and the three-symbol universe XAUUSD.DWX / SP500.DWX / EURUSD.DWX. The committed EA mirror at `framework/EAs/QM5_38005_codetrading-ascending-triangle-breakout/docs/strategy_card.md:1` is content-equivalent after trimming trailing whitespace (approval at `:10`, symbols at `:33`).
- The ticket premise that the EA did not exist was stale in this worktree. The source, SPEC, three presets, and focused tests were already tracked through commits `4256cf984` and `6fdb5b310`; this ticket audited and completed the missing governed artifacts rather than duplicating the EA.
- The allocated EA identity already existed and was not duplicated: `framework/registry/ea_id_registry.csv:4476`.

## Executable card mapping

- The source SHA-256 is `060403f50d18d840643941c251bf80a89a0e752b2f56be56dfb6de3e8dfece1f`.
- Framework/corset wiring: `QM_Common` include and canonical framework inputs are at the top of `framework/EAs/QM5_38005_codetrading-ascending-triangle-breakout/QM5_38005_codetrading-ascending-triangle-breakout.mq5`; configuration validation begins at `:87`, framework init at `:497`, H1 execution-contract declaration at `:515`, slippage configuration at `:523`, risk cap at `:531`, and kill-switch thresholds at `:532`.
- Bounded closed-bar mechanics: the guarded `CopyRates` buffer is implemented at `.mq5:131`; triangle/pivot/volume state advances once per H1 bar at `.mq5:202`. Every dynamic rates access is protected by actual `ArraySize`/copy-count checks, and the only raw OHLCV retrieval is the sanctioned bounded structural `CopyRates` call.
- Card entry and management: daily realized-loss admission is at `.mq5:312`, no-trade conditions at `.mq5:324`, long/short entry construction at `.mq5:345`, and break-even plus tightening-only swing-pivot trailing at `.mq5:402`.
- Per-tick ordering keeps MAE sampling first (`.mq5:552`), advances closed-bar state before management (`:560` / `:565`), keeps management ahead of entry-only filters/news, and uses the two-axis news filter at `:594`.
- The SPEC now points at the approved mirror (`framework/EAs/QM5_38005_codetrading-ascending-triangle-breakout/SPEC.md:5`), documents executable parameter bounds (`:27` onward), and records this build completion at `:112`.

## Registry and resolver

- Existing active rows were retained in their allocated slots and their reservation provenance was set to the ticket-required `Codex burn-window build`: `framework/registry/magic_numbers.csv:17497-17499`.
- Deterministic verification over active rows returned `duplicate_active_magics=0` and `duplicate_active_slots=0`.
- Command: `python framework/scripts/update_magic_resolver.py --keep-obsolete`
- Output: `[OK] wrote framework\include\QM\QM_MagicResolver.mqh — 17994 rows kept, 0 dropped, sha=3957BA51F8836A7D...`
- Derived contract: `framework/include/QM/QM_MagicResolver.mqh:16` contains SHA-256 `3957BA51F8836A7D3C26E4E4242BD29DC88FC18CDF667D33C6FB3D9F6AB4A340`; row count 17,994 is at `:18`.

## Governed setfiles

The governed generator ran once for each approved `(symbol, H1, backtest)` tuple:

```text
pwsh -File framework/scripts/gen_setfile.ps1 -EaSlug QM5_38005_codetrading-ascending-triangle-breakout -Symbol <SYMBOL> -TF H1 -Env backtest
XAUUSD.DWX status=ok sha256=f3539dd12650b8e8e796c7113da2907f9bbeebbfe9fcbc76596c9f7708b24aef
SP500.DWX  status=ok sha256=8b48d677086cef63c51884f2278cf4af67bfc477a209d2a9786fe845545c4935
EURUSD.DWX status=ok sha256=c3e1d84f13eaa1baef52c05d8440014a3448a5fa72e1d1528b9f3ff6a497aa1b
```

All three presets have version `s20260824-001`, their allocated symbol slot, `RISK_FIXED=1000`, `RISK_PERCENT=0`, H1 enum `16385`, and every declared `strategy_*` input (representative XAUUSD evidence: `sets/QM5_38005_codetrading-ascending-triangle-breakout_XAUUSD.DWX_H1_backtest.set:6-25`). The build hash remains `pending` at line 13 by design because this ticket explicitly forbids compilation.

The required scoped check was attempted without compilation:

```text
pwsh -File framework/scripts/build_check.ps1 -EALabel QM5_38005_codetrading-ascending-triangle-breakout -SkipCompile
exit=1
failure_class=LIVE_FACTORY_AD_HOC_COMPILE_REFUSED
detail=terminal64 processes are alive; ad-hoc compile/build_check is refused
```

The refusal occurred in the compile-pipeline preflight before static checks. No terminal was stopped, no factory flag was changed, the guard was not bypassed, and the suggested `enqueue-compile` command was not run because this ticket forbids router/enqueue mutation.

## Validation output

EA-focused and touched-tool pytest suite (`test_qm5_38005_review_rework.py:26-148`, plus generator, resolver-newline, governed allocator, and host-slot tests):

```text
python -m pytest tools/strategy_farm/tests/test_qm5_38005_review_rework.py tools/strategy_farm/tests/test_gen_setfile.py tools/strategy_farm/tests/test_magic_resolver_reconcile_newlines.py tools/strategy_farm/tests/test_governed_magic_allocator.py tools/strategy_farm/tests/test_host_slot_magic_resolution_static.py -q
......................                                                   [100%]
22 passed in 9.26s
```

Other scoped deterministic checks:

```text
python framework/scripts/validate_spec_doc.py framework/EAs/QM5_38005_codetrading-ascending-triangle-breakout
Summary: 1 PASS, 0 FAIL (of 1)

python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_38005_codetrading-ascending-triangle-breakout
verdict=PASS files_checked=4 findings=[] max_news_stale_hours=336

python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_38005_codetrading-ascending-triangle-breakout --fail-on-leak
SINGLE_SYMBOL_OK n_violations=0

python tools/strategy_farm/build_gate_hardening.py --repo-root . --ea-label QM5_38005_codetrading-ascending-triangle-breakout
files_scanned=1 failures=[] warnings=[] symbols_observed=3

git diff --check
PASS (Git emitted only configured LF-to-CRLF conversion notices)
```

## Literal ambiguity record

The binding build SOP requires ambiguous card language to be recorded while proceeding with the most literal deterministic reading. No gate threshold was changed:

- The card gives slope thresholds without units; the EA uses ATR-normalized price change per pivot-bar distance.
- The card defines ascending geometry but separately requires a short descending-triangle path; the short path is the exact geometric mirror.
- The card gives no pivot search depth; the bounded default is 30 H1 bars.
- The lifecycle names `BE_Trigger` without a value; the implementation uses +1R, then permits tightening-only swing-pivot trailing.
- The card simultaneously names TP as one triangle height and labels it 1:2 R:R; TP remains one projected height and formations offering less than 2R are rejected.

These are implementation questions for future OWNER card clarification, not authorization to alter the current gate criteria or mechanics.

## Rollback

Revert the ticket commit with `git revert <ticket-commit-sha>`. This restores the prior three preset headers/provenance, SPEC text, magic reservation provenance, and resolver hash, and removes the committed card mirror/evidence file. The EA source, allocated magic values/slots, EA-ID row, factory state, queue, verdict rows, backtests, and T_Live are not mutated by this ticket and require no rollback.
