# build-QM5_21509_qs-emv-trend-ndx evidence — 2026-08-24

Ticket: `build-QM5_21509_qs-emv-trend-ndx`

Worktree: `C:\QM\worktrees\rework-slot-17`

## Status and safety boundary

Build-only implementation is complete for the OWNER-approved `QM5_21509`
card. The approved card declares `g0_status: APPROVED` and the single-symbol
`NDX.DWX` universe (`framework/EAs/QM5_21509_qs-emv-trend-ndx/docs/strategy_card.md:17`,
`:24`). The existing EA-ID row was verified, not rewritten
(`framework/registry/ea_id_registry.csv:4389`).

No EA compile or backtest was run, no work item or router task was created, no
backtest was enqueued or deleted, no verdict was changed, the factory was not
toggled, and `C:/QM/mt5/T_Live` was not touched.

## Implementation evidence

- The EA exposes and uses all seven card parameters
  (`framework/EAs/QM5_21509_qs-emv-trend-ndx/QM5_21509_qs-emv-trend-ndx.mq5:43-49`).
- Bespoke EMV uses a bounded `MqlRates` vector, explicit `ArraySize` proofs,
  native tick volume divided by the governed scale, and no-update carry
  semantics for zero range/volume (`...mq5:93-160`, `:203-206`). There is no
  raw `CopyBuffer`, ML, web request, `CTrade`, or raw indicator-handle call.
- Completed-bar state caches both smoothed EMV values, close, SMA50, and ATR14
  once per D1 bar (`...mq5:165-235`). Long/short entries are exact zero crosses
  with the corresponding SMA agreement (`...mq5:273-277`).
- The spread cap is entry-only and accepts legitimate zero modeled spread;
  every entry gets a normalized `2.5 * ATR` hard stop (`...mq5:288-309`).
- Trend failure and a restart-safe 50-completed-D1-bar stop latch the exact
  owned ticket (`...mq5:176-186`, `:226-234`, `:319-334`). Exit closure also
  checks ticket, symbol, and magic (`...mq5:393-407`, `:418-432`).
- Framework wiring includes `QM_Common`, `QM_FrameworkInit`, the first-line MAE
  hook, Friday-close management, and two-axis news filtering with management
  and exit above the entry-only news gate (`...mq5:348-454`). Backtest risk is
  `RISK_FIXED=1000`, while live remains framework-selected `RISK_PERCENT`
  (`...mq5:24-27`).
- `SPEC.md` documents mechanics, declared inputs, single-symbol universe, and
  risk contract (`framework/EAs/QM5_21509_qs-emv-trend-ndx/SPEC.md:11`, `:19`,
  `:33`, `:80`). The local strategy card is an exact 197-line mirror of the
  approved artifact.

## Registry, resolver, and setfile evidence

- Added slot 0 for `NDX.DWX`, magic `215090000 = 21509 * 10000 + 0`, with the
  required reservation text (`framework/registry/magic_numbers.csv:18027`).
- Read-only CSV verification: `active_rows=16561`,
  `duplicate_active_magics=0`, target magic rows `1`, target EA-ID rows `1`.
- Regenerated with
  `python framework/scripts/update_magic_resolver.py --keep-obsolete`:
  `17995 rows kept, 0 dropped`, SHA prefix `88CAC062A2636BB7`. The generated
  contract records the full SHA and row count
  (`framework/include/QM/QM_MagicResolver.mqh:16-18`). A subsequent dry-run
  reported the same row count, zero dropped rows, and identical SHA.
- Generated the one authorized setfile with
  `framework/scripts/gen_setfile.ps1 -EaSlug QM5_21509_qs-emv-trend-ndx -Symbol NDX.DWX -TF D1 -Env backtest`.
  Its header is `NDX.DWX / D1 / FIXED`, and all seven card defaults are present
  (`framework/EAs/QM5_21509_qs-emv-trend-ndx/sets/QM5_21509_qs-emv-trend-ndx_NDX.DWX_D1_backtest.set:7-13`,
  `:24-30`). The declared build hash
  `32a1dd8b70e3ee249479bbde35710d691e0b2f325c0f3f7bf79a93a6c9dad236`
  exactly matches `build_check.ps1`'s CRLF/SHA-256 algorithm applied to the
  generated `pending` form.

## Validation evidence

- `python tools/strategy_farm/build_gate_hardening.py --repo-root . --ea-label QM5_21509_qs-emv-trend-ndx`
  — exit 0, `files_scanned=1`, zero failures, exact card/magic/setfile universe
  `NDX.DWX`. One non-blocking D14 warning is a parser false positive: it reads
  the prose phrase “a rising EMV” as an SMA-direction declaration, while the
  card's SMA rule is price-above/price-below, implemented at source lines
  273-276.
- `python tools/strategy_farm/validate_build_guardrails.py <target.mq5>` —
  `verdict=PASS`, one file checked, zero findings.
- `python framework/scripts/validate_spec_doc.py <EA directory>` —
  `1 PASS, 0 FAIL`.
- `python -m pytest tools/strategy_farm/tests/test_build_gate_hardening.py tools/strategy_farm/tests/test_gen_setfile.py tools/strategy_farm/tests/test_magic_resolver_reconcile_newlines.py -q`
  — `32 passed in 670.44s`.
- `python -m pytest tools/strategy_farm/tests/test_build_guardrails.py -q` —
  `20 passed in 1.14s`.
- Resolver static tests — `12 passed, 1 failed in 1.47s`. The sole failing
  binary-search test calls `load_rows(keep_obsolete=False)` and asserts that the
  repository has no obsolete EA IDs; it reports the pre-existing obsolete IDs
  `1001, 1015, 1016`. This ticket was explicitly required to regenerate with
  `--keep-obsolete`, and did not alter or remove those unrelated rows. Hash,
  strict-default, and symbol-fail-closed resolver tests all passed.
- `git diff --check` — exit 0. Target forbidden-pattern scan — zero hits.

The requested scoped command
`framework/scripts/build_check.ps1 -EALabel QM5_21509_qs-emv-trend-ndx -SkipCompile`
was attempted once. It refused before compile, validation, or mutation because
`Assert-CompilePipelineGuard` detected active T1-T10 factory terminals and
returned `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`. No terminal was stopped and no
guard was bypassed. The allowed direct hardening path above therefore supplies
the scoped zero-failure build-gate evidence; the governed compile lane remains
responsible for the later full build-check/compile receipt.

## Risks and open questions

- Per ticket, there is no compiler or Strategy Tester evidence in this build
  commit. Syntax/runtime proof belongs to the governed `COMPILE_EA` lane.
- The full `build_check.ps1` wrapper cannot currently execute `-SkipCompile`
  while factory terminals are live because its compile interlock runs before
  the skip branch. Pipeline ownership should decide whether that wrapper needs
  a separately governed validation-only path; this build did not weaken or
  bypass the interlock.
- The repository-wide binary resolver test remains red on three unrelated
  obsolete EA IDs under its non-`--keep-obsolete` assumption. The generated
  resolver required by this ticket retains them by explicit instruction.

## Rollback

Use `git revert <this ticket commit>`; do not reset the branch. That removes the
EA implementation/docs/setfile and the appended magic allocation while
restoring the prior generated resolver. No runtime or database rollback is
required because this ticket made no runtime/state mutation.
