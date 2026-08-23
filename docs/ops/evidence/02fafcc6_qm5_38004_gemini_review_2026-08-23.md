# QM5_38004 mandatory Codex review — 2026-08-23

- Review task: `02fafcc6-df34-46b4-b195-7324f635e420`
- Gemini build task: `952a07fb-63c7-4fc3-9582-83096a13c9e0`
- EA: `QM5_38004_codetrading-triple-ema-momentum-scalper`
- Build summary: `artifacts/qm5_38004_build_result.json`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_38004_codetrading-triple-ema-momentum-scalper.md`
- Reviewed MQ5 SHA-256: `08ab42f3790df9a0d519a75987f937874ca9f6158501f0c9f0c744cf7498641e`
- Reviewed EX5 SHA-256: `eb1da058b0b708e897bb2de639a5bd50e1cc4e2bbc46be70699d4b51fb4f2e22`
- Disposition: `CHANGES_REQUIRED`; leave in `REVIEW`, with no pipeline promotion.

## Mechanical verification

- The current MQ5 and EX5 hashes equal the values written in the Gemini summary, and `_build_review_dispatch_gate(...)` returns `BUILD_REVIEW_DISPATCH_PASS`.
- That structural gate is not compile provenance. The MQ5 was modified at 2026-08-23 12:50 UTC by commit `6fdb5b310`, while the retained EX5 is dated 2026-08-18 16:09 UTC. A search of the farm/repository artifacts found the current MQ5 hash only in the summary itself, not in a strict compiler result. The summary claims `compile_succeeded=true` and `smoke_result=passed`, but `smoke_report_path` is null. The executable is therefore not evidence-bound to the reviewed source.
- `validate_build_guardrails.py` passes for the MQ5 and all three setfiles. News staleness is 336 hours; every setfile uses `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- `validate_spec_doc.py` passes (`1 PASS, 0 FAIL`). Registry/setfile symbols are NDX.DWX, WS30.DWX, and GDAXI.DWX.
- Fresh `build_gate_hardening.py` reports four failures: the card's 2.0% daily entry halt, 2.5% daily hard stop, and 5.0% total drawdown stop are absent, and raw broker time is used for a GMT window.

A structurally reviewable packet and static guardrail pass are necessary but not sufficient. Card-to-code review fails.

## Blocking findings

1. **The reviewed executable is stale or otherwise unproven.** The EX5 predates the post-fix MQ5 by five days, and there is no strict compile record binding the current source hash to that binary. A hash list inside the same summary and an unevidenced smoke claim cannot establish build identity.

2. **The card's capital-preservation controls are absent.** The canonical hardening check fails all three declared controls: 2.0% realized-daily entry halt, 2.5% daily hard stop, and 5.0% total drawdown stop. The source also does not wire the card's 0.50% per-trade cap or its maximum three-tick order deviation.

3. **The GMT rollover contract uses broker time.** `StrategyInRolloverWindow(TimeCurrent())` at MQ5 line 114 has no `QM_BrokerToUTC` conversion, so 23:55–00:05 is broker-local rather than GMT.

4. **The first eligible bar can bypass the spread ceiling, and entry-only filters suppress management.** `Strategy_NoTradeFilter()` runs at line 303 before `AdvanceState_OnNewBar()` at line 333. At startup `g_last_atr` is zero, so the spread test at line 122 is skipped and entry can follow after state is populated without rechecking admission. The same filter returns before `Strategy_ManageOpenPosition()` at line 306, so rollover or a wide spread suppresses the approved EMA trail on an existing position. `OnInit()` does not seed EMA/ATR state, so restart management is also unavailable until a chart-new-bar event.

5. **The stop mechanic silently falls back to a different strategy.** The card requires the stop beyond EMA(55) by 2 pips. When that stop is invalid relative to the next entry quote, lines 165/176 substitute 1.5×ATR rather than rejecting the entry. The trailing trigger then derives R from the mutable current SL and falls back to 1.5×ATR after protection, so it does not preserve the entry's original R definition across the lifecycle.

## Required repair

- Implement and wire the card's 2.0%/2.5%/5.0% loss controls, 0.50% per-trade cap, and three-tick deviation ceiling.
- Convert the rollover window to UTC, initialize restart-safe closed-bar state, and keep active management ahead of entry-only rollover/spread admission.
- Keep the exact EMA(55) ±2-pip stop contract; reject invalid geometry instead of substituting ATR, and preserve original risk deterministically for the +1R trail.
- Recompile through the governed compiler and provide strict hash-bound compile/smoke evidence for the current MQ5 before another mandatory Codex review.

No source was changed in this review. No Q phase, pipeline verdict, terminal launch, AutoTrading action, or T_Live action occurred.
