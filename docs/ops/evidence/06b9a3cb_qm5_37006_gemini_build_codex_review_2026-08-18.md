# Codex review: QM5_37006 Gemini build

- Review task: `06b9a3cb-a504-47c1-aa29-ef0b4c61f44c`
- Gemini source task: `fc2c4254-fae3-4ad7-bd0c-c44be30334fb`
- Source artifact: `C:/QM/repo/artifacts/builds/fc2c4254-fae3-4ad7-bd0c-c44be30334fb.json`
- Reviewed tree HEAD: `59467c41c4e53ec72c6731c0378dc0f8c13c1e73`
- MQ5 SHA-256: `7b7555846abefad5e6ada02a092aaf1b3985befded294f5c9633caab094cfd8e`
- Fresh EX5 SHA-256: `37aab81b8139805e9d48e227cd9830a990ac450ed00da7db0a28db3fe4518332`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex therefore reviewed the approved card,
implementation, producer result, registries, and focused checks directly.

## Findings

### 1. Critical: the CUSUM recurrence omits the card's expected-return term

The approved recurrence is `S += y_t - E[y_t]`. Source lines 103-108 add the
raw close difference directly to both accumulators. `CalculateReturnStdDev`
computes a sample mean at lines 76-92, but uses it only for the volatility
threshold and never returns or subtracts it from the CUSUM increment. A
non-zero drift therefore accumulates as a structural break and changes the
authorized signal.

### 2. High: CUSUM state resets before order execution is known

Lines 174-194 zero both accumulators while merely constructing an entry
request. The framework open is not attempted until lines 297-303, and its
boolean result is ignored. A rejected order therefore consumes the signal and
resets state even though the card requires reset upon trade execution.

### 3. High: the approved loss-limit contract is absent

The card requires a 2.0% daily realized-loss entry halt, a 2.5% daily hard
stop, and a 5.0% total-drawdown stop. The EA implements none. Its generic
`QM_FrameworkInit` path currently initializes the shared kill switch at 3.0%
daily and 0.0% portfolio drawdown, which is not the approved contract.

### 4. High: the reviewed source and binary have no committed identity

The MQ5, EX5, and SPEC are untracked in the canonical checkout. A fresh compile
can prove syntax, but no commit binds the reviewed source hash to the binary or
producer result.

## Independent verification

- Fresh compile: PASS, 0 errors / 0 warnings; EX5 size 389,930 bytes; log
  `C:/QM/repo/framework/build/compile/20260818_152648/QM5_37006_cusum-filter-structural-breakout.compile.log`.
- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: PASS, zero failures and two call-graph warnings;
  report `D:/QM/reports/framework/21/build_check_20260818_152924.json`.
  Both warned `CopyRates` calls are reached only through
  `AdvanceState_OnNewBar()` after the `QM_IsNewBar()` gate, so they are not
  per-tick history scans.
- Three active magic rows are collision-free and represented by the current
  generated-resolver hash.
- All three backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- The producer JSON satisfies the static build-result criteria but supplies no
  smoke summary (`smoke_result=deferred_p2_smoke`); no runtime or pipeline
  verdict is inferred.

Fresh compilation regenerated the untracked EX5 and refreshed only setfile
`build_hash` comments. No Gemini source, registry, work item, terminal,
AutoTrading, or pipeline state was changed.
