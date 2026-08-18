# Codex review: QM5_38008 Gemini build

- Review task: `6076e5b8-5a12-4590-8e89-bd2d24f21f4d`
- Gemini source task: `1f82ac59-1c1e-4e72-a1f8-4eaea2120347`
- Source artifact: `docs/ops/evidence/1f82ac59_qm5_38008_build_ea_result_2026-08-18.md`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_38008_codetrading-optimized-bollinger-trend-breakout.md`
- Reviewed tree HEAD: `56be1b34e03bf9bf3195f755da65326524bb9cc2`
- MQ5 SHA-256: `eeb06bfe730f635f247d2be662f5378ee585d3a6b8949845586338af83608dec`
- Fresh EX5 SHA-256: `76b2612029a45a549a2e5e7da40f755afb3ba3c346804f3cbecbeae18601165e`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused checks directly.

## Findings

### 1. Critical: a fixed 5R TP replaces the approved open-ended trend exit

The card explicitly specifies no take-profit and an open-ended position closed
on the Bollinger midline. Source line 43 defaults `strategy_tp_rr_mult` to 5.0,
and lines 163-172 attach that fixed broker TP to every entry. The implemented
holding rule is therefore materially different from the approved strategy.

### 2. Critical: the open-position guard disables the midline exit and break-even

`Strategy_NoTradeFilter` returns true for an open position at lines 118-120.
`OnTick` returns at lines 303-304 before calling management at line 306. The
midline close at lines 203-216 and break-even logic at lines 218-242 can never
run while a position exists, leaving only the unapproved 5R TP and broker SL.

### 3. High: the approved loss-limit contract is absent

The card requires a 2.0% daily realized-loss entry halt, a 2.5% daily hard
stop, and a 5.0% total-drawdown stop. The EA implements none. The generic
framework path supplies 3.0% daily and 0.0% portfolio drawdown instead.

### 4. High: reviewed source and binary have no committed identity

The MQ5, EX5, SPEC, and copied card are untracked in the canonical checkout.
No commit binds the reviewed source hash, freshly compiled binary, and
producer evidence.

## Independent verification

- Fresh compile: PASS, 0 errors / 0 warnings; EX5 size 398,862 bytes; log
  `C:/QM/repo/framework/build/compile/20260818_164257/QM5_38008_codetrading-optimized-bollinger-trend-breakout.compile.log`.
- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: PASS, zero failures and zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_164441.json`.
- Three active magic rows are collision-free and represented in the generated
  resolver.
- All three backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Focused forbidden scan found no direct indicator handles, `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, or ML calls.
- The producer supplied no smoke summary. No runtime or pipeline verdict is
  inferred, and no active tester was interrupted.

Fresh compilation regenerated the untracked EX5 and refreshed only setfile
`build_hash` comments. No Gemini source, registry, resolver, work item,
terminal, AutoTrading, or pipeline state was changed.
