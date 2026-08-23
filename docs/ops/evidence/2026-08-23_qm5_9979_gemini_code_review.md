# QM5_9979 Gemini build — mandatory review

Date: 2026-08-23 UTC

Router task: `84776da8-b769-4828-8fed-ceb8f9c5b101` (`task_type=review_ea`, priority 51)

Source task: `a0768e09-7427-4ebe-87c1-19b4b17c9de1` (`gemini`/`agy`, build delivery only)

Reviewed artifact: `artifacts/qm5_9979_build_result.json`

The router-requested `gemini-output-review` skill is not installed in this session
(`code-review` is); reviewed directly against the approved card, SPEC, and repository
checks, matching the fallback pattern used for prior Gemini-build reviews (e.g.
`docs/ops/evidence/2026-08-23_qm5_9911_gemini_code_review.md`).

Verdict: **REQUEST_CHANGES — symbol universe exceeds the approved card scope and the
anti-cluster guard is not restart-safe; do not promote to PIPELINE**

## Findings

### 1. Medium — delivered cohort trades 8 symbols the card explicitly excludes by design

The card (`framework/EAs/QM5_9979_bandy-index-gap-fade-mr-index/docs/strategy_card.md`,
"Target Symbols" + "Zusätzliche Filter") authorizes exactly `SP500.DWX` (backtest-only),
`NDX.DWX`, `WS30.DWX` — three index symbols — and states the exclusion is deliberate:
*"FX overnight gaps are too small (overnight FX is liquid) to clear the 0.5×ATR threshold;
this card is index-specific by design."* The delivered build registers 13 symbols
(`framework/registry/magic_numbers.csv` rows for `ea_id=9979`): the 3 authorized index
symbols plus `GDAXI.DWX`, `UK100.DWX`, `XAUUSD.DWX`, and all 7 FX majors (`EURUSD`,
`GBPUSD`, `USDJPY`, `USDCHF`, `AUDUSD`, `USDCAD`, `NZDUSD`). This is the same defect class
flagged High in the `QM5_9911` review (cohort exceeds card-approved `target_symbols`); here
the delivered cohort doesn't just add adjacent instruments, it adds the exact asset class
(FX) the card's own author argues the edge does not exist on.

This is not unique to this EA: the mirror sibling `QM5_9965_bandy-index-gap-and-go-continuation`
carries the **identical** 13-symbol set, so this looks like a batch-level universe template
applied uniformly rather than a per-card decision — worth a batch-level fix rather than a
one-off patch, but each of the 10 non-index symbols still burns Q02-Q10 backtest capacity
against a thesis the card explicitly disclaims for that asset class.

Required correction: either (a) restrict the registered/setfile universe to
`SP500.DWX`/`NDX.DWX`/`WS30.DWX` per the card, or (b) obtain an explicit OWNER-approved
`target_symbols` amendment to the card broadening the universe before backtesting the
other 10 symbols.

### 2. Medium — anti-cluster window is not restart-safe, contradicting an explicit build note

The card's "Build-EA Notes" states: *"Anti-cluster state must persist across restarts
(track last entry timestamp per direction)."* The implementation
(`QM5_9979_bandy-index-gap-fade-mr-index.mq5:59-60,118-123,143-148`) holds
`g_last_long_entry_bar_time` / `g_last_short_entry_bar_time` as plain in-memory `datetime`
globals with no `GlobalVariableSet`/file persistence. A terminal or EA restart within the
`strategy_anti_cluster_bars` (2 D1 bars) window after an entry silently resets this guard,
allowing a same-direction re-entry the card's anti-cluster rule was meant to block. Same
gap in the sibling `QM5_9965` (identical globals, identical pattern) — again a shared,
not EA-specific, defect. Low real-world frequency (needs a restart within a ~2-day window
right after an entry) but it is a direct, reproducible violation of an explicit written
requirement, not a judgment call.

Required correction: persist last-entry-bar-time per direction (e.g.
`GlobalVariableSet`/`GlobalVariableGet` keyed by magic+direction) so the anti-cluster guard
survives a restart.

