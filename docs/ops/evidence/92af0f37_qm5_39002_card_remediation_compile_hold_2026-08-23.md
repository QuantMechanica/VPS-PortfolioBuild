# QM5_39002 card remediation and governed compile hold

- Task: `92af0f37-cfdf-41b4-b187-0fd19f00b722`
- EA: `QM5_39002_forexfactory-sonic-r-system`
- Strategy Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_39002_forexfactory-sonic-r-system.md`
- Branch: `agents/board-advisor`
- Source commit: `e56c2c8b9`
- Source SHA-256: `2c8c9129030e1001bd3d97bb956358c4ec7f925db0b50b951c756471687f275b`
- Disposition: static remediation complete; compile evidence unavailable because both sanctioned compile paths failed closed.

## Remediation

The existing implementation was not accepted unchanged. The current source:

1. implements the approved closed-bar Dragon(34 High/Low) and TrendWave(89 Close) entry predicates on M15;
2. uses the exact outer Dragon edge plus/minus 3-pip stop and exact 2.5R target, rejecting invalid stop geometry instead of substituting an ATR-clamped distance;
3. reconstructs original +1R from the untouched broker-side SL and moves to exact break-even, including after restart, without depending on volatile cached ATR;
4. initializes closed-bar state on startup, refreshes it before admission on each M15 bar, and manages open exposure on every tick before entry-only rollover, spread, daily-loss, and news filters;
5. converts the card's 23:55–00:05 GMT rollover window from broker time to UTC and fails closed when ATR/spread inputs are unavailable;
6. wires a maximum three-trade-tick deviation, the 2.0% realized daily entry halt, 2.5% daily hard stop, 5.0% total drawdown stop, and 0.5% per-trade risk cap;
7. updates `SPEC.md` and all three M15 backtest sets. Each set remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and is bound to the source hash above.

## Focused verification

| Check | Result |
|---|---|
| `python tools/strategy_farm/build_gate_hardening.py --repo-root C:/QM/repo --ea-label QM5_39002_forexfactory-sonic-r-system` | PASS; zero failures and warnings, including D2/D4/D5/D7/D8/D9/D10/D17 |
| `python tools/strategy_farm/validate_build_guardrails.py <mq5> <sets-dir>` | PASS for the MQ5 and all three sets; news staleness ceiling remains 336 hours |
| `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_39002_forexfactory-sonic-r-system` | PASS (`1 PASS, 0 FAIL`) |
| Source/set identity audit | PASS; all three `build_hash` values exactly equal `2c8c9129...f275b` |
| Backtest risk audit | PASS; every set has `RISK_FIXED=1000` and `RISK_PERCENT=0` |
| Registry audit | PASS; EA ID 39002 and active magic slots 0–2 already exist for EURUSD.DWX, GBPUSD.DWX, and USDJPY.DWX |
| `git diff --check` on the EA directory | PASS |

## Compile hold

The obsolete EX5 dated 2026-08-18 was removed so it cannot be mistaken for a binary built from the remediated source. It remains recoverable from Git.

Strict `framework/scripts/build_check.ps1` did not invoke MetaEditor. It failed closed with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because factory `terminal64` processes are alive. No terminal was started, stopped, or interrupted.

The required governed alternative was attempted:

```text
python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-compile QM5_39002_forexfactory-sonic-r-system
```

It refused with `BOUND_SETFILE_HASH_EXISTS`; `force_rebuild_authorized=false`. There is therefore no current EX5, strict compile-PASS JSON, smoke evidence, or pipeline verdict. Bypassing either guard requires authority absent from this task.

## Review verdict

`BLOCKED_COMPILE_AUTHORIZATION`: source, SPEC, and presets satisfy the focused card and static checks, but D6 build identity cannot be satisfied until the governed compiler accepts an OWNER-authorized force rebuild for the bound source hash.

No Q phase or backtest was run. AutoTrading and T_Live remained untouched.
