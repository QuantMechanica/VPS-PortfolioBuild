# Q02 stranded ONINIT pairs: instrumented rebuild follow-up (Claude, 2026-09-20)

Task `0ceeea69-43dd-4b3a-a189-fa893a58a5e7`, successor of `4216dd75-6430-4ccb-b545-6c6cf6f3fd4b`.
Input: `docs/ops/evidence/2026-09-19_q02_stranded_pairs/oninit_rootcause_4216dd75.md` and its four
sibling per-pair files. **No verdict touched. No requeue performed this cycle.**

## What this cycle did

1. **Fixed the QM5_10505 `.set` hygiene defect first**, as the acceptance criterion required.
2. **Read the actual current source of `QM_FrameworkInitCoreAfterRuntimeStateArmed`**
   (`framework/include/QM/QM_Common.mqh`) rather than trusting the predecessor doc's
   characterization. Finding: the predecessor's premise ("bare `return false`, only
   `magic_resolution_failed` is logged") was **out of date** — 5 of 8 internal rejection
   branches already emit `QM_LogEvent(QM_ERROR,"FRAMEWORK_INIT_FAILED",{"reason":...})`:
   `runtime_state_not_armed`, `ea_id_non_positive`, `portfolio_weight_out_of_range`,
   `risk_inputs_invalid`, `magic_resolution_failed`. The genuinely silent branches were three
   others further down the same function, plus one in the runtime-execution-contract gate it
   calls first. Those are the ones actually added this cycle.
3. **Added self-describing `QM_LogEvent` predicates to the remaining silent branches** —
   additive-only, no control-flow/threshold/economics change, same style as the 2026-08-17
   precedent (`docs/ops/evidence/2026-08-17_bars_zero_is_oninit_rejection_misclassified_as_infra.md`).
   See `source_repair_authority.json` for the exact files/hashes/summary.
4. Wrote the governed source-repair-authority packet documenting the change and its scope
   (`cross_ea: true` because both edited files are shared includes; `compile_ea: false` because
   no compile was dispatched this cycle — see "What this cycle did NOT do").

## Per-pair disposition

| EA | Symbol | Disposition this cycle | Rationale |
|---|---|---|---|
| QM5_12582 | XNGUSD.DWX | **FIX APPLIED, PENDING VERIFICATION** | Same `OnInit returns non-zero code 1` signature as QM5_10505 — genuinely runs inside `QM_FrameworkInitCoreAfterRuntimeStateArmed`. Neither EA defines `QM_PATTERN_PERMISSION_EA_MANAGED`, so `QM_EntryPatternConfigure()` executes for both and was, until this cycle, a silent `return false` path — now logged. `QM_RiskSizerConfigure` and `QM_ChartUI_Init` failures were the other two silent candidates; also now logged. Next real compile+Q02 attempt will show which (if any) of these three fires, or confirm the failure is still one of the five already-logged branches (in which case the missing piece is log-sample capture into evidence, a separate finding, not a code defect). |
| QM5_10505 | XAUUSD.DWX | **FIX APPLIED (setfile) + FIX APPLIED (logging), PENDING VERIFICATION** | Same signature class as QM5_12582 — see above. Setfile hygiene defect fixed independently (below). |
| QM5_10369 | GDAXI.DWX + NDX.DWX | **STILL UNRESOLVED — this repair does not reach it** | Tester-log wording `OnInit reports incorrect input parameters` + zero logger files on disk = MT5's own `.set`-to-`.ex5` parameter binder rejecting **before** `OnInit()` is ever invoked, i.e. upstream of every function touched in this repair. No source-code logging fix can surface a rejection that happens before the EA's code runs at all. Confirming this needs either a fresh run with the raw journal deliberately preserved before the 2h purge, or MetaEditor-side inspection of the compiled `.ex5` input signature vs. the `.set` file's key/value list — neither available from this session (see "Constraints" below, unchanged from the predecessor). No requeue performed. |
| QM5_10327 | GDAXI.DWX | **REAFFIRMED: out of ONINIT_FAILED batch, no action** | Most recent real evidence (`838e5951-...`, 2026-09-15) is `reason_classes=[TIMEOUT, INCOMPLETE_RUNS]`, `oninit_failure_detected=false` — not an OnInit rejection. Predecessor's disposition stands. |

## The QM5_10505 setfile hygiene fix

`framework/EAs/QM5_10505_mql5-macd-sar/sets/QM5_10505_mql5-macd-sar_XAUUSD.DWX_H1_backtest.set`
carried nine `qm_filter_*` keys with no corresponding `input` in the current
`QM5_10505_mql5-macd-sar.mq5` (orphaned residue from a source refactor that removed a
filter-library input group) and omitted `qm_ea_id` entirely. Fixed by direct hand-edit (not a
full `gen_setfile.ps1` regeneration, to avoid silently pulling in unrelated card-default drift
for inputs this set file currently leaves undeclared): removed the nine orphaned keys, added
`qm_ea_id=10505`. Every other value (`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`,
`qm_magic_slot_offset=3`) is byte-identical to before. This is a real, independent, low-risk fix
regardless of what the instrumented rebuild eventually reveals about the `OnInit` rejection
itself — MT5 tolerates unknown `.set` keys, so this alone was very unlikely to be the sole cause,
but the set file could not be trusted as "current card defaults" until fixed, per the
predecessor's own finding.

