# QM5_13129 Energy RSJ Q02 Enqueue Evidence

Date: 2026-07-11
Branch: `agents/board-advisor`
Actor: Codex paced fleet
Status: Q01 PASS; logical-basket Q02 pending

## Outcome

Built and enqueued one new low-frequency market-neutral commodity/energy
sleeve: `QM5_13129_energy-rsj`. The EA calculates each leg's normalized
relative signed jump from the immediately preceding complete month of daily
returns, buys the lower-RSJ energy leg, shorts the higher-RSJ leg, and holds
the pair until the next month transition. Fixed package risk is split equally.

This is a Q02 candidate, not a certified portfolio admission. No portfolio
correlation, source performance transfer, or live readiness is claimed.

## Source And Card Evidence

- Sole primary source: Kiss, Tamas, and Igor Ferreira Batista Martins (2025),
  "Good Volatility, Bad Volatility and the Cross Section of Commodity Returns,"
  *Finance Research Letters* 86, Part D, article 108656, DOI
  `10.1016/j.frl.2025.108656`.
- Open published manuscript:
  `https://www.diva-portal.org/smash/get/diva2%3A2013183/FULLTEXT01.pdf`.
- The complete 12-page publication was read end to end, including all tables
  and appendices.
- Source packet: `strategy-seeds/sources/KISS-RSJ-2025/source.md`.
- Canonical card: `strategy-seeds/cards/energy-rsj_card.md`.
- Approved fleet card:
  `artifacts/cards_approved/QM5_13129_energy-rsj.md`.
- R1/R2/R3/R4: PASS/PASS/PASS/PASS.
- G0 card lint: PASS; schema/ML lint: PASS with zero ML hits.

The source uses daily returns on 36 collateralized commodity futures and forms
monthly extreme portfolios. WTI and natural gas are explicit source members.
The EA narrows that design to two continuous CFDs and equal fixed-risk legs;
this translation is a falsification risk rather than an assumed equivalence.

## Mechanic And Non-Duplicate Evidence

For each leg in the prior complete broker month:

`RSJ = (sum(r^2 where r>0) - sum(r^2 where r<0)) / sum(r^2)`.

The source documents a negative RSJ premium, so the EA buys the lower-RSJ leg
and shorts the higher-RSJ leg for one month.

- `QM5_12567_cum-rsi2-commodity`: short-horizon RSI pullback; no overlap.
- `QM5_12733`, `QM5_12840`, `QM5_12850`, and `QM5_13089`: relative
  momentum, return-spread z-score, volatility-contraction breakout, and carry.
- `QM5_13113`, `QM5_13115`, `QM5_13120`, `QM5_13121`, `QM5_13123`, and
  `QM5_13126`: momentum-IVol, same-calendar return, reversal, trend, value,
  and momentum/carry agreement rather than RSJ.
- `QM5_13118_energy-skew-rank`: estimates a 12-month third standardized moment.
  QM5_13129 separates positive and negative squared returns over one month;
  the primary paper's factor and spanning tests explicitly distinguish RSJ
  from realized skewness.

Pre-allocation command:

`python framework/scripts/research_dedup_check.py check --slug energy-rsj --strategy-id KISS-RSJ-2025_XTI_XNG_S01 --author "Kiss Ferreira Batista Martins" --mechanic "monthly XTI XNG market neutral cross sectional relative signed jump rank from one completed month daily returns RSJ equals upside semivariance minus downside semivariance divided by total variance buy lower RSJ sell higher RSJ one month hold equal fixed risk"`

Verdict: `CLEAN`.

## Registry Evidence

- EA registry:
  `13129,energy-rsj,KISS-RSJ-2025_XTI_XNG_S01,active`.
- Magic slot 0: `XTIUSD.DWX -> 131290000`.
- Magic slot 1: `XNGUSD.DWX -> 131290001`.
- `QM_MagicResolver.mqh` was regenerated and contains both values.

Resolver generation retained the repository's three pre-existing
missing-directory warnings for IDs `1001`, `1015`, and `1016`; no `13129`
defect remained.

## Q01 Build Evidence

- EA source:
  `framework/EAs/QM5_13129_energy-rsj/QM5_13129_energy-rsj.mq5`.
- Compiled artifact:
  `framework/EAs/QM5_13129_energy-rsj/QM5_13129_energy-rsj.ex5`.
- Compile result: PASS, 0 errors, 0 compiler warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260710_233037/QM5_13129_energy-rsj.compile.log`.
- Build check: PASS, 0 failures, 0 warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260710_233037.json`.
- SPEC validator: PASS.
- Build prerequisite guard: PASS.
- Symbol scope: `BASKET_OK`, 0 violations.
- MQ5 SHA256:
  `8f7a41cc4b8cdb86a5e88fb8ca52fdc3c9cedb038e1fccf73e11b41ee53813f0`.
- EX5 SHA256:
  `cc0109d18736189d1e9b6c84b9c4259133b9d13a1a8ab31f42f006e53fe79a7f`.

## Risk And Setfile Evidence

- Logical symbol: `QM5_13129_ENERGY_RSJ_D1`.
- Host: `XTIUSD.DWX`, D1.
- Basket symbols: `XTIUSD.DWX`, `XNGUSD.DWX`.
- Setfile:
  `framework/EAs/QM5_13129_energy-rsj/sets/QM5_13129_energy-rsj_QM5_13129_ENERGY_RSJ_D1_D1_backtest.set`.
- `RISK_FIXED=1000`.
- `RISK_PERCENT=0`.
- `PORTFOLIO_WEIGHT=1`.
- Friday close is disabled only for the source-aligned monthly holding period.
- Each leg receives half package risk, a frozen `ATR(20) * 3.5` hard stop,
  orphan cleanup, and a 35-day stale-package guard.

## Q02 Queue Evidence

- Build task: `040412e6-1b99-4127-9e35-7b326c4a230b` (`done`).
- Work item: `9d4fe6ed-97fc-41d0-9b81-3466cef8d53c`.
- Phase: `Q02`.
- Kind: `backtest`.
- Symbol: `QM5_13129_ENERGY_RSJ_D1`.
- Status at verification: `pending`.
- Attempt count: `0`.
- Enqueued at: `2026-07-10T23:31:57+00:00`.
- Queue path: `record_build_result.auto_q02`.
- Basket manifest: two traded symbols, host `XTIUSD.DWX`, timeframe D1.

No manual smoke, backtest, terminal launch, or dispatch tick was started.
Read-only slot inspection showed existing activity on T1 and T3; the new Q02
item was left pending for paced dispatch. No backtest CPU ceiling was consumed
or encountered by this build turn.

## Safety Boundary

- No T_Live path changed.
- No AutoTrading setting changed.
- No live setfile or deploy manifest created.
- No portfolio gate, gate threshold, portfolio KPI, or admission file changed.
