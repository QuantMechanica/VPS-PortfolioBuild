# Codex review: QM5_41006 Gemini build

- Review task: `0249f85f-cd98-4374-998f-8e76a8ad1e48`
- Gemini source task: `b42bac52-ccda-4a73-b49b-faab46b48c88`
- Source artifact: `artifacts/builds/b42bac52-ccda-4a73-b49b-faab46b48c88.json`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_41006_man-ahl-multispeed-ewma-trend.md`
- Reviewed tree HEAD: `db498d0cc4814b24acf21ca469d44c7a5d973c44`
- Source build commit: `8269f225e`
- MQ5 SHA-256: `6f0d44bef1c3bbc1a9cf8f747b9f29c5efdd5f8faa6342ee03ac3ddc38adc72e`
- Fresh EX5 SHA-256: `a9accb29338de23d6e55bc9d9d66e496db0c660236bf520df699293a3eb41651`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused checks directly.

## Findings

### 1. Critical: the forecast's volatility sigma is replaced by ATR(60)

The approved equation normalizes every EWMA spread by realized volatility
`sigma_t`, with `InpVolWindow=60` (card lines 76-77 and 162-164). Source lines
47-64 use `QM_ATR(..., InpVolWindow)` instead. A 60-day ATR is not the return
volatility/standard-deviation normalizer specified by the model, so all six
forecast magnitudes and the +/-0.35 threshold crossings are changed.

### 2. Critical: continuous forecast rebalancing is not implemented

The card's only profit/exit rule is continuous dynamic rebalancing based on
`S_t` (card lines 96-99). The EA opens one fixed-size position, leaves
`Strategy_ManageOpenPosition` empty, and closes the entire position only when
the forecast crosses zero (source lines 139-168). No exposure scaling or
rebalance mechanics exist, and the zero-cross liquidation rule is not in the
approved card.

### 3. High: missing long-horizon EMA data is included as zero

`CalculateForecast` checks only the ATR normalizer. It never validates the 12
EMA reads, including the 256-day slow horizon (source lines 53-62). Framework
indicator reads return zero when unavailable; those zeros are then divided by
sigma and included in the score, potentially creating false entries or exits.
The forecast must fail closed until every required horizon is ready.

### 4. High: the mandatory execution contract is undeclared

`OnInit` calls `QM_FrameworkInit` and then reports `INIT_OK` (source lines
176-185), but never calls `QM_FrameworkDeclareExecutionContract`. The D1 card
binding and Friday-close override therefore have no runtime mismatch check or
explicit declaration, contrary to `QM_Common.mqh` lines 442-489.

### 5. High: forecast exit work runs on every tick

`OnTick` evaluates `Strategy_ExitSignal` before the new-bar gate (source lines
194-225). While a position is open, every market tick repeats ATR plus all 12
EMA reads even though the D1 forecast can change only once per closed bar.
Cache the complete score on the D1 new-bar path to avoid tester-timeout risk.

### 6. High: the approved loss-limit contract is absent

The card requires a 2.0% daily realized-loss entry halt, a 2.5% daily hard
stop, and a 5.0% total-drawdown stop. The EA implements none. Its generic
framework path supplies 3.0% daily and 0.0% portfolio drawdown
(`QM_Common.mqh` line 298), which is not the approved contract.

## Independent verification

- Fresh compile: PASS, 0 errors / 0 warnings; EX5 size 387,910 bytes; log
  `C:/QM/repo/framework/build/compile/20260818_172901/QM5_41006_man-ahl-multispeed-ewma-trend.compile.log`.
- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: PASS, zero failures and zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_172928.json`.
- Four active magic rows are collision-free and all four values are present in
  the generated resolver.
- All four backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- The approved-card copy in Git matches the canonical approved card byte for
  byte (SHA-256 `eb537b7a95a3357332cad3c8ae2bd12d7bdaa58b9458cd74eaae160111160a80`).
- Focused forbidden scan found no direct indicator handles, `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, or ML calls.
- Producer smoke was explicitly deferred to governed Q02 dispatch. No runtime
  or pipeline verdict is inferred, and no active tester was interrupted.

Fresh compilation regenerated only the tracked EX5 and refreshed setfile
`build_hash` comments. No Gemini MQ5 source, registry, resolver, work item,
terminal, AutoTrading, or pipeline state was changed.
