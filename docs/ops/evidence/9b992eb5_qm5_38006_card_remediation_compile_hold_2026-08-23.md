# QM5_38006 card remediation and governed compile hold

- Task: `9b992eb5-9773-40ff-b4f3-ef03719e373e`
- EA: `QM5_38006_codetrading-doji-hammer-pivot-rejection`
- Strategy Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_38006_codetrading-doji-hammer-pivot-rejection.md`
- Prior Codex review: `docs/ops/evidence/67e670f0_qm5_38006_codex_review_2026-08-18.md`
- Branch: `agents/board-advisor`
- Source commit: `8d64f9c0d`
- Source SHA-256: `a9547dc1db07f7986353aebce3d18cdb68699322faf28a676924dfa0db1495ec`
- Disposition: static remediation complete; compile evidence unavailable because both sanctioned compile paths failed closed.

## Remediation

The prior implementation was not accepted unchanged. The current source:

1. refreshes H1 closed-bar EMA/ATR/pattern state before ATR-dependent entry admission and clears state first so an incomplete read cannot reuse an old signal;
2. evaluates open-position management on every tick before entry-only rollover, spread, daily-loss, and news filters;
3. derives +1R from the untouched original broker-side SL and moves the stop to the exact entry price; a missing/invalid SL fails closed instead of substituting current ATR;
4. removes the unauthorized ATR fallback for entry stops and retains the exact candle extreme plus/minus 2-pip structural stop and exact 1.8R take profit;
5. uses UTC for the card's GMT rollover window and the framework host-magic entry contract;
6. wires a three-trade-tick deviation ceiling, the 2.0% realized daily entry halt, 2.5% daily hard stop, 5.0% total drawdown stop, and 0.5% per-trade cap;
7. updates `SPEC.md` and all three H1 backtest sets. Each set remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and is bound to the source hash above.

## Focused verification

| Check | Result |
|---|---|
| `python tools/strategy_farm/build_gate_hardening.py --repo-root C:/QM/repo --ea-label QM5_38006_codetrading-doji-hammer-pivot-rejection` | PASS; zero failures and warnings, including D2/D4/D5/D7/D8/D9/D10/D17 |
| `python tools/strategy_farm/validate_build_guardrails.py <mq5> <sets-dir>` | PASS for the MQ5 and all three sets; news staleness ceiling remains 336 hours |
| `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_38006_codetrading-doji-hammer-pivot-rejection` | PASS (`1 PASS, 0 FAIL`) |
| Source/set identity audit | PASS; all three `build_hash` values exactly equal `a9547dc1...1495ec` |
| Backtest risk audit | PASS; every set has `RISK_FIXED=1000` and `RISK_PERCENT=0` |
| `git diff --check` on the EA directory | PASS |

## Compile hold

The obsolete EX5 (`SHA-256 7ccb980d5872606fa8a65c0ab4185adf5742bbfd57f20895884c49a4719071a8`) was removed so it cannot be mistaken for a binary built from the remediated source.

Strict `framework/scripts/build_check.ps1` did not invoke MetaEditor. It failed closed with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because factory `terminal64` processes are alive. No terminal was started, stopped, or interrupted.

The required governed alternative was attempted:

```text
python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-compile QM5_38006_codetrading-doji-hammer-pivot-rejection
```

It refused with `BOUND_SETFILE_HASH_EXISTS`; `force_rebuild_authorized=false`. There is therefore no current EX5, strict compile-PASS JSON, or pipeline verdict. Bypassing either guard requires authority absent from this task.

## Review verdict

`BLOCKED_COMPILE_AUTHORIZATION`: source/spec/presets satisfy the focused card and static checks, but D6 build identity cannot be satisfied until the governed compiler accepts an OWNER-authorized force rebuild for the bound source hash.
