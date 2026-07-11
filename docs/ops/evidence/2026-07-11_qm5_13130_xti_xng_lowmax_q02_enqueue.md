# QM5_13130 XTI/XNG Low-MAX Q02 Enqueue Evidence

Date: 2026-07-11
Branch: `agents/board-advisor`
Actor: Codex paced fleet
Status: Q01 PASS; logical-basket Q02 pending

## Outcome

Built and enqueued one new low-frequency market-neutral commodity/energy
sleeve: `QM5_13130_xti-xng-lowmax`. Once per broker month, the EA averages
each leg's five largest daily returns from the prior 252 completed D1 returns,
buys the lower-MAX energy leg, shorts the higher-MAX leg, and holds the package
until the next month transition. Fixed package risk is split equally.

This is an out-of-sample Q02 candidate, not a certified portfolio admission.
No decorrelation result, source performance transfer, or live readiness is
claimed.

## Source And Card Evidence

- Sole primary source: Hollstein, Fabian; Prokopczuk, Marcel; and Tharann,
  Bjoern (2021), "Anomalies in Commodity Futures Markets," *Quarterly Journal
  of Finance* 11(4), article 2150017, DOI
  `10.1142/S2010139221500178`.
- Institutional accepted manuscript:
  `https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf`.
- The complete 57-page accepted article and online appendix were read end to
  end, including methodology, portfolio splits, subperiods, robustness tables,
  annual holds, and instrument membership.
- Source packet: `strategy-seeds/sources/HOLLSTEIN-MAX-2021/source.md`.
- Canonical card: `strategy-seeds/cards/xti-xng-lowmax_card.md`.
- Approved fleet card:
  `artifacts/cards_approved/QM5_13130_xti-xng-lowmax.md`.
- R1/R2/R3/R4: PASS/PASS/PASS/PASS.
- G0 card lint: PASS; schema/ML lint: PASS with zero ML hits.

The source's full-sample MAX hedge and its full-sample two-portfolio split are
both statistically insignificant. Only the December 2000-December 2015
post-financialization subsample supports the negative MAX direction. The QM
2017+ baseline is therefore a genuine out-of-sample falsification. The paper
ranks a broad collateralized-futures cross-section; this EA narrows the
mechanic to two continuous CFDs. Those are kill risks, not assumed waivers.

## Mechanic And Non-Duplicate Evidence

For each leg:

`MAX = arithmetic_mean(five_largest(simple_D1_returns over 252 observations))`.

The modern-subsample relation fixes the direction: buy the lower-MAX leg and
short the higher-MAX leg for one broker month.

- `QM5_12567_cum-rsi2-commodity`: short-horizon RSI pullback; no overlap.
- `QM5_12733`, `QM5_12840`, `QM5_12850`, and `QM5_13089`: relative
  momentum, return-spread z-score, volatility-contraction breakout, and carry.
- `QM5_13113`, `QM5_13115`, `QM5_13118`, `QM5_13120`, `QM5_13121`,
  `QM5_13123`, and `QM5_13126`: residual volatility, same-calendar return,
  skewness, reversal, trend, value, and momentum/carry agreement.
- `QM5_13129_energy-rsj`: one completed month of signed semivariance. This
  sleeve uses only the five largest returns over 252 observations and does not
  use downside semivariance.

Pre-allocation command:

`python framework/scripts/research_dedup_check.py check --slug xti-xng-lowmax --strategy-id HOLLSTEIN-MAX-2021_XTI_XNG_S01 --author "Hollstein Prokopczuk Tharann" --mechanic "monthly XTI XNG market neutral cross sectional post financialization MAX rank average five largest daily returns over prior 252 D1 observations buy lower MAX sell higher MAX one month hold equal fixed risk"`

Verdict: `CLEAN`.

## Registry Evidence

- EA registry:
  `13130,xti-xng-lowmax,HOLLSTEIN-MAX-2021_XTI_XNG_S01,active`.
- Magic slot 0: `XTIUSD.DWX -> 131300000`.
- Magic slot 1: `XNGUSD.DWX -> 131300001`.
- `QM_MagicResolver.mqh` was regenerated and contains both values.

Resolver generation retained the repository's three pre-existing
missing-directory warnings for IDs `1001`, `1015`, and `1016`; no `13130`
defect remained.

## Q01 Build Evidence

- EA source:
  `framework/EAs/QM5_13130_xti-xng-lowmax/QM5_13130_xti-xng-lowmax.mq5`.
- Compiled artifact:
  `framework/EAs/QM5_13130_xti-xng-lowmax/QM5_13130_xti-xng-lowmax.ex5`.
- Compile result: PASS, 0 errors, 0 compiler warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260711_012055/QM5_13130_xti-xng-lowmax.compile.log`.
- Build check: PASS, 0 failures, 0 warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260711_012055.json`.
- SPEC validator: PASS.
- Build prerequisite guard: PASS.
- Guardrail validator: PASS.
- Symbol scope: `BASKET_OK`, 0 violations.
- MQ5 SHA256:
  `71a6a14d82df396a37f8552fe8016e6e86dd10c4bd3be662355c30c52b79e5a2`.
- EX5 SHA256:
  `443302394d71feeb8d91d898d7be345fd77ac5ad8f7fdfbc36d5f0f0b8c62937`.

## Risk And Setfile Evidence

- Logical symbol: `QM5_13130_XTI_XNG_LOWMAX_D1`.
- Host: `XTIUSD.DWX`, D1.
- Basket symbols: `XTIUSD.DWX`, `XNGUSD.DWX`.
- Setfile:
  `framework/EAs/QM5_13130_xti-xng-lowmax/sets/QM5_13130_xti-xng-lowmax_QM5_13130_XTI_XNG_LOWMAX_D1_D1_backtest.set`.
- Setfile SHA256:
  `41ad2993e9a593cffcbed4be1cecb80de18adf6de7d5f8a488fc154109a08d31`.
- `RISK_FIXED=1000`.
- `RISK_PERCENT=0`.
- `PORTFOLIO_WEIGHT=1`.
- Friday close is disabled only for the source-aligned monthly holding period.
- Each leg receives half package risk, a frozen `ATR(20) * 3.5` hard stop,
  orphan cleanup, and a 35-day stale-package guard.

## Q02 Queue Evidence

- Build task: `26d3f077-c4c7-4fb9-babc-997d8f53cc3d` (`done`).
- Work item: `d96cc22a-4825-4d48-9ca3-0253cf3c4ac5`.
- Phase: `Q02`.
- Kind: `backtest`.
- Symbol: `QM5_13130_XTI_XNG_LOWMAX_D1`.
- Status at verification: `pending`.
- Attempt count: `0`.
- Enqueued at: `2026-07-11T01:17:32+00:00`.
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
