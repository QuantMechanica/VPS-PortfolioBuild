# QM5_39008 FX review repair and Q02 CPU stop

Date: 2026-08-18 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `BUILD/MECHANICAL REVIEW PASS; Q02 NOT ENQUEUED — HARD CPU CEILING`

## Selection

The frozen sign-aware 66-pair cointegration reconciliation at `a80493291`
remains an ancestor of HEAD and reports every relationship already built.
The preferred anchors are not Q02-blocked: `QM5_12532` is past Q02 PASS and
later failed Q05, while `QM5_12533` is past Q02 PASS and later failed Q04.

Per the mission fallback, this unit advances one existing forex card:
`QM5_39008_forexfactory-symphonie-matrix-system` on `EURUSD.DWX`,
`GBPUSD.DWX`, and `USDCHF.DWX`, H1. Its approved card is unchanged; no new
card, hypothesis, parameter, or source claim was created.

## Mechanical repair

Codex review found that `Symphonie_AllBear()` negated each bullish light.
That made equality and unavailable indicator reads count as bearish; all four
pooled wrappers returning their failure sentinel (`0.0`) could therefore
manufacture a unanimous short signal.

The EA now evaluates the card's bearish rules explicitly:

- close `<` EMA(20);
- RSI(14) `<` 50;
- MACD main `<` signal; and
- stochastic K `<` D.

EMA/close and RSI failure sentinels are rejected, and equal values are neutral
for every light. The approved-card snapshot was added under the EA `docs/`
directory, stale card pointers in source/SPEC were corrected, and all three
canonical backtest set hashes were sealed. Risk remains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## Verification

- Strict compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `framework/build/compile/20260818_050010/QM5_39008_forexfactory-symphonie-matrix-system.compile.log`.
- Compile summary: `D:/QM/reports/compile/20260818_050010/summary.csv`.
- Strict targeted build check: PASS, 0 failures, 0 warnings.
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260818_050038.json`.
- Build guardrails: PASS, four files checked, no findings.
- SPEC validation: PASS (1/1).
- Forbidden direct indicator/runtime/ML scan: no hits.
- MQ5 SHA-256:
  `ada71a307546e324446741fd1eb7f3edf2de3b70150e6cf2ef43f72171296f54`.
- EX5 SHA-256:
  `74d0fe189fbc5198be669ffb19e4afe213575533846bf1a81a785589b32359be`.
- Build-check report SHA-256:
  `df34ec7b30dea956790d67de7c5c848abffdc93cb09aaa789b50861288841c7f`.

Structured results:

- `artifacts/builds/edbb12cd-1198-421e-a029-738fe8b825be.json`
- `artifacts/reviews/b7c633a4-8c76-4aee-ad4e-dfef517bbace.json`

The legacy approved card predates the current heading-only extraction lint;
that lint reports missing literal `## hypothesis`, `## rules`, and `## risk`
headings even though the approved body contains thesis, exact rules, and risk
sections. No OWNER-governed G0 artifact was rewritten in this build/review unit.

## Binding CPU stop

At `2026-08-18T05:01:03Z`, the supported path-aware census found six occupied
factory terminals: `T1`, `T2`, `T4`, `T5`, `T6`, and `T7`. Five whole-host
CPU samples were `100%`, `100%`, `97%`, `100%`, and `100%` (average `99.4%`,
maximum `100%`). This meets the mission's hard backtest CPU ceiling.

No smoke tester, Q02 enqueue, dispatcher tick, terminal reservation, MT5
launch, or terminal control followed. `farmctl work-items --ea QM5_39008`
remained empty before this repair; the structured build result records the
sanctioned `deferred_p2_smoke` disposition for a saturated tester fleet.

## Safety

- No portfolio-admission, KPI, or Q08-contribution path changed.
- No `T_Live` manifest or terminal, AutoTrading state, or live artifact changed.
- Concurrent unrelated dirty-worktree files were left untouched.
