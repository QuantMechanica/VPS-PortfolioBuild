# Review — QM5_9720 Bandy ADX-Regime-Filter Trend (D1)

Date: 2026-08-24 UTC
Reviewer: Claude (review lane)
Router task: `41c5ecbf-caa4-4f3b-989c-1490a2b767f5` (review_ea, was REVIEW, assigned codex)
Source: `2dc0025a-7b2d-472c-ac65-58c806c5a768` (gemini build via agy)
Artifact: `D:/QM/strategy_farm/artifacts/builds/2dc0025a-7b2d-472c-ac65-58c806c5a768.json`
Source hash reviewed: mq5 SHA-256 `0a432e165805faa1f08eed7e775d3ac0ca16a0429729ac29075b27bbf56d9d3d`
(current working-tree hash matches artifact — review is against the delivered source)

## Verdict: RECYCLE — named actionable defects; not clean for Q02

A prior Codex-authored review (`docs/ops/evidence/2026-08-23_qm5_9720_gemini_code_review.md`)
reached REQUEST_CHANGES. This independent Claude-lane review confirms the load-bearing
defects by re-running the cited validators and re-reading the source, and closes the task
RECYCLE.

## Confirmed defects (must fix before re-review)

1. **SPEC structurally incomplete (validator FAIL).**
   `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_9720_bandy-adx-regime-filter-trend`
   → `0 PASS, 1 FAIL`, missing required sections: `## 3. Symbol Universe`,
   `## 4. Timeframe`, `## 5. Expected Behaviour`, `## 6. Source Citation`,
   `## 7. Risk Model`. `SPEC.md` stops after parameters.

2. **Symbol universe exceeds card authority; oil omitted.**
   Card `docs/strategy_card.md` primary set (lines "Target Symbols"): EURUSD, GBPUSD,
   USDJPY, AUDUSD, XAUUSD, NDX.DWX, WS30.DWX, XTIUSD; optional SP500.DWX.
   Delivered 13 setfiles / magic rows add unauthorized **GDAXI, UK100, USDCAD, USDCHF,
   NZDUSD** and omit **XTIUSD**. Per-setfile `validate_symbol_scope.py --fail-on-leak`
   returning SINGLE_SYMBOL_OK is a leak check, not card authorization — it does not
   expand card scope. Package only approved symbols (incl. XTIUSD) or obtain a card
   amendment.

3. **Exit paths unreachable when cached state is invalid (correctness gap).**
   `OnTick` (mq5) calls `AdvanceState_OnNewBar()` then `if(Strategy_NoTradeFilter()) return;`
   *before* `Strategy_ManageOpenPosition()` / `Strategy_ExitSignal()`.
   `Strategy_NoTradeFilter()` returns true whenever `!g_state_valid` (transient
   history/indicator invalidity) or on bad params/timeframe. That early return skips the
   card's 60-day hard time stop, the ATR ratchet, and the opposite-cross reverse-exit for
   an already-open position. Entry ineligibility must not suppress mandatory exits: keep
   management/exit reachable for open positions; apply transient filters to new entries only.

## Lower-severity / consistency

4. D1 execution contract not declared: `OnInit()` never calls
   `QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)` (available in
   `framework/include/QM/QM_Common.mqh:474`, used by newer EAs). Only a late
   `_Period != PERIOD_D1` check in `Strategy_NoTradeFilter()` guards timeframe. Not
   universally enforced across the fleet, but the D1-only card warrants a fail-closed
   contract at init.
5. Producer artifact is not a canonical build result (omits `compile_succeeded`, `ea_dir`,
   `magic_base`, `symbols_registered`, `smoke_result`/`smoke_report_path`). Matching
   hashes establish file identity only.

## Checks that passed (do not re-litigate)

- All 7 declared strategy inputs have use-sites beyond declaration (grep counts 2-6 each):
  no dead input.
- Card-faithful mechanism materially implemented for valid state: SMA(20)/SMA(50) cross,
  ADX(14) >= 25 gate, 2.5x ATR(14) ratchet trail, 60-day time stop, one-position-per-magic,
  close-before-reverse.
- Framework chain present: `QM_FrameworkInit`, `QM_FrameworkTrackOpenPositionMae()` first in
  OnTick (MAE hook), `QM_FrameworkHandleFridayClose`, `QM_KillSwitchCheck`, news wired via
  `QM_NewsAllowsTrade2`, magic via `QM_FrameworkMagic()` (ea_id*10000+slot resolver).
- Bounded indicator access via `QM_SMA/QM_ADX/QM_ATR` helpers; no raw handles/CopyBuffer/
  OrderSend/Sleep; no ML; no invented commission/swap.
- Setfiles `RISK_FIXED=1000 > 0`, `RISK_PERCENT=0` (backtest-correct).
- Prior guardrail/hardening validators PASS per Codex review.

## Disposition

Read-only review. No source, binary, registry, setfile, work item, or trade stream
changed. T_Live/AutoTrading untouched. Corrected code + complete SPEC + card-scoped
setfiles require a fresh build and mandatory review before enqueue.
