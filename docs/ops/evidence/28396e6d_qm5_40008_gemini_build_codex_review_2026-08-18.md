# Codex review: QM5_40008 Gemini build

- Review task: `28396e6d-be0b-4685-89df-749b9fe622f8`
- Gemini source task: `3e8438fe-884f-4337-974d-7c8c2a1dd459`
- Source artifact: `docs/ops/evidence/3e8438fe_qm5_40008_build_ea_result_2026-08-18.md`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_40008_aqr-value-and-momentum-everywhere.md`
- Reviewed tree HEAD: `f6afb7aedb3758972447af14f5ea8dae2afc7890`
- Source build commit: `139ece403`
- MQ5 SHA-256: `51c422d1d2ea24c39e9dccedb97f0513c998621cdfd3f7b2f3334535236f35c5`
- Fresh EX5 SHA-256: `1e1cbe5582c9f2b3cf523e0c9350ca44cd5762dbf87424797326c5f63db2b66f`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused checks directly.

## Findings

### 1. Critical: the approved cross-asset ranks are not implemented

The card defines `CombinedScore = 0.50 * Rank(M) + 0.50 * Rank(V)` for a
multi-asset engine (card lines 61 and 76-77). `CalculateCombinedScore` instead
reads only the chart symbol and maps its raw momentum and value z-score through
two arbitrary sigmoid functions (source lines 79-118), including an
undocumented `mom_ret * 5.0` scale. Separate single-symbol tester runs therefore
cannot produce either cross-sectional rank. The implemented entry signal is a
different model, not a mechanical realization of the approved formula.

### 2. Critical: fixed 2R and invented decay exits replace quarterly rebalance

The approved lifecycle specifies a 2.5 ATR hard stop and quarterly dynamic
factor rebalancing, not a fixed price target (card lines 96-99). Source lines
171-177 and 195-201 attach a 2R broker TP to every entry. Source lines 256-276
also add undocumented score-decay thresholds `0.40/0.60` plus SMA-cross exits.
These changes materially alter holding period, payoff distribution, and the
strategy being tested.

### 3. High: the five-year value requirement silently degrades

The card requires a 1,260-day mean and standard deviation. Source lines 91-114
use however many bars are available down to 100; below 100 they return the
momentum score alone. The same configured strategy can therefore mean a
five-year value model, a short-history proxy, or a momentum-only model without
failing closed or recording which mechanic ran.

### 4. High: the approved loss-limit contract is absent

The card requires a 2.0% daily realized-loss entry halt, a 2.5% daily hard
stop, and a 5.0% total-drawdown stop (card lines 87 and 110-113). The EA
implements none. Its generic framework initialization uses 3.0% daily and 0.0%
portfolio drawdown (`QM_Common.mqh` line 298), so the approved FTMO-oriented
capital-preservation contract is not enforced.

### 5. High: the strict framework build gate fails

The fresh strict check reports six `EA_FRAMEWORK_RAW_SERIES_CALL` failures at
source lines 81, 82, 98, 105, 152, and 261. The producer's blanket build-pass
claim is not reproducible against the current canonical framework gate.

### 6. High: the 1,260-bar factor scan runs on every tick

`OnTick` calls `Strategy_ExitSignal` before the new-bar gate (source lines
339-364). That calls `CalculateCombinedScore`, whose two loops perform up to
2,520 raw `iClose` reads. Repeating a five-year D1 scan for every market tick is
a deterministic backtest-timeout risk and violates the closed-bar evaluation
design; compute/cache it only on a new D1 bar.

## Independent verification

- Fresh compile: PASS, 0 errors / 0 warnings; EX5 size 396,288 bytes; log
  `C:/QM/repo/framework/build/compile/20260818_171017/QM5_40008_aqr-value-and-momentum-everywhere.compile.log`.
- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: FAIL, six failures and zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_171049.json`.
- Four active magic rows are collision-free and all four values are present in
  the generated resolver.
- All four backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- The approved-card copy in Git matches the canonical approved card byte for
  byte (SHA-256 `ecbb03f6cbeff3ec46f66097648f4023d535d7951de9a3085a4be6dcfa33c99e`).
- Focused forbidden scan found no direct indicator handles, `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, or ML calls.
- The producer supplied no smoke summary. No runtime or pipeline verdict is
  inferred, and no active tester was interrupted.

Fresh compilation regenerated only the tracked EX5 and refreshed setfile
`build_hash` comments. No Gemini MQ5 source, registry, resolver, work item,
terminal, AutoTrading, or pipeline state was changed.
