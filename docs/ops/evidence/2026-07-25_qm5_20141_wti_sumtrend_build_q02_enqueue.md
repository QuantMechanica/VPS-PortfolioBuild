# QM5_20141 WTI summer trend short — build and Q02 enqueue

Date: 2026-07-25 (Europe/Berlin)

Branch: `agents/board-advisor`

EA: `QM5_20141_wti-sumtrend`

Strategy ID: `EWALD-MOP-WTI-SUMTREND-2026_S01`

## Outcome

One new low-frequency structural WTI candidate was carded, registered, built,
strictly compiled, and handed to the paced pipeline. On the first tradable D1
bar of each broker week from July through November, it may open one WTI short
only when the completed 252-D1 WTI log return is strictly negative.

This is a Q02 research candidate, not a certified portfolio admission. No
profitability, decorrelation, or diversification result is claimed before the
governed pipeline produces evidence.

## Source And Claim Boundary

The approved composite source packet preserves two existing, completely read
repository lineages:

- Ewald, Haugom, Lien, Stordal, and Wu (2022), a peer-reviewed *Energy
  Economics* paper, supplies the WTI trading-time seasonal short direction.
  The QM carrier deliberately ends the fixed season in November so the paper's
  reported December offset is never traded short.
- Moskowitz, Ooi, and Pedersen (2012), a peer-reviewed *Journal of Financial
  Economics* paper, supplies the instrument-own completed 12-month
  return-sign state.

Neither paper tests their conjunction, the Darwinex continuous WTI CFD,
weekly fixed-risk renewal, the ATR stop, or QM portfolio behavior. Those are
explicit QM hypotheses. This work imported no new web claim. Runtime reads no
external feed, inventory, futures curve, COT, volume, open interest, analyst
forecast, CSV, API, or ML output.

## Non-Duplicate Boundary

Before allocation, the deterministic check scanned 4,198 EA-registry rows and
376 research cards and returned CLEAN. Manual semantic review resolved the
closest candidates:

- `QM5_13107_wti-weekly-season` trades the July-November weekly short without
  the slow trend gate.
- `QM5_12603_tsmom12m` trades a year-round symmetric 252-D1 trend without a
  fixed WTI seasonal window.
- `QM5_20135_wti-winter-trend` uses a monthly November-May symmetric trend
  package.
- `QM5_20093_wti-summer-short` is an unconditional summer short.
- `QM5_20136_wti-caltrend` estimates an adaptive same-calendar state and uses
  a completed 63-D1 trend.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback.

The load-bearing new state is the predeclared conjunction of a fixed
July-November weekly WTI short and a strictly negative completed 252-D1 WTI
return. Removing either component recreates an already-built parent mechanic.
Realized correlation remains a downstream Q09 and unchanged portfolio-gate
question.

## Frozen Baseline

- Host: exact `XTIUSD.DWX`, D1, slot 0, magic `201410000`
- Decision clock: first tradable D1 bar of each broker week
- Seasonal state: broker month July-November
- Trend state: strictly negative completed 252-D1 WTI log return
- Direction: short only; non-negative, invalid, or stale state remains flat
- Lifecycle: close an older-week, out-of-season, wrong-side, or seven-day stale
  position before considering a new package
- Risk control: frozen `3.0 * ATR(20)` hard stop; no take-profit or trailing
- Friday close: enabled at broker hour 21
- Entry spread ceiling: 1,500 points
- Attempt state: persist the broker-week key before fallible gates; no retry
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
- News axes: OFF

Only the locked baseline setfile was created. There is no parameter sweep,
live setfile, external signal, grid, martingale, scale-in, or pyramiding.

## Deterministic Identity And Hashes

- EA registry:
  `20141,wti-sumtrend,EWALD-MOP-WTI-SUMTREND-2026_S01`
- Magic registry:
  `20141,wti-sumtrend,0,XTIUSD.DWX,201410000`
- Card SHA-256:
  `F01885DD6F366F562F6A7B1638D93FD131DB41E44B2BBBC12E1A93CC62FF34BF`
- Source packet SHA-256:
  `CAAC9C70EFAA77F76999F927F3790E8E4A57A18303878F8BBD086B7624753E9C`
- MQ5 SHA-256:
  `5F555CAB6B3DB7EF837ECE956FD8463129C5BA8B2C6E75073E0F798F31934A10`
