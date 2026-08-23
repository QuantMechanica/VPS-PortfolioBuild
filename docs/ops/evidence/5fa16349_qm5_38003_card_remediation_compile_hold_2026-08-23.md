# QM5_38003 card remediation and governed compile hold

- Task: `5fa16349-5252-448a-8f5d-8a7d77306f9b`
- EA: `QM5_38003_codetrading-bollinger-engulfing-reversal`
- Strategy Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_38003_codetrading-bollinger-engulfing-reversal.md`
- Branch: `agents/board-advisor`
- Source commit: `0d4af0105`
- Source SHA-256: `1710662cd09f19cbbd27af4843bb67d5029197010b2a5ed0f53cb137ea69333d`
- Disposition: static remediation complete; compile evidence unavailable because both sanctioned compile paths failed closed.

## Card-conformance remediation

The prior implementation was not accepted unchanged. The remediation:

1. keeps trade management reachable on every tick, before entry-only rollover, spread, daily-loss, and news admission filters;
2. refreshes H1 ATR and signal state before evaluating the current new-bar entry admission;
3. implements the card's exact one-time 50% close at the 20-SMA Bollinger middle band instead of moving the whole position's stop near break-even;
4. reconstructs that one-time middle-band exit state from `DEAL_ENTRY_OUT`, `DEAL_ENTRY_OUT_BY`, or `DEAL_ENTRY_INOUT` history for the current `POSITION_IDENTIFIER`, and fails closed if history is unavailable;
5. rejects an entry when the risk-sized lot cannot split into two equal broker-valid half volumes, avoiding an approximate partial exit;
6. removes the unauthorized engulfing tolerance and ATR stop fallback, retaining the exact engulfing inequalities and engulfing-candle extreme plus/minus 2-pip stop;
7. preserves the exact 2R take profit, uses the framework host magic contract, converts the rollover window to UTC, caps market deviation at three trade ticks, and wires the 2.0% realized entry halt / 2.5% daily hard stop / 5.0% total stop / 0.5% per-trade cap;
8. updates `SPEC.md` and all three H1 backtest sets. Every set remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and is bound to the source SHA-256 above.

## Focused verification

| Check | Result |
|---|---|
| `python tools/strategy_farm/build_gate_hardening.py --repo-root C:/QM/repo --ea-label QM5_38003_codetrading-bollinger-engulfing-reversal` | PASS; zero failures and zero warnings, including D2/D4/D5/D7/D8/D9/D10/D17 |
| `python tools/strategy_farm/validate_build_guardrails.py <mq5> <sets-dir>` | PASS for the MQ5 and all three sets; `max_news_stale_hours=336` |
| `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_38003_codetrading-bollinger-engulfing-reversal` | PASS (`1 PASS, 0 FAIL`) |
| SHA-256 / preset identity audit | PASS; all three `build_hash` values exactly equal `1710662...69333d` |
| Backtest risk audit | PASS; every set has `RISK_FIXED=1000` and `RISK_PERCENT=0` |
| `git diff --check` on the EA directory | PASS |

## Compile hold

The obsolete EX5 (`SHA-256 5f4558db0a340cdb1b6969904b0665ee20b13d235279bf2b5d1ddc07e645ca38`) was removed so it cannot be mistaken for a binary built from the remediated source.

Strict `framework/scripts/build_check.ps1` did not invoke MetaEditor. It failed closed with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because factory `terminal64` processes are alive. No terminal was started, stopped, or interrupted.

The required governed alternative was attempted:

```text
python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-compile QM5_38003_codetrading-bollinger-engulfing-reversal
```

It refused with `BOUND_SETFILE_HASH_EXISTS`; `force_rebuild_authorized=false`. Therefore there is no current EX5, strict compile-PASS JSON, or pipeline verdict. Bypassing either guard would require authority not present in this task.

## Review verdict

`BLOCKED_COMPILE_AUTHORIZATION`: source/spec/presets are card-conformant under focused static review, but D6 build identity cannot be satisfied until the governed compiler accepts an OWNER-authorized force rebuild for the new bound hash.
