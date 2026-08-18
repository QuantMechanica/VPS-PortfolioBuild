# Codex review: QM5_39003 Gemini build

- Review task: `ec8363cd-b870-450d-9ce9-4ec345ff87db`
- Gemini source task: `f361cc66-38ca-4125-ab5f-153ce82fc340`
- Source artifact: `D:/QM/strategy_farm/artifacts/builds/f361cc66-38ca-4125-ab5f-153ce82fc340.json`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_39003_forexfactory-james16-price-action-ppz.md`
- Reviewed tree HEAD: `56be1b34e03bf9bf3195f755da65326524bb9cc2`
- MQ5 SHA-256: `c6d1b71b349ba5b34d11650c1fb6792f34eadbf7f5c09f386b4f1a3d8164f1ff`
- Fresh EX5 SHA-256: `8880fb107e078c01067d22d948d6214ced662494d5911257ef8fbceda5e3e8c3`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex reviewed the approved card, implementation,
producer result, registries, and focused checks directly.

## Findings

### 1. Critical: the approved swing trailing exit is absent

The card requires a dynamic swing-high/low trailing stop. Source
`Strategy_ManageOpenPosition` is empty at lines 207-209 and
`Strategy_ExitSignal` always returns false at lines 211-214. The implementation
therefore has no trailing lifecycle and can exit only through its initial
broker SL/TP or framework-wide controls.

### 2. High: the TP does not target the next PPZ

The card specifies the next institutional PPZ as the take-profit target. Lines
167 and 190 instead use `QM_TakeRR` to attach an unconditional fixed 2.5R TP;
the detected PPZ levels are never used to select an exit target.

### 3. High: the configured 2-pip stop buffer is converted into 20 pips

Line 156 multiplies `strategy_sl_buffer_pips` by 10 before passing it to
`QM_StopRulesPipsToPriceDistance`, whose argument already represents pips.
The default 2.0 buffer therefore becomes 20 pips and also expands the 2.5R TP.

### 4. Critical: mandatory no-trade filters are not implemented

`Strategy_NoTradeFilter` always returns false at lines 120-123. The card's
1.8-ATR spread filter, 23:55-00:05 rollover blackout, and 2.0% daily
realized-loss entry halt are absent. The max-position rule is checked inside
entry generation, but it does not replace the other mandatory filters.

### 5. High: the approved hard loss limits are absent

The required 2.5% daily hard stop and 5.0% total-drawdown stop are not
implemented. The generic framework path supplies 3.0% daily and 0.0% portfolio
drawdown instead.

### 6. High: reviewed source and binary have no committed identity

The MQ5, EX5, and SPEC are untracked in the canonical checkout. No commit binds
the reviewed source hash, freshly compiled binary, and producer result.

## Independent verification

- Fresh compile: PASS, 0 errors / 0 warnings; EX5 size 390,624 bytes; log
  `C:/QM/repo/framework/build/compile/20260818_164405/QM5_39003_forexfactory-james16-price-action-ppz.compile.log`.
- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: PASS, zero failures and zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_164517.json`.
- Three active magic rows are collision-free and represented in the generated
  resolver.
- All three backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Focused forbidden scan found no direct indicator handles, `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, or ML calls. The bounded D1 PPZ scan runs only
  after the new-bar gate.
- The producer result satisfies the static build-result schema with
  `smoke_result=deferred_p2_smoke`; no smoke summary exists. No runtime or
  pipeline verdict is inferred.

Fresh compilation regenerated the untracked EX5 and refreshed only setfile
`build_hash` comments. No Gemini source, registry, resolver, work item,
terminal, AutoTrading, or pipeline state was changed.
