# Review — QM5_9909 bandy-lrchannel-breakout-trend (review_ea close)

Date: 2026-08-24 UTC
Reviewer: Claude (review lane)
Router task: `d6ea3abe-d44b-4861-b466-475a28899eaa` (task_type `review_ea`, assigned `codex`, source_agent `gemini`)
Source build task: `a944cf09-4a86-43b5-90b5-1d6fc5108ae6`
Reviewed EA: `framework/EAs/QM5_9909_bandy-lrchannel-breakout-trend/`
Card: `framework/EAs/QM5_9909_bandy-lrchannel-breakout-trend/docs/strategy_card.md`
Prior Codex review (uncloseD router task): `docs/ops/evidence/2026-08-23_qm5_9909_gemini_code_review.md` (REQUEST_CHANGES)

## Verdict: RECYCLE — named actionable defects; not clean for Q02.

Source hash unchanged since build: mq5 sha256 `3c5c7dd75f7501698280a3c89fcc8b26bcb4ff2012c09657b9fc7516c623d2fc` matches `build_identity.json` and every setfile `build_hash`.

## Defects (blocking Q02)

1. **Dead strategy input** `strategy_sl_atr_mult` — declared at `.mq5:42`, that is its ONLY occurrence in the file (grep count 1). Never read anywhere. Per review rule, a dead declared strategy input is an automatic RECYCLE.

2. **Card mechanism missing** — the card requires a two-layer stop: a 2.5×ATR Chandelier primary trail PLUS a separate `5.0 * ATR(14)` catastrophic backstop from entry (card "Stop Loss"). The EA sets only the trail-distance stop at entry (`.mq5:147`, `.mq5:164`, both via `strategy_trail_atr_mult`) and management maintains only the Chandelier (`.mq5:210`, `.mq5:218`). The catastrophic backstop — and the input meant to drive it (defect 1) — is absent. Fixed-risk sizing distance (2.5×ATR) is card-faithful; the separate catastrophic protection is not.

3. **Exit management suppressed by an entry-only gate** — `Strategy_NoTradeFilter()` runs at `.mq5:272` and returns BEFORE `Strategy_ManageOpenPosition()` at `.mq5:275`. On insufficient warmup (`.mq5:105`) or wide spread (`.mq5:114`, the invented `strategy_spread_max_atr`, not in card) the Chandelier ratchet and the 40-bar time stop never execute on an open position. Management/exit must run ahead of every entry-eligibility return.

4. **Universe expanded beyond card** — SPEC §3 and the 13 delivered setfiles add `GDAXI.DWX` and `UK100.DWX` and omit the card-authorized oil CFD. Card R3 authorizes FX majors, XAUUSD, oil CFD, NDX.DWX, WS30.DWX, and backtest-only SP500.DWX. Align cohort to card or obtain an OWNER `target_symbols` amendment.

5. **Producer evidence not schema-complete** — `build_identity.json` lacks `task_id`, `ea_id`, `ea_dir`, `magic_base`, `symbols_registered`, `compile_succeeded`, `smoke_result`/`smoke_report_path`. No smoke proof or sanctioned `deferred_p2_smoke` deferral.

## Checks that passed (independently confirmed)

- QM_Common chain included (`.mq5:5`); framework wiring complete: `QM_FrameworkInit` (`.mq5:244`), MAE hook `QM_FrameworkTrackOpenPositionMae` (`.mq5:260`), kill-switch (`.mq5:262`), Friday close (`.mq5:269`), `QM_FrameworkOnTradeTransaction` (`.mq5:324`).
- Magic via resolver `QM_FrameworkMagic()` (`.mq5:125`, `.mq5:177`); one-position-per-magic enforced (`.mq5:126`).
- News filter IS wired via framework `QM_NewsAllowsTrade2` (`.mq5:293-299`); the empty `Strategy_NewsFilterHook` (`.mq5:233`) is intentional deferral to the framework path.
- OLS math card-faithful: closed D1 bars oldest→newest (`.mq5:64-71`), correct closed-form slope/intercept (`.mq5:73-78`), centerline at newest closed bar (`.mq5:80`), sample residual sd with `N-1` (`.mq5:92`), symmetric ±sigma channel, no look-ahead (entry on `close[1]`).
- Bounded buffers only; no raw `CopyBuffer`/`OrderSend`, no `Sleep`, no ML.
- RISK_FIXED=1000 / RISK_PERCENT=0 defaults and in all 13 setfiles; setfiles carry governed-generator header + `build_hash` matching source.

Note: defect set matches the prior Codex review (REQUEST_CHANGES); that review never closed the router task. This close resolves the outstanding REVIEW row. REQUEST_CHANGES maps to RECYCLE (fixable, named defects) — not BLOCKED/FAILED.

## Disposition
Read-only review. No source, binary, registry, setfile, work item, trade stream, or T_Live state changed. Router task closed RECYCLE.