## What this cycle did NOT do, and why (no blind requeue)

The acceptance criterion also asks for "one governed smoke each" and a fix-or-RETIRE terminal
disposition per pair. That was **not** completed this cycle, deliberately:

1. **No `run_smoke` reproduction was attempted.** The infra constraint the predecessor documented
   is unchanged: this session is `SYSTEM`-identity headless
   (confirmed again this cycle: `whoami` → `SYSTEM`, `%COMPUTERNAME%` →
   `WIN-B95G5LPSJ1O`); `run_smoke.ps1 -Terminal DEV1/DEV2` hard-requires the `QMDev1`/`QMDev2`
   Windows identity; `T11`/`T12` carry no privatized `Bases\Custom` data for these Custom-history
   symbols; and a live T1–T10 slot's `reserve-terminal` bookkeeping is not actually consulted by
   the automated claim/dispatch loop, so a manual `run_smoke` there could race a worker's own
   `terminal64.exe` — a direct violation of "do not interrupt active T1-T10 backtests."
2. **No `COMPILE_EA` work item was enqueued.** `farmctl.py compile-status` confirms both EAs are
   currently `NOT_ENQUEUED` (no stale predecessor to supersede), so a plain
   `enqueue-compile QM5_12582_chan-ng-spring QM5_10505_mql5-macd-sar` would very likely succeed
   mechanically. It was not run this cycle for two concrete reasons: (a) `compile_work_items.py`'s
   `--source-repair-authority` path is wired through per-incident hardcoded registration
   dictionaries (`STALE_INCLUDE_CLOSURE_REGISTRATIONS`, `BACKLOG_SOURCE_REPAIR_REGISTRATIONS`,
   compile-fail-repair authority tables, etc.) rather than accepting an arbitrary new authority —
   wiring a new registration correctly is a repo-code change with its own correctness surface,
   not something to do uncompiled/unverified in the same pass as the framework edit; (b) this
   session has no local way to invoke MetaEditor to confirm the two-file edit actually compiles
   before asking the factory to build it — the compiled result must go through the governed async
   pipeline regardless, and dispatching untested framework-header syntax into that pipeline is a
   worse failure mode than deferring the dispatch by one cycle.
3. **Never requeued anything blind; never touched a verdict.** The four existing stranded rows
   (`ae468d0f`, `cc347183`, `89875e78`, `446e60ca`) are untouched.

## Recommended next step (concrete, for the Codex build lane)

1. `python tools/strategy_farm/farmctl.py enqueue-compile QM5_12582_chan-ng-spring QM5_10505_mql5-macd-sar`
   (plain form — no stale predecessor exists for either, so no `--source-repair-authority` /
   `--repair-successor-of` flag should be required; verify with `compile-status` first at exec
   time in case the async router state has moved).
2. On `COMPILE_OK`, dispatch exactly one exact-successor Q02 attempt per pair on a real T1–T10
   slot through the normal factory claim path (`enqueue-backtest --append-only-rerun-of
   ae468d0f-2d3c-4595-9d49-6b5b00a25f75` for QM5_12582/XNGUSD, and the equivalent for
   `cc347183-5365-427e-b815-3879639c0d42` for QM5_10505/XAUUSD, both now carrying the corrected
   setfile) to capture the `FRAMEWORK_INIT_FAILED` reason before the 2h log purge.
3. Separately, for QM5_10369: since the failure is a tester-side `.set`/`.ex5` binder rejection,
   the productive next step is comparing the compiled `.ex5`'s actual input signature (order,
   type, count) against the current `.mq5` and `.set` — a MetaEditor/build-tooling task, not a
   source-logging one. File as its own ticket rather than folding into this repair.
4. Structural gap flagged again (unchanged from predecessor): `farmctl reserve-terminal` /
   `release-terminal` is bookkeeping only — `terminal_reservation()` is never read by the
   automated claim loop in `farmctl.py`. Any future bounded manual diagnostic on a live factory
   terminal needs that closed first.

## Evidence

- `source_repair_authority.json` (this directory) — file hashes, exact repair summary, scope.
- `docs/ops/evidence/2026-09-19_q02_stranded_pairs/` — predecessor task's per-pair root-cause
  detail, unchanged, still authoritative for the parts this cycle did not touch.
- Diff: `framework/include/QM/QM_Common.mqh`, `framework/include/QM/QM_RuntimeExecutionContract.mqh`,
  `framework/EAs/QM5_10505_mql5-macd-sar/sets/QM5_10505_mql5-macd-sar_XAUUSD.DWX_H1_backtest.set`.
