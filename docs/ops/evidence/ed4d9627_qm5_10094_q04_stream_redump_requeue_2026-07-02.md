# QM5_10094 Q04 stream mismatch requeue

Task: `ed4d9627-d91c-424e-8fc9-b0980a472f64`
EA: `QM5_10094_gh-h4-zone`
Date: 2026-07-02

## Verdict

REVIEW: the invalid Q04 aggregate was requeued/redumped against the current EA/framework build. The old aggregate had `native_report_guard_fallback` because the Q08 stream trade count was lower than the native tester report. The current EA has `OnTradeTransaction` wired to `QM_FrameworkOnTradeTransaction`, the EA was recompiled cleanly, guardrails pass, and the Q04 GDAXI work item is now active under the worker. No pipeline verdict is claimed here.

## Invalidated Evidence

Old aggregate:
`D:\QM\reports\work_items\a794c47f-2f99-4f5f-bb92-ab9eab94ed87\QM5_10094\Q04\GDAXI.DWX\aggregate.json`

Mismatch reasons:

- F1: `trade_count_mismatch:stream=87,report=93`
- F2: `trade_count_mismatch:stream=91,report=100`
- F3: `trade_count_mismatch:stream=104,report=110`

That forced `commission_basis=native_report_guard_fallback`, with gross and simulated commission totals null.

## Verification

- Source wiring: `OnTradeTransaction(...)` forwards to `QM_FrameworkOnTradeTransaction(...)`.
- Compile command: `python C:\QM\repo\tools\strategy_farm\compile_ea.py --ea-label QM5_10094_gh-h4-zone --force --json`
- Compile result: `COMPILED`, 0 errors, 0 warnings.
- EX5: `C:\QM\repo\framework\EAs\QM5_10094_gh-h4-zone\QM5_10094_gh-h4-zone.ex5`
- Compile log: `C:\QM\repo\framework\build\compile\20260702_060458\QM5_10094_gh-h4-zone.compile.log`
- Guardrail command: `python tools/strategy_farm/validate_build_guardrails.py C:\QM\repo\framework\EAs\QM5_10094_gh-h4-zone`
- Guardrail result: `PASS`, files_checked=15, findings=[], max_news_stale_hours=336.

## Queue State

`python tools/strategy_farm/farmctl.py work-items --ea QM5_10094` now shows target work item:

- Q04 GDAXI.DWX: `active`, claimed_by `T1`, verdict NULL, evidence_path NULL (`a794c47f-2f99-4f5f-bb92-ab9eab94ed87`)

Fresh worker evidence has started under:

- `D:\QM\reports\work_items\a794c47f-2f99-4f5f-bb92-ab9eab94ed87\QM5_10094\20260702_060412`
- `D:\QM\reports\work_items\a794c47f-2f99-4f5f-bb92-ab9eab94ed87\QM5_10094\20260702_060519`

The worker started the terminal; Codex did not start `terminal64.exe` manually and did not interrupt any active T1-T10 backtest. The final Q04 verdict must come from the worker aggregate after this active run completes.
