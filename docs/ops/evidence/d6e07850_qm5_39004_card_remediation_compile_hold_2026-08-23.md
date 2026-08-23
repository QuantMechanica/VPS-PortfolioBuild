# QM5_39004 card remediation and governed compile hold

- Task: `d6e07850-a05d-4aa7-ad8b-5f7895fd2b36`
- EA: `QM5_39004_forexfactory-thv-cobra-trix-scalper`
- Strategy Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_39004_forexfactory-thv-cobra-trix-scalper.md`
- Branch: `agents/board-advisor`
- Source commit: `1ad3e817f`
- Source SHA-256: `94c163077bb645ea2b25a85901904f5c3304bad979d8374930c493b0313958ef`
- Disposition: static remediation complete; compile evidence unavailable because both sanctioned compile paths failed closed.

## Remediation

The existing implementation was not accepted unchanged. The current source:

1. computes closed-bar M5 Fast TRIX(9), Slow TRIX(18), and Coral SMMA(20) state with explicit fail-closed cache clearing;
2. implements the approved long/short predicates, the exact Coral ±2-pip stop, and exact 2R target; the prior pip-native `×10` bug and unauthorized 1.5×ATR stop substitution are removed;
3. reconstructs position direction from broker-side symbol/magic/type state, so the Fast-TRIX direction-change exit remains available after restart and does not depend on an entry-process memory variable;
4. seeds indicator state on initialization, refreshes it before exit/admission on each M5 bar, evaluates the active Trix exit before all entry-only filters, and prevents same-bar re-entry after an exit signal;
5. enforces the 1.8×ATR spread ceiling and converts the exact 23:55–00:05 GMT rollover window from broker time to UTC;
6. wires the maximum three-trade-tick deviation, 2.0% realized daily entry halt, 2.5% daily hard stop, 5.0% total drawdown stop, and 0.5% per-trade cap;
7. changes the source default to one valid risk mode (`RISK_FIXED=1000`, `RISK_PERCENT=0`) and updates `SPEC.md` plus all three M5 sets. Every set is bound to the source hash above.

## Focused verification

| Check | Result |
|---|---|
| `python tools/strategy_farm/build_gate_hardening.py --repo-root C:/QM/repo --ea-label QM5_39004_forexfactory-thv-cobra-trix-scalper` | PASS; zero failures and warnings, including D2/D3/D4/D5/D7/D8/D9/D10/D17 |
| `python tools/strategy_farm/validate_build_guardrails.py <mq5> <sets-dir>` | PASS for the MQ5 and all three sets; news staleness ceiling remains 336 hours |
| `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_39004_forexfactory-thv-cobra-trix-scalper` | PASS (`1 PASS, 0 FAIL`) |
| Source/set identity audit | PASS; all three `build_hash` values exactly equal `94c16307...958ef` |
| Backtest risk audit | PASS; every set has `RISK_FIXED=1000` and `RISK_PERCENT=0` |
| Registry audit | PASS; EA ID 39004 and active slots 0–2 exist for EURUSD.DWX, USDJPY.DWX, and GBPUSD.DWX |
| `git diff --check` on the EA directory | PASS |

## Compile hold

The obsolete EX5 dated 2026-08-18 was removed so it cannot be mistaken for a binary built from the remediated source. It remains recoverable from Git.

Strict `framework/scripts/build_check.ps1` did not invoke MetaEditor. It failed closed with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because factory `terminal64` processes are alive. No terminal was started, stopped, or interrupted.

The required governed alternative was attempted:

```text
python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-compile QM5_39004_forexfactory-thv-cobra-trix-scalper
```

It refused with `BOUND_SETFILE_HASH_EXISTS`; `force_rebuild_authorized=false`. There is therefore no current EX5, strict compile-PASS JSON, smoke evidence, or pipeline verdict. Bypassing either guard requires authority absent from this task.

## Review verdict

`BLOCKED_COMPILE_AUTHORIZATION`: source, SPEC, and presets satisfy the focused card and static checks, but D6 build identity cannot be satisfied until the governed compiler accepts an OWNER-authorized force rebuild for the bound source hash.

No Q phase or backtest was run. AutoTrading and T_Live remained untouched.