## Checks that passed

- Approved card exists (`g0_status: APPROVED`) with PASS on all four R1-R4 criteria; one
  active registry identity for `9979/bandy-index-gap-fade-mr-index`.
- Gap/ATR/regime shift convention (`bar1`=shift 1 gap bar, `bar2`=shift 2 pre-gap bar,
  `ATR(14)` at shift 2 to exclude the gap bar's own true range) is internally consistent
  and **matches the already-built mirror sibling `QM5_9965`** exactly, including its
  explicit "to avoid look-ahead bias" comment — this is the established, working pattern
  for this EA family, not a bug, despite the strategy card's own build note describing a
  differently-indexed (`shift=1`) mental model written before implementation.
- Gap-fill exit target (`Strategy_ExitSignal`) recomputes `iClose(D1, entry_bar_shift+2)`
  from the immutable historical bar via `iBarShift(opened)` rather than caching a price in
  a variable — this is restart-safe by construction (no persistence gap here, unlike
  finding #2) and correctly resolves to the same historical close as at entry time.
  Verified by hand-tracing the shift arithmetic at entry time (shift 0/1/2) and at a later
  exit check (shift N/N+1/N+2 with `entry_bar_shift=N`).
- Fade confirmation, gap-significance gate, and regime filter are all evaluated once per
  closed D1 bar (`QM_IsNewBar()` gate in `OnTick`), not intra-bar.
- One-position-per-magic enforced (`QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0` early
  return in `Strategy_EntrySignal`); no pyramiding, no martingale, no ML entry point.
- `QM_FrameworkTrackOpenPositionMae()` is the first statement in `OnTick()` (current MAE-hook
  contract satisfied).
- `ZeroMemory(req)` on the `QM_EntryRequest` before `Strategy_EntrySignal` (current
  hardening contract satisfied).
- All 13 setfiles use `RISK_FIXED=1000` / `RISK_PERCENT=0` (Q02-Q10 backtest risk-mode rule).
- `validate_build_guardrails.py` → `PASS`, 14 files checked, zero findings,
  `max_news_stale_hours=336`.
- `validate_symbol_scope.py --ea-label ... --fail-on-leak` → `SINGLE_SYMBOL_OK`,
  `n_violations=0` (no cross-symbol leakage; this check is orthogonal to finding #1, which
  is about card-scope, not symbol isolation).
- `build_gate_hardening.py` → zero failures for this EA.
- Compile log (`framework/build/compile/20260823_084541/...compile.log`): `0 errors,
  0 warnings`.
- MQ5 SHA-256 matches the build artifact:
  `4d873d6705b19bbf7621ab2a4dba3cd35d5e27cc5f812b315e03bd7de0c4360c`.
- EX5 SHA-256 matches the build artifact:
  `ae0354af71cc647b56e3b482ccba4bf57f9390ec76c1bfd0dcff5421a0490fbf`.
- Resolver contains the EA's rows (`grep -c 9979 QM_MagicResolver.mqh` → 2, i.e. the ea_id
  and magic array lines both carry the 13 rows for this EA).

These passes establish file identity, mechanical consistency with the reviewed sibling, and
guardrail compliance. No pipeline (Q02+) verdict is inferred from a code review.

## Disposition

No source, binary, registry, setfile, work item, task verdict, or trade stream was changed
by this review. `T_Live` and AutoTrading were not touched. Per hard rule ("Codex review is
mandatory before acceptance; leave Gemini code tasks in REVIEW and do not self-approve or
move them to PIPELINE"), this review task is closed with `REQUEST_CHANGES`, not `APPROVED`
— findings #1 and #2 require either a source/setfile correction or an explicit OWNER-approved
scope amendment before this build proceeds to Q02. Both findings also apply verbatim to the
sibling `QM5_9965_bandy-index-gap-and-go-continuation`, which has not yet had a full review
(only a Gemini build-draft note on file) — worth checking together.