- EX5 SHA-256:
  `311D9D19C31E54F1FE7D9D9068055CF45A30CDFD841B8F469566FF74FDB620D7`
- SPEC SHA-256:
  `A3AF2D19605EC948C5711358AE3432BD6F7710F5398F4DB689FFCEEC13595F5C`
- Setfile SHA-256:
  `C056F90E13B2EACB4DACCF11429BFFE636B5C4B77BB28D8775EA4C1366354E69`
- EA-ID registry SHA-256:
  `B01731CB65486781376270561DE7E4BF4894F2DF822BB212D727365E25B27EDF`
- Magic registry SHA-256:
  `D339D90DF1F8BEC078745D51353ECF6029C84FF630D28B7DA7BA3636471A96A8`
- Generated resolver SHA-256:
  `27C445998184D902F5856C9B5391972533E1E77FC17573EB3F93370B3837C982`

The resolver was regenerated from the canonical registry after the EA
directory and magic row existed. Generated magic `201410000` was verified.

## Validation Evidence

- Strategy-card schema lint: PASS, no missing sections and no ML hits.
- G0 card lint: PASS.
- Seven-section SPEC validation: PASS.
- Candidate build guard: PASS; approved G0 card, EA registry, magic registry,
  exact folder, and exact slug agree.
- V5 build guardrails: PASS, 0 findings.
- V5 strict build check: PASS, 0 failures, 0 warnings.
- Strict MQL5 compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260725_071427/QM5_20141_wti-sumtrend.compile.log`
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260725_071427.json`

The execution contract deliberately remains DRAFT. A repository-wide
execution-contract lint still reports pre-existing live-book calendar/news and
promotion blocks unrelated to this candidate; this build neither edits nor
claims approval of that global live contract.

No manual smoke test or pipeline runner was started by this agent.

## Paced Q02 Handoff And Observed Result

- Build task: `9ec1daba-d13f-4ef9-9266-a8654e98d3c3`, status `done`
- Q02 work item: `a32fabb1-63c1-4ff9-abc1-8a6638709999`
- Phase/status: `Q02` / `done`
- Verdict: PASS
- Attempt count: 0
- Claimed by: none
- Created: `2026-07-25T07:19:26+00:00`
- Symbol/timeframe: `XTIUSD.DWX` / D1
- Setfile:
  `QM5_20141_wti-sumtrend_XTIUSD.DWX_D1_backtest.set`
- Initial auto-enqueue: exactly 1 enqueued, 0 skipped
- Read-only database recheck: exactly one canonical Q02 row for this EA/build
- Evidence:
  `D:/QM/reports/work_items/a32fabb1-63c1-4ff9-abc1-8a6638709999/QM5_20141/20260725_071952/summary.json`
- Model/window: Model 4, D1, `2018.07.02` through `2022.12.31`
- Observed baseline: 44 trades, PF 1.04, 3.36% drawdown, net +340.10
- Execution identity: source/deployed EX5 and setfile hashes matched and stayed
  stable; deterministic PASS; no OnInit or log-bomb failure

The paced fleet picked up Q02 immediately after enqueue and created downstream
Q04 work item `e0dcbc7a-a704-4f01-a94b-bf5e02d680a3`, observed pending and
unclaimed. This agent did not start Q04. Q02 PASS is only a baseline gate
result; it is not certification, correlation evidence, or portfolio admission.

At enqueue time the factory was active. Six pre-existing pipeline
`terminal64.exe` processes and the separate pre-existing `T_Live` terminal
were observed. This agent launched no tester; the paced worker fleet owned the
Q02 Model-4 run. The run completed, so this task did not hit the backtest CPU
ceiling.

During the post-enqueue metadata write, a second `record-build` call ran after
the canonical Q02 had already completed. Because that command's idempotency
predicate covers only pending/active rows, it created one new pending duplicate
Q02. The exact untouched row
`48150df0-c12b-4727-9859-0954c4a47bf8` (attempt 0, unclaimed, no evidence) was
deleted in a guarded SQLite transaction, and audit event
`duplicate_q02_removed` was written. The canonical PASS row above is the only
remaining Q02 row.

AutoTrading, the portfolio gate, the T_Live manifest, and all T_Live files
were not touched.
