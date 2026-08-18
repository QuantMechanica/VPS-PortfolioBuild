# Codex review: QM5_41010 Gemini build

- Review task: `ba6be389-4570-4ae6-b636-40e62ae7ad2f`
- Gemini source task: `5111533d-3668-4f98-a036-c379de89ce7c`
- Source artifact: `C:/QM/repo/framework/EAs/QM5_41010_developing-poc-migration-scalper/QM5_41010_developing-poc-migration-scalper.mq5`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_41010_developing-poc-migration-scalper.md`
- Reviewed tree HEAD: `d9493e11b44636018617eb2e12e0e9d8fd74e351`
- Source build commit: **none; MQ5, SPEC, and EX5 are untracked at the reviewed HEAD**
- MQ5 SHA-256: `d817c6d14756049d394036183101c526a4641c11f1be37cb4b31e128df118cab`
- Fresh EX5 SHA-256: `17f6aeb7afed02afc99e0e0194607a82a35667445f973731bd8a732c0de9393d`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex reviewed the approved card, implementation,
registries, and focused checks directly.

## Findings

### 1. Critical: the core d-POC mechanic is an unapproved invented proxy

The card defines entry from `dPOC_t - dPOC_t-4`, but never defines the profile
session/window, bucket granularity, or how MT5 bar volume is assigned to price
(card lines 72-93 and 157-164). The EA and its Gemini-authored SPEC introduce a
32-bar rolling window and ten-quote-point buckets (source lines 37-44 and
139-143), then distribute each bar's entire tick volume uniformly across every
bucket between that bar's low and high (source lines 71-129). That proxy is the
strategy's central signal, not a plumbing detail. It needs an approved,
reproducible card formula before a build can claim mechanical fidelity.

### 2. High: an invalid profile is silently replaced with the range midpoint

When a profile requires more than 2,000 buckets, `CalculateDPOC` returns the
window midpoint (source lines 89-90) instead of failing closed. A midpoint is
not a point of control. It can generate false migration and entry signals with
no indication that the required volume profile was unavailable.

### 3. High: card “ticks” are implemented as quote points without symbol evidence

The card requires four ticks for entry and stop buffers (card lines 89-98).
Source lines 139-143, 181-182, and 243-245 use `SYMBOL_POINT` for both profile
buckets and buffer distances rather than `SYMBOL_TRADE_TICK_SIZE`. No evidence
shows those values are identical for both NDX.DWX and SP500.DWX. The build
therefore does not guarantee the approved tick distances or a comparable POC
grid across targets.

### 4. High: the explicit d-POC stop is replaced by an ATR-clamped stop

The approved SL is the active d-POC plus or minus four ticks (card lines
95-98). After calculating that level, source lines 191-198 and 216-223 move it
to an unapproved 0.5-to-4.0 ATR distance from the current quote. TP is then
calculated from the altered distance. This changes both the stop contract and
the resulting payoff location.

### 5. High: the approved loss-limit contract is absent

The card requires a 2.0% daily realized-loss entry halt, a 2.5% maximum daily
drawdown hard stop, and a 5.0% maximum total-drawdown stop (card lines 82-87
and 102-113). No strategy hook or parameter implements those values. Calling
generic `QM_FrameworkInit` alone does not encode this approved three-part
contract.

### 6. High: mandatory management and Friday close are gated by entry filters

`OnTick` returns when news disallows entries and again when the no-trade filter
is active (source lines 305-313) before it calls the d-POC stop ratchet (line
315). The framework Friday-close handler is also after the news return (line
312). Existing positions can therefore miss risk management or a mandatory
Friday close during a news blackout, spread spike, or rollover window.

### 7. High: GMT rollover policy is evaluated in broker-server time

The card specifies a 23:55-00:05 GMT rollover blackout (card lines 82-86).
Source lines 160-164 apply those clock values directly to `TimeCurrent()` and
never convert broker time to UTC. The blackout shifts whenever server time is
not GMT, including broker DST regimes.

### 8. High: the mandatory execution contract is undeclared

`OnInit` calls `QM_FrameworkInit` and returns success without calling
`QM_FrameworkDeclareExecutionContract` (source lines 287-295). The approved
M15 host-symbol binding therefore has no fail-closed runtime declaration.

### 9. High: the package has no authenticated source commit

At reviewed HEAD `d9493e11b`, the MQ5, SPEC, and freshly compiled EX5 are all
untracked. The two tracked setfiles existed only with `build_hash: pending`
before this review compile. A filesystem path and SHA identify the reviewed
bytes, but there is no committed Gemini source build for close-review to
authenticate or reproduce from repository history.

## Independent verification

- Fresh compile: PASS, 0 errors / 0 warnings; EX5 size 393,040 bytes; log
  `C:/QM/repo/framework/build/compile/20260818_173933/QM5_41010_developing-poc-migration-scalper.compile.log`.
- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: **FAIL**, eight raw-series-call failures (`iVolume`
  three times, `iHigh` twice, `iLow` twice, and `iClose` once); report
  `D:/QM/reports/framework/21/build_check_20260818_174000.json`.
- Two active magic rows (`410100000` and `410100001`) are collision-free and
  present in the generated resolver.
- Both backtest setfiles use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `qm_news_stale_max_hours=336`.
- The approved-card copy in Git matches the canonical approved card byte for
  byte (SHA-256 `dc23dc5fe8bb86c75047997e6bd7eb04d47030629a3aa3026ce88252e6671182`).
- Focused forbidden scan found no direct indicator handles, `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, or ML calls; the strict raw-series failures
  above remain unresolved.
- No smoke test or pipeline phase was run. No runtime or pipeline verdict is
  inferred, and no active tester was interrupted.

Fresh compilation created the untracked EX5 and refreshed only the two tracked
setfile `build_hash` comments. No Gemini source, registry, resolver, work item,
terminal, AutoTrading, or pipeline state was changed.
