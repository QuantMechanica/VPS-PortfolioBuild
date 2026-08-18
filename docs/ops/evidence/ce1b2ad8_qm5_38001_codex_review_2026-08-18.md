# QM5_38001 Codex review evidence — 2026-08-18

- Review task: `ce1b2ad8-e99a-49b3-96d1-581726dc3bdf`
- Source build task: `33322516-1797-4d97-8a74-eb4fd7385953` (Gemini)
- EA: `QM5_38001_codetrading-vwap-bollinger-rsi-scalper`
- Disposition: `FAIL_CODE_REVIEW`; remain in `REVIEW`

## Verification

- Repository branch: `agents/board-advisor`
- Mechanical pre-screen: PASS (artifacts, freshness, three active magic rows, setfiles, fixed-risk mode, input wiring)
- `validate_build_guardrails.py`: PASS, four files checked, no findings, maximum news staleness 336 hours
- Fresh compile through `compile_ea.py --force`: PASS, 0 errors, 0 warnings
- Backtest sets: `RISK_FIXED > 0`, `RISK_PERCENT=0`, and symbol slots match the registry
- Card-to-code review: FAIL

## Blocking findings

1. `Strategy_NoTradeFilter()` rejects when this magic already has one open position (MQ5 line 147), while `OnTick()` returns on that filter at line 315 before calling `Strategy_ManageOpenPosition()` at line 318. The card-required +1R break-even management cannot execute while a position exists; any later strategy exit is unreachable for the same reason.
2. `OnTick()` evaluates the ATR-dependent spread filter before the new-bar state refresh. At startup `g_last_atr` is zero, so line 315 does not enforce the approved spread ceiling; state is populated at line 345 and entry follows without re-running admission. The first eligible signal can bypass the current-spread rule.
3. The card defines cumulative intraday/session VWAP. `StrategyResetVwap()` zeroes the accumulator (MQ5 line 88), and `AdvanceState_OnNewBar()` adds only each bar observed after initialization (lines 96-114). There is no initialization/backfill of earlier bars in the current session. When the EA is attached or restarted mid-session, its entry and TP reference is therefore a partial post-attach VWAP, not the card-defined session VWAP.

## Required repair

- Separate entry admission from open-position management so management and exits remain reachable.
- Refresh closed-bar state before ATR-dependent admission and recheck current spread immediately before entry.
- Deterministically reconstruct the current session VWAP from the session boundary on initialization/day rollover, using the governed broker/session time basis.
- Recompile and regenerate bound evidence; a later Codex review remains mandatory.

No pipeline verdict is inferred. No Q phase was started, no terminal was launched, and AutoTrading/T_Live were not enabled.
