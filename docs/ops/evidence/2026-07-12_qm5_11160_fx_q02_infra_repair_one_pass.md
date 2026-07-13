# QM5_11160 diverse-FX Q02 infrastructure recovery — one-pass result

## Outcome

`QM5_11160_dwx-brk-risk` was claimed as a distinct infrastructure-recovery unit and rebuilt from its approved Darwinex card. The source, package metadata, and canonical `.DWX` setfiles were repaired, and all static gates passed. Both compile wrappers reported PASS, but the repository `.ex5` remained byte-for-byte identical to the pre-repair HEAD binary. The mandatory one-pass smoke therefore exercised stale code and produced valid deterministic reports with zero trades. The package was **not** re-enqueued at Q02.

The blocking evidence is specific: the stale EA generated breakout entry attempts, but `QM_Entry` rejected each one because its request arrived with a garbage `symbol_slot` even though the tester loaded `qm_magic_slot_offset=0`. The repaired MQ5 explicitly assigns that field, but the compiler/deployment chain did not produce a new binary, so the source correction was never tested. The build is routed for bounded stale-binary rework rather than being allowed to consume Q02 capacity.

## Selection and farm claim

- Farm task: `2ce555a1-f57a-4949-8d33-2f36dfb7ea29`
- Assigned lane: `codex:agents/board-advisor`
- Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_11160_dwx-brk-risk.md`
- G0 status: `APPROVED`
- Source: Darwinex Blog, "The Journey of an Automated Trading Expert", 2024-10-03, https://blog.darwinex.com/the-journey-of-an-automated-trading-expert
- Diversity basket: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, and canonical DAX alias `GDAXI.DWX`, H1
- Claim backup: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11160_q02_repair_claim_20260711T234937Z.sqlite`

The approved build backlog had no executable higher-diversity card: the lumber and bond cards require unavailable feeds, while the remaining XAU/NDX card adds to the concentrated index/metal cohort. QM5_11160 had 48 Q02 rows with infrastructure-only outcomes, no business verdict, and no downstream phase.

## Repair performed before smoke

- Replaced the per-tick 48-bar `iHigh`/`iLow` channel scans with one bounded `CopyRates` refresh per new H1 bar and cached the closed-bar breakout state.
- Kept break-even management and closed-bar exits active through entry-only news/spread filters.
- Restricted strategy closes to the chart symbol and current registered magic.
- Zero-initialized the entry request and explicitly assigned `qm_magic_slot_offset` and expiration fields.
- Added the required `SPEC.md` and an exact SHA-256-identical copy of the approved card.
- Regenerated four canonical backtest setfiles. Every setfile uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, all nine strategy inputs, and its registered slot (`0`, `1`, `2`, `3`). The obsolete `GER40.DWX` setfile was replaced by `GDAXI.DWX`.
- Invoked the scoped and strict compile workflows against the current framework; both reported PASS, but the post-compile artifact-integrity check below proves that they did not leave a refreshed repository binary.

Package hashes after the one build attempt:

- MQ5: `30DF156CFAA65030C3DAEA2F76B3D7BB71FB76DB7FC493629288AEBD62F423EA`
- EX5: `52B8D0E3926572E6D35ECAC12DC1382B1CFD50E07086A03CEEE05E1CF2B7C693` — stale; Git blob `208a2e3447aa2880cd7447aaae4ecb0ae32425c8`, exactly equal to `HEAD:framework/EAs/QM5_11160_dwx-brk-risk/QM5_11160_dwx-brk-risk.ex5`

## Verification

- SPEC validator: PASS
- Deterministic build guardrails: PASS
- Scoped build check: PASS, 0 failures / 0 warnings
  - `D:\QM\reports\framework\21\build_check_20260711_235920.json`
- Strict compile wrapper: PASS, 0 errors / 0 warnings
  - `D:\QM\reports\compile\20260711_235941\summary.csv`
- Binary freshness/integrity: **FAIL**; the EX5 retained the pre-repair Git blob despite the wrapper PASS
- P1 artifact-existence check: PASS (existence only; it does not verify freshness)
  - `D:\QM\reports\pipeline\QM5_11160\P1\P1_QM5_11160_result.json`

## One-pass smoke and rework directive

The single permitted smoke invocation used the first registered symbol:

- Symbol / period / year: `EURUSD.DWX`, H1, 2024
- Terminal dispatch: `any` selected factory terminal T6
- Model: 4, real ticks
- Smoke floor: 1 trade
- Runner result: `MIN_TRADES_NOT_MET`; build classification: `framework_error` / stale `.ex5`
- Summary: `D:\QM\reports\smoke\QM5_11160\20260712_000022\summary.json`
- Both deterministic runs: valid current-EA report, no OnInit failure, no timeout, no log bomb, 0 trades

The tester loaded the intended inputs, including `qm_ea_id=11160`, `qm_magic_slot_offset=0`, and the card defaults. Starting on 2024-01-02, the stale binary's journal then recorded repeated entry-path failures such as:

`EA_MAGIC_NOT_REGISTERED: invalid symbol_slot=572516304`

Other observed garbage values included `1547890752` and `1563734080`. Their timestamps prove the breakout path is producing entry attempts and rule out missing history or an inactive 2024 signal regime. They do **not** test the repaired source because the smoke-deployed EX5 is the old Git blob.

The next build wake should force a fresh EX5 regeneration, verify before dispatch that the binary hash differs from Git blob `208a2e3447aa2880cd7447aaae4ecb0ae32425c8`, and then run a fresh one-pass smoke. If a genuinely refreshed binary still logs garbage slots, only then inspect request assignment/copy semantics. Per the binding `codex_build_ea` discipline, this wake did not compile, rewrite, or re-smoke after discovering the stale artifact.

## Funnel and safety state

- Q02 enqueue: deliberately skipped; Q01 zero-trade artifacts must not fan out.
- Factory state: `D:\QM\strategy_farm\state\FACTORY_OFF.flag` remained asserted, so no pipeline phase dispatched.
- Backtest ceiling: not hit; only the one dispatcher-selected factory smoke was launched and T6 exited/released cleanly.
- T_Live / AutoTrading: untouched.
- Portfolio gate and T_Live manifest: untouched.
- Required output: `artifacts/qm5_11160_fx_q02_infra_repair_one_pass_20260712.json`.
