# Codex review: QM5_39004 Gemini build

- Review task: `6b47ceec-cb94-46e4-80a4-c3ab93de07a2`
- Gemini source task: `d6e07850-a05d-4aa7-ad8b-5f7895fd2b36`
- Source artifact: `D:/QM/strategy_farm/artifacts/builds/d6e07850-a05d-4aa7-ad8b-5f7895fd2b36.json`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_39004_forexfactory-thv-cobra-trix-scalper.md`
- Reviewed tree HEAD: `56be1b34e03bf9bf3195f755da65326524bb9cc2`
- MQ5 SHA-256: `5f74734e688417ec576d8c15c6ca3cd157b137c865372c47f86f87478a2b80c2`
- Fresh EX5 SHA-256: `4f7a7a70348d2c1930885d8b245c5972dabd39dd4a1ffcd161904ab438d41be5`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex reviewed the approved card, implementation,
producer result, registries, and focused checks directly.

## Findings

### 1. Critical: mandatory no-trade filters are not implemented

`Strategy_NoTradeFilter` always returns false at source lines 122-125. The card
requires the 1.8-ATR spread filter, the 23:55-00:05 rollover blackout, and a
2.0% daily realized-loss entry halt. The max-position rule is checked later,
but the other mandatory entry filters are absent.

### 2. High: the configured 2-pip stop buffer is converted into 20 pips

Line 138 multiplies `strategy_sl_buffer_pips` by 10 before passing it to
`QM_StopRulesPipsToPriceDistance`, whose argument already represents pips.
With the default 2.0 value, the stop is placed 20 pips beyond Coral and the 2R
target is expanded by the same error.

### 3. High: Fast-Trix exit state is not tied to confirmed position state

Lines 158 and 180 set `g_pos_direction` while constructing an entry request,
before `QM_TM_OpenPosition` succeeds. The value is not reconstructed from an
existing position in `OnInit`, so a restart disables the Fast-Trix exit for an
open trade. Lines 196-204 also clear the direction before the close result is
known; a rejected close is not retried by the strategy exit.

### 4. High: the approved hard loss limits are absent

The required 2.5% daily hard stop and 5.0% total-drawdown stop are not
implemented. The generic framework path supplies 3.0% daily and 0.0% portfolio
drawdown instead.

### 5. High: reviewed source and binary have no committed identity

The MQ5, EX5, and SPEC are untracked in the canonical checkout. No commit binds
the reviewed source hash, freshly compiled binary, and producer result.

## Independent verification

- Fresh compile: PASS, 0 errors / 0 warnings; EX5 size 391,284 bytes; log
  `C:/QM/repo/framework/build/compile/20260818_164323/QM5_39004_forexfactory-thv-cobra-trix-scalper.compile.log`.
- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: PASS, zero failures and zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_164452.json`.
- Three active magic rows are collision-free and represented in the generated
  resolver.
- All three backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Focused forbidden scan found no direct indicator handles, `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, or ML calls. The bounded TRIX history walk is
  reached only after the M5 new-bar gate.
- The producer result satisfies the static build-result schema with
  `smoke_result=deferred_p2_smoke`; no smoke summary exists. No runtime or
  pipeline verdict is inferred.

Fresh compilation regenerated the untracked EX5 and refreshed only setfile
`build_hash` comments. No Gemini source, registry, resolver, work item,
terminal, AutoTrading, or pipeline state was changed.
