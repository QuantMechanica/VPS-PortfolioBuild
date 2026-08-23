# QM5_20089 Build Evidence — Recovery Package Completed, Governed Compile Held

- Task: `d00ea063-eb22-41c0-85f3-f793f11a3978` (`build_ea`, priority 50, assigned to Codex)
- EA: `QM5_20089_hopwood-ts4-standalone-h4-r1-recovery`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_20089_hopwood-ts4-standalone-h4-r1-recovery.md`
- Current MQ5 SHA-256: `ff2e6831370c9ef53a49994f6085ab0c1d79b741ebfe22c97068f4a9fc18c7a6`
- Outcome: `SOURCE_READY_COMPILE_HELD`

## Governed identity

The approved recovery card declares EA ID `QM5_20089` and slug
`hopwood-ts4-standalone-h4-r1-recovery`; the active registry and folder match the
repaired identity. Eight active magic rows bind slots 0-7 to EURUSD.DWX,
GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, NDX.DWX, WS30.DWX, XAUUSD.DWX, and XTIUSD.DWX.

## Card and framework alignment

The source implements the approved H4 TS4 three-way consensus: DMI direction,
MACD-histogram sign, prior-20-bar channel breakout, and mandatory D1 EMA(200) slope.
It also implements the six-bar same-direction cooldown, 0.4-ATR range gate,
ATR-relative spread gate, 1.5-ATR initial stop, 2-ATR half exit, break-even-plus-
spread, PSAR trailing, stack-break exit, and 24-H4-bar time stop.

This task completed the missing package and current framework alignment:

- cached PSAR and fallback ATR once per closed H4 bar instead of reading indicators
  on the per-tick management path;
- constrained PSAR modifications to valid sides of current price;
- normalized the initial stop through `QM_StopATR`;
- added the current MAE hook, request zero-initialization, H4 chart guard, and input validation;
- moved the central news gate to entries only so management and exits remain active;
- generated all eight governed H4 backtest presets and the required seven-section spec;
- retained `qm_news_stale_max_hours=336`, `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  one position per magic, no ML/grid/martingale, and no live operation.

## Focused verification

- `validate_spec_doc.py`: PASS (1/1).
- `validate_build_guardrails.py`: PASS; 9 files checked, zero findings, stale-news ceiling 336 hours.
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`, zero violations.
- `gen_setfile.ps1`: PASS for all eight governed symbols.
- `git diff --check`: clean for the EA package.

## Compile boundary

Direct strict `build_check.ps1` stopped before compilation with
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because terminal64 factory processes are active.
No terminal was started, stopped, interrupted, or bypassed. The tracked EX5 was older
than the pre-task source and became further stale after framework hardening, so it was
removed instead of being represented as current-source evidence.

The sanctioned compile command accepted governed work item
`271b603f-3039-4435-9074-2853b23c7449`, bound to the eight active magic rows and H4
sets. Activation is held under `COMPILE_EA_WORKER_ROLLOUT_PENDING`; no current EX5 or
strict build PASS exists yet. Smoke was not run, and no pipeline verdict is claimed.

Short verdict: `SOURCE_READY_COMPILE_HELD: static gates PASS; governed compile 271b603f pending under worker-rollout activation hold.`
