# QM5_13132 XTI/XNG Betting-Against-Beta Q02 Enqueue Evidence

Date: 2026-07-11
Branch: `agents/board-advisor`
Actor: Codex paced fleet
Status: Q01 PASS; logical-basket Q02 pending

## Outcome

Built and enqueued one new low-frequency beta-matched commodity/energy
sleeve: `QM5_13132_energy-bab`. Once per broker month, the EA estimates
source-aligned one-year Dimson betas for XTI and XNG, buys the lower-beta leg,
shorts the higher-beta leg, and sizes the two notionals toward equal energy-
benchmark beta.

This is an out-of-sample Q02 candidate, not a certified portfolio admission.
No decorrelation result, source performance transfer, or live readiness is
claimed.

## Candidate Selection And Dedup

The mission's named XAU/XAG ratio candidate was rejected because the repository
already contains `QM5_12577_cme-xauxag-ratio`,
`QM5_12724_cme-xauxag-brk`, `QM5_12862_xauxag-rspread`, and the older Desai
gold/silver pair. The WTI and XNG inventory also contains extensive calendar,
trend, reversal, momentum, carry, event, and volatility sleeves.

The selected edge is commodity BAB, which was absent from the energy book.
Existing BAB EAs `QM5_1104`, `QM5_12396`, and `QM5_12403` cover equity
indices. `QM5_1253_carver-lowbeta-rv` is registered for indices and FX only.
None trades a beta-matched XTI/XNG package.

Pre-allocation command:

`python framework/scripts/research_dedup_check.py check --slug energy-bab --strategy-id FRAZZINI-BAB-2014_XTI_XNG_S01 --author "Andrea Frazzini Lasse Pedersen" --mechanic "monthly XTI XNG market neutral betting against beta long lower beta short higher beta one year D1 Dimson beta equal risk energy benchmark shrink beta halfway to one beta matched package one month hold"`

The tool produced a false fuzzy hit on `energy-rsj_card.md` because of the
shared `energy-` token; mechanic similarity was zero. Formula, direction,
formation window, sizing, and lifecycle review returned
`CLEAN_AFTER_MANUAL_REVIEW` before allocation.

## Source And Card Evidence

- Primary: Frazzini, Andrea, and Lasse Heje Pedersen (2014), "Betting Against
  Beta," *Journal of Financial Economics* 111(1), 1-25, DOI
  `10.1016/j.jfineco.2013.10.005`.
- Official working paper: NBER Working Paper 16601, DOI
  `10.3386/w16601`.
- Complete extraction text:
  `https://conference.nber.org/confer/2010/BEf10/Frazzini.pdf`.
- The complete 68-page conference draft was read end to end, including theory,
  methodology, proofs, robustness appendix, tables, figures, and instrument
  membership. The official NBER record/current wrapper was also checked.
- Source packet: `strategy-seeds/sources/FRAZZINI-BAB-2014/source.md`.
- Canonical card: `strategy-seeds/cards/energy-bab_card.md`.
- Approved fleet card:
  `artifacts/cards_approved/QM5_13132_energy-bab.md`.
- Card schema/ML lint: PASS.
- G0 readiness lint: PASS.
- R1/R2/R3/R4: PASS/PASS/PASS/PASS.

The source explicitly includes crude oil and natural gas in its 24-commodity
universe and uses a diversified equal-risk commodity benchmark. Its
commodity-only BAB result is positive but statistically weak. The EA narrows
the test to two continuous CFDs and raw close returns. Those are Q02 kill
risks, and no source statistic is imported.

## Locked Mechanic

At the first tradable XTI D1 bar of a broker month:

1. Load 258 synchronized completed closes for XTI and XNG.
2. Calculate 257 simple returns; the oldest five provide lag history and the
   latest 252 are regression observations.
3. Form a fixed inverse-volatility XTI/XNG benchmark.
4. Regress each leg on an intercept, the current benchmark return, and lags
   one through five.
