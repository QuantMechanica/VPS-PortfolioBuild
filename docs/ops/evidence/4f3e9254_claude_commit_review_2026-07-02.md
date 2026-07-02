# Claude Commit Review - QM5_12821 / Basket Timeout Chain

Task: `4f3e9254-cd8e-45f4-a908-1e2a61c2f69f`  
Reviewed commits: `dc418a720`, `ec6b8ded7`, `6260606f8`  
Reviewer: Codex  
Date: 2026-07-02

## Verdict

No blocking findings found in the reviewed changes. Leave in REVIEW for normal owner/close-review handling; do not self-promote to PIPELINE.

## Review Notes

- `QM5_12821_twin-csm-basket.mq5:182` centralizes close/cancel in `QM12821_CloseAllOwned()`, closing owned positions through the basket equity-stop helper and then canceling owned pending orders. The post-equity-stop call at `:445` is not a double-close hazard for the original closed positions; its added value is pending-order cleanup.
- `QM5_12821_twin-csm-basket.mq5:407` keeps `QM12821_CheckBasketRisk()` as the management path, with kill-switch cycle-stop latching at `:439-440` and next-D1 re-arm at `:509-510`. This matches the card behavior that a 1% stop ends the current cycle, not the entire backtest.
- `QM5_12821_twin-csm-basket.mq5:573-575` still routes active-position management through `Strategy_ManageOpenPosition()`.
- `QM5_12821_twin-csm-basket.mq5:583-586` has `Strategy_NewsFilterHook()` as a no-op, so the top-of-tick framework hook does not block risk management. The effective blackout gate is below management at `:667-672`, preserving fail-closed init while gating new entries only.
- `farmctl.py:2022-2052` keeps single-symbol Q02 full-run timeout at the existing 7200s floor and caps single-symbol prescreen-derived estimates at 14400s. Basket payloads get the member-count floor, e.g. 28 symbols -> 18600s.
- `farmctl.py:3460-3478` wires the Q02 basket outer active-timeout net to `BASKET_Q02_ACTIVE_TIMEOUT_MIN = 450`, and `_detect_active_age_timeout()` uses that helper at `farmctl.py:3407`.
- `run_smoke.ps1:27-28` now accepts `TimeoutSeconds` up to 28800 and passes it through to `Start-TesterRun` at `:1553`, so the 18600s basket timeout is no longer rejected by parameter validation.

## Focused Verification

- `python -m py_compile C:\QM\repo\tools\strategy_farm\farmctl.py` - PASS
- PowerShell parser check for `C:\QM\repo\framework\scripts\run_smoke.ps1` - PASS
- Timeout spot-check via imported `farmctl.py`:
  - single symbol: inner `7200`, outer `45`
  - 28-symbol basket: inner `18600`, outer `450`
  - 2-symbol basket: inner `7200`, outer `450`
- `python tools\strategy_farm\compile_ea.py --ea-label QM5_12821_twin-csm-basket --force --json --fail-on-error` - PASS
  - verdict `COMPILED`
  - errors `0`
  - warnings `0`
  - symbol scope `BASKET_OK`
  - compile log `C:\QM\repo\framework\build\compile\20260702_054250\QM5_12821_twin-csm-basket.compile.log`
- `python tools\strategy_farm\validate_build_guardrails.py framework\EAs\QM5_12821_twin-csm-basket` - PASS
  - files checked `30`
  - findings `[]`
  - `max_news_stale_hours` `336`
