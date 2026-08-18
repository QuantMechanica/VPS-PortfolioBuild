# Codex review: QM5_41011 Gemini build

- Review task: `86e63523-90c7-47e7-bd41-b220e70042e7`
- Gemini source task: `fdaac67c-12cf-4c0f-a203-c19618076972`
- Source artifact: `C:/QM/repo/framework/EAs/QM5_41011_tokyo-london-bank-flow-handover/QM5_41011_tokyo-london-bank-flow-handover.mq5`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_41011_tokyo-london-bank-flow-handover.md`
- Reviewed tree HEAD: `3fab15e50bb05c79a2a67d95e95bcbce25e47398`
- Source build commit: **none; MQ5, SPEC, and EX5 are untracked at the reviewed HEAD**
- MQ5 SHA-256: `376aba9ca4b8b21be86a822bfd3ebeaa6c13a01ec1c79f1afde36edf45aa1547`
- Fresh EX5 SHA-256: `7a9dcbbc0de4f62ae7f8d2b0c46752f704fa005ee319562fda34c404de20e0a3`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex reviewed the approved card, implementation,
registries, and focused checks directly.

## Findings

### 1. Critical: the cached Tokyo range uses the breakout bar and omits required range bars

`AdvanceState_OnNewBar` runs on the first tick of a new M15 bar. When closed
bar `[1]` is 07:00, source lines 81-98 trigger range construction and scan
shifts 1 through 3. Those shifts are 07:00, 06:45, and 06:30, despite the
source comment naming the intended three bars as 06:00, 06:15, and 06:30.
The cached range is therefore contaminated by the first breakout bar and omits
two intended pre-range bars. Entries at source lines 152-200 are not the
approved 06:00-06:45 handover breakout (card lines 74-97).

### 2. Critical: whole-pip inputs are multiplied by ten, while the ATR default also drifts from the card

The approved entry requires a 2-pip breakout buffer and ATR(14) of at least 15
pips (card lines 89-93). The EA defaults `InpBufferPips=2.0` and
`InpMinAtrPips=10.0` (source lines 46-47), then multiplies both values by ten
before passing them to `QM_StopRulesPipsToPriceDistance` (source lines
145-149). That helper already accepts whole pips and applies the 3/5-digit pip
factor (`QM_StopRules.mqh` lines 39-50). The effective defaults are therefore a
20-pip buffer and a 100-pip ATR floor, not 2 and 15 pips. This can suppress the
expected strategy population and is a setup defect, not pipeline evidence.

### 3. High: stop and target mechanics do not implement the approved exit formula

The card fixes SL at the handover-range midpoint and TP at two times the
handover range (card lines 95-98). Source lines 158-165 and 184-191 move the
midpoint stop to an unapproved 0.5-to-4.0 ATR clamp and calculate TP as two
times the resulting stop distance. Those formulas are not equivalent; both
the risk distance and payoff location can materially change.

### 4. High: news/no-trade returns can suppress mandatory position exits

`OnTick` returns when news disallows trading and again when the no-trade filter
is active (source lines 246-254) before it evaluates the 12:00 UTC time stop or
calls the framework Friday-close handler (source lines 253 and 258-267).
Consequently an existing position can remain open past a mandatory time or
Friday exit during a news blackout, spread spike, or rollover window.

### 5. High: the approved loss-limit contract is absent

The card requires a 2.0% daily realized-loss entry halt, a 2.5% maximum daily
drawdown hard stop, and a 5.0% maximum total-drawdown stop (card lines 82-87
and 102-113). No strategy hook or parameter implements those values. Calling
generic `QM_FrameworkInit` alone does not encode this approved three-part
contract.

### 6. High: the mandatory execution contract is undeclared

`OnInit` calls `QM_FrameworkInit` and returns success without calling
`QM_FrameworkDeclareExecutionContract` (source lines 228-235). The approved
M15 host-symbol binding therefore has no fail-closed runtime declaration.

### 7. High: the package has no authenticated source commit

At reviewed HEAD `3fab15e50`, the MQ5, SPEC, and freshly compiled EX5 are all
untracked. The three tracked setfiles existed only with `build_hash: pending`
before this review compile. A filesystem path and SHA identify the reviewed
bytes, but there is no committed Gemini source build for close-review to
authenticate or reproduce from repository history.

### 8. Medium: a rejected order consumes the only daily opportunity

`Strategy_EntrySignal` sets `g_cached_traded=true` before the order is sent
(source lines 174 and 200), while `OnTick` ignores the boolean result of
`QM_TM_OpenPosition` (source lines 274-279). A transient broker or validation
rejection therefore suppresses every later valid signal that day even though
no trade opened.

## Independent verification

- Fresh compile: PASS, 0 errors / 0 warnings; EX5 size 389,342 bytes; log
  `C:/QM/repo/framework/build/compile/20260818_173414/QM5_41011_tokyo-london-bank-flow-handover.compile.log`.
- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: **FAIL**, five raw-series-call failures (`iClose`,
  two `iTime`, `iHigh`, and `iLow`); report
  `D:/QM/reports/framework/21/build_check_20260818_173447.json`.
- Three active magic rows (`410110000`-`410110002`) are present in the generated
  resolver.
- All three backtest setfiles use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `qm_news_stale_max_hours=336`.
- The approved-card copy in Git matches the canonical approved card byte for
  byte (SHA-256 `0d9d23af9a259a76ea06ca42728ceda518867f4cd67369a3f67ab9514c532afe`).
- Focused forbidden scan found no direct indicator handles, `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, or ML calls; the strict raw-series failures
  above remain unresolved.
- No smoke test or pipeline phase was run. No runtime or pipeline verdict is
  inferred, and no active tester was interrupted.

Fresh compilation created the untracked EX5 and refreshed only the three
tracked setfile `build_hash` comments. No Gemini source, registry, resolver,
work item, terminal, AutoTrading, or pipeline state was changed.
