# Codex review: QM5_40005 Gemini build

- Review task: `96b77b6a-9abe-4acc-8c4d-9f59d2b9bf3a`
- Gemini source task: `788cf6e9-a0dc-4ccc-8462-48650989f114`
- Source artifact: `docs/ops/evidence/788cf6e9_qm5_40005_build_ea_result_2026-08-18.md`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_40005_tradingview-multitimeframe-supertrend-atr.md`
- Reviewed tree HEAD: `4ed682ad08d4f7dc88e288c55f43fbcb40fa1715`
- Source build commit: `967a427eb`
- MQ5 SHA-256: `3987f621520bd7b1faa393ff522db794d4956d265928e93f520211a68cadaf20`
- Fresh EX5 SHA-256: `bdef574b18f3f875801f27a6419d8e708df762e3142a8b2eba1ee70eeb98bb5e`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused checks directly.

## Findings

### 1. Critical: the approved 2-pip buffer is implemented as 20 pips

`QM_StopRulesPipsToPriceDistance` accepts whole pips and applies the broker
digit factor itself (`QM_StopRules.mqh` lines 39-50). Source lines 163 and 219
pass `InpBufferPips * 10.0`, so the default 2.0-pip entry and trailing buffer is
converted as 20 pips. This changes every initial stop, 2R target, and trailing
stop across EURUSD, GBPJPY, and XAUUSD from the approved mechanics.

### 2. High: the ATR cap can move the stop inside the Supertrend boundary

The card requires the stop at the active Supertrend line plus/minus 2 pips.
Lines 171-174 and 195-198 cap the distance at 3.5 ATR and recompute the stop
from entry. When the Supertrend boundary is farther away, the cap places the
stop inside the approved boundary and changes the 2R target.

### 3. High: full Supertrend reconstruction runs twice on every tick

`OnTick` calls both management and exit before the new-bar gate (source lines
333-361). Each calls `CalculateSupertrend`, which copies 100 bars and performs
one `QM_ATR` read per bar. The EA therefore performs roughly 200 historical
indicator reads on every tick even with no position; an entry bar adds three
more reconstructions. This is a deterministic tester-timeout risk and does not
match the card's closed-bar/bar-by-bar evaluation. Cache H1/H4 state once per
new H1 bar and reuse it.

### 4. High: an unapproved market exit is added on every H1 flip

The card specifies the 2R TP, Supertrend-line SL, and bar-by-bar Supertrend
trailing stop (card lines 95-99). Source lines 252-273 add a separate immediate
strategy close whenever H1 direction flips. That is not equivalent to letting
the buffered trailing stop execute and materially changes exit price and
slippage behavior.

### 5. High: the approved loss-limit contract is absent

The card requires a 2.0% daily realized-loss entry halt, a 2.5% daily hard
stop, and a 5.0% total-drawdown stop. The EA implements none. Its generic
framework path supplies 3.0% daily and 0.0% portfolio drawdown
(`QM_Common.mqh` line 298), which is not the approved contract.

## Independent verification

- Fresh compile: PASS, 0 errors / 0 warnings; EX5 size 395,900 bytes; log
  `C:/QM/repo/framework/build/compile/20260818_171523/QM5_40005_tradingview-multitimeframe-supertrend-atr.compile.log`.
- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: PASS, zero failures and zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_171553.json`. The static gate
  does not currently detect the doubled pip conversion or repeated
  reviewer-annotated reconstruction.
- Three active magic rows are collision-free and all three values are present
  in the generated resolver.
- All three backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- The approved-card copy in Git matches the canonical approved card byte for
  byte (SHA-256 `094bee5401161ba2376bc6f0bf827dba4dd922df4df63a6810e16e4bf9d070a7`).
- Focused forbidden scan found no direct indicator handles, `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, or ML calls.
- The producer supplied no smoke summary. No runtime or pipeline verdict is
  inferred, and no active tester was interrupted.

Fresh compilation regenerated only the tracked EX5 and refreshed setfile
`build_hash` comments. No Gemini MQ5 source, registry, resolver, work item,
terminal, AutoTrading, or pipeline state was changed.
