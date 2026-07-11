# QM5_13139 Energy CV Rank - Q02 Enqueue Evidence

**Date:** 2026-07-11
**Branch:** `agents/board-advisor`
**EA:** `QM5_13139_energy-cv-rank`
**Strategy ID:** `SZYMANOWSKA-CV-2014_XTI_XNG_S01`

## Outcome

A new structural, low-frequency energy sleeve was carded, atomically allocated,
built, and left pending in Q02. The EA ranks XTI and XNG by 36-month
coefficient of variation every two months, buys the higher-CV leg, and shorts
the lower-CV leg with equal fixed-risk shares.

This differs mechanically from the book's existing XNG pullback exposure and
from the energy value, carry, momentum, beta, IVOL, skew, semivariance,
kurtosis, MAX, and variance-ratio builds. Portfolio decorrelation remains a Q09
measurement, not a build claim.

## Source And Card Evidence

- Canonical source: Szymanowska, de Roon, Nijman, and van den Goorbergh (2014),
  "An Anatomy of Commodity Futures Risk Premia," *The Journal of Finance*
  69(1), 453-482, DOI `10.1111/jofi.12096`.
- The complete 45-page paper, appendices, tables, and bibliography were read
  end to end.
- Source packet:
  `strategy-seeds/sources/SZYMANOWSKA-CV-2014/source.md`.
- Card of record: `strategy-seeds/cards/energy-cv-rank_card.md`.
- G0 and schema lints: PASS; R1-R4: PASS under the OWNER mission directive.
- Pre-allocation dedup: no exact slug, strategy-ID, or formula collision. The
  lexical `energy-val-rank` fuzzy hit was manually cleared because that EA
  ranks a multiyear price ratio rather than variance divided by mean.

## Locked Mechanic

1. On the first tradable XTI D1 bar of each odd-numbered broker month,
   reconstruct 37 completed consecutive month-end closes for XTI and XNG.
2. Form exactly 36 monthly log returns per leg.
3. Compute sample variance with denominator 35 and
   `CV = variance / abs(mean_return)`.
4. Buy the higher-CV leg and short the lower-CV leg.
5. Split `RISK_FIXED=1000` equally and apply a frozen D1
   `ATR(20) * 3.5` hard stop to each leg.
6. Close at the next odd-month transition or after 70 days; repair an orphan or
   invalid package immediately.
7. Use position and deal history to prevent a second package in the same
   two-month period after a restart or stop.

A missing calendar month, near-zero mean, nonpositive variance, numerical tie,
invalid arithmetic, excess spread, or incomplete package fails closed.

## Identity And Registry Evidence

- Atomic EA reservation:
  `13139,energy-cv-rank,SZYMANOWSKA-CV-2014_XTI_XNG_S01,active`.
- Magic slot 0: `XTIUSD.DWX -> 131390000`.
- Magic slot 1: `XNGUSD.DWX -> 131390001`.
- `QM_MagicResolver.mqh` was regenerated with 14,861 retained rows and contains
  both 13139 magic values.
- Resolver SHA256:
  `82E5059C869CE113DC562D6137314F08314B572B6874C753F64E69A730FE2D76`.

The resolver retained only the three pre-existing missing-directory warnings
for IDs 1001, 1015, and 1016. The full legacy registry validator continues to
report historical inventory defects unrelated to 13139; targeted registry,
resolver, compile, and build checks found no 13139 defect.

## Q01 Build Evidence

- EA source:
  `framework/EAs/QM5_13139_energy-cv-rank/QM5_13139_energy-cv-rank.mq5`.
- Compiled artifact:
  `framework/EAs/QM5_13139_energy-cv-rank/QM5_13139_energy-cv-rank.ex5`.
- Strict compile: PASS, 0 errors, 0 compiler warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260711_072050/QM5_13139_energy-cv-rank.compile.log`.
- Build check: PASS, 0 failures, 0 warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260711_072050.json`.
- Targeted SPEC validator: PASS.
- Build guardrails: PASS.
- Symbol-scope validator: `BASKET_OK`.
- MQ5 SHA256:
  `3EB41E81CF5F3C2DECE9FEDDC9786DFF3857ABB6227F73EAE8029BBA9F147DAD`.
- Clean staged-resolver reproducibility compile: PASS, 0 errors, 0 compiler
  warnings.
- EX5 SHA256:
  `D1567C048D560E46AB9E33CD959929060A1EE2FAC2B554C3DE4BD1DA0A17A0BD`.

## Risk And Setfile Evidence

- Logical symbol: `QM5_13139_XTI_XNG_CV_D1`; host `XTIUSD.DWX`, D1.
- Setfile:
  `framework/EAs/QM5_13139_energy-cv-rank/sets/QM5_13139_energy-cv-rank_QM5_13139_XTI_XNG_CV_D1_D1_backtest.set`.
- Setfile SHA256:
  `AA004642ADE81A129DAFBE6508304CB88761C7BD3E708F02F5182A538B3C62A4`.
- Setfile build hash:
  `3eb41e81cf5f3c2dece9feddc9786dff3857abb6227f73eae8029bba9f147dad`.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Friday close is disabled only for the source-aligned bimonthly hold.

## Q02 Queue Evidence

- Build task: `c0df5d27-fffb-4071-ac49-30cbab40b698` (`done`).
- Work item: `3d079ad8-6cde-4cf5-894f-2fc6d312fb05`.
- Phase: `Q02`; kind: `backtest`.
- Logical basket: `QM5_13139_XTI_XNG_CV_D1`.
- Host/timeframe: `XTIUSD.DWX`, D1.
- Status at verification: `pending`.
- Attempt count: `0`; claimed by: none.
- Enqueued at: `2026-07-11T07:24:50+00:00`.
- Queue path: `record_build_result.auto_q02`.

No manual smoke, tester, terminal launch, dispatch tick, worker tick, or
backtest was started. This work consumed no backtest CPU and left paced Q02
dispatch intact.

## Safety Boundary

- No T_Live path changed.
- No AutoTrading setting changed.
- No live setfile or deploy manifest was created.
- No portfolio gate, gate threshold, portfolio KPI, admission file, or T_Live
  manifest was changed.