5. Sum the six slopes and shrink raw beta halfway toward one.
6. Buy lower beta and short higher beta.
7. Split fixed stop risk in proportion to `(ATR / price) / beta`, targeting
   notional exposure proportional to inverse beta.
8. Reject entry if broker-rounded notional-beta exposures differ by more than
   20%.
9. Close and renew on the next month, after 35 days, or on orphan/invalid
   composition.

The estimator, shrinkage, benchmark, direction, beta scaling, and monthly
renewal are locked. The EA uses no RSI, momentum rank, price ratio, z-score,
carry/swap, event feed, banned indicator, or ML.

## Registry Evidence

- EA registry:
  `13132,energy-bab,FRAZZINI-BAB-2014_XTI_XNG_S01,active`.
- Magic slot 0: `XTIUSD.DWX -> 131320000`.
- Magic slot 1: `XNGUSD.DWX -> 131320001`.
- `QM_MagicResolver.mqh` was regenerated and contains both values.

Resolver generation retained the repository's three pre-existing
missing-directory warnings for IDs `1001`, `1015`, and `1016`; no `13132`
defect remained.

## Q01 Build Evidence

- EA source:
  `framework/EAs/QM5_13132_energy-bab/QM5_13132_energy-bab.mq5`.
- Compiled artifact:
  `framework/EAs/QM5_13132_energy-bab/QM5_13132_energy-bab.ex5`.
- Compile result: PASS, 0 errors, 0 compiler warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260711_035926/QM5_13132_energy-bab.compile.log`.
- Build check: PASS, 0 failures, 0 warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260711_035953.json`.
- SPEC validator: PASS.
- Build prerequisite guard: PASS.
- Guardrail validator: PASS.
- Symbol scope: `BASKET_OK`, 0 violations.
- MQ5 SHA256:
  `ae3faa18103103a989bb2d12d704d69043f1fa5b52889f068553ee40cb7e0532`.
- EX5 SHA256:
  `d3ef0e506cf8020e4c7b0fd8e9936deb46d06b8d6f615b55597fffe098efd3c1`.

## Risk And Setfile Evidence

- Logical symbol: `QM5_13132_XTI_XNG_BAB_D1`.
- Host: `XTIUSD.DWX`, D1.
- Basket symbols: `XTIUSD.DWX`, `XNGUSD.DWX`.
- Setfile:
  `framework/EAs/QM5_13132_energy-bab/sets/QM5_13132_energy-bab_QM5_13132_XTI_XNG_BAB_D1_D1_backtest.set`.
- Setfile SHA256:
  `e528a7a1f2002a5983217aa3ef16a6fe48f9e56d342b95c07446e03cf2f6ba9d`.
- `RISK_FIXED=1000`.
- `RISK_PERCENT=0`.
- `PORTFOLIO_WEIGHT=1`.
- Friday close is disabled only for the source-aligned monthly hold.
- Both legs receive frozen `ATR(20) * 3.5` hard stops, a 20% maximum beta-
  mismatch guard, orphan cleanup, and a 35-day stale-package guard.

## Q02 Queue Evidence

- Build task: `750a1be8-f45a-4edf-964b-adffb2e90b5a` (`done`).
- Work item: `92097f32-58bb-4c86-9b54-5ee371716499`.
- Phase: `Q02`.
- Kind: `backtest`.
- Symbol: `QM5_13132_XTI_XNG_BAB_D1`.
- Status at verification: `pending`.
- Attempt count: `0`.
- Claimed by: none.
- Enqueued at: `2026-07-11T04:01:12+00:00`.
- Queue path: `record_build_result.auto_q02`.
- Basket manifest: two traded symbols, host `XTIUSD.DWX`, timeframe D1.

No manual smoke, backtest, terminal launch, dispatch tick, or worker tick was
started. The Q02 item was left pending for paced dispatch. No backtest CPU
ceiling was consumed or encountered by this build turn.

## Safety Boundary

- No T_Live path changed.
- No AutoTrading setting changed.
- No live setfile or deploy manifest created.
- No portfolio gate, gate threshold, portfolio KPI, or admission file changed.
