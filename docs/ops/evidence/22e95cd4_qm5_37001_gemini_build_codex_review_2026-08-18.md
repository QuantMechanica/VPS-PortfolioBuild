# Codex review: QM5_37001 Gemini build

- Review task: `22e95cd4-390e-48a4-aa40-1b144a2817e3`
- Gemini source task: `92c3eb98-4998-40dc-b31a-8b2da987365e`
- Source artifact: `D:/QM/strategy_farm/artifacts/build_results/QM5_37001_ernest-chan-ornstein-uhlenbeck-statarb_build_result.json`
- Reviewed tree HEAD: `07a691f79257a7f798b129f674e800769de5269b`
- Source SHA-256: `7b59d7b080727e7cc525885567052d83e163864a673785614651fbf992acedd4`
- Fresh EX5 SHA-256: `addeda9ceea2dc04d89a0de3aea62734bfa65dea3daee63496ef3c8c43916f2b`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex therefore reviewed the approved card,
implementation, producer result, registries, and focused checks directly.

## Findings

### 1. Critical: a single-symbol OU trade replaces the approved spread package

The card defines an OU model on a cointegrated currency-pair spread and calls
for `BUY Spread Package` / `SELL Spread Package`. `ComputeOrnsteinUhlenbeck`
reads only one symbol's close series at lines 76-139, and entry lines 188-210
send one market order on `_Symbol`. There is no second leg, hedge ratio,
cointegration/spread construction, or atomic package lifecycle. The code is a
univariate price-mean-reversion EA, not the approved stat-arbitrage mechanic.

### 2. High: the 100-bar OLS model is recomputed on every tick while a trade is open

`Strategy_ExitSignal` calls the full `CopyRates(..., 101)` regression at lines
253-268. `OnTick` invokes that exit at lines 339-351 before the new-bar gate at
line 361. This defeats closed-bar caching and repeats two 100-element loops on
every H1 tick, creating the exact per-tick full-window performance class that
the V5 review contract blocks.

### 3. High: the time stop uses the configured maximum, not the calibrated half-life

The approved exit is `2.5 * tau`, where `tau` is the fitted half-life. Lines
270-275 instead use `strategy_time_stop_mult * strategy_max_half_life` for
every position. A fitted 5-bar process and a fitted 40-bar process therefore
receive the same 100-bar time stop, materially changing the exit rule.

### 4. High: the approved drawdown controls are absent

The card requires a 2.0% daily realized-loss entry halt, a 2.5% daily hard
stop, and a 5.0% total-drawdown stop. The EA implements none of those
thresholds. Initializing the generic framework does not establish the
card-specific limits.

### 5. Medium: entry-only filters can suspend protective exits

`OnTick` returns for rollover or expanded spread at lines 334-335 before the
OU divergence/mean/time exits at lines 339-351. Those card filters govern new
entries; they do not authorize leaving existing exposure unmanaged.

### 6. High: the reviewed source and binary have no committed identity

The EA directory, MQ5, EX5, SPEC, and setfiles are untracked in the canonical
checkout. No commit binds the reviewed source hash to the rebuilt binary, so
the artifact cannot be accepted or handed to the pipeline in this state.

## Independent verification

- Fresh compile: PASS, 0 errors / 0 warnings; EX5 size 392,350 bytes; log
  `C:/QM/repo/framework/build/compile/20260818_145817/QM5_37001_ernest-chan-ornstein-uhlenbeck-statarb.compile.log`.
- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: PASS, zero failures/warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_150620.json`.
- Three active magic rows are collision-free and present in the generated
  resolver.
- All three backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- The producer JSON satisfies its static schema, but supplies no smoke summary
  (`smoke_result=deferred_p2_smoke`); no runtime or pipeline verdict is inferred.

Fresh compilation regenerated the untracked EX5 only. No Gemini source,
setfile, registry, work item, terminal, AutoTrading, or pipeline state was
changed.
