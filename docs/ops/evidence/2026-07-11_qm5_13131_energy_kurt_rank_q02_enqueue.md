# QM5_13131 XTI/XNG Historical-Kurtosis Q02 Enqueue Evidence

Date: 2026-07-11
Branch: `agents/board-advisor`
Actor: Codex paced fleet
Status: Q01 PASS; logical-basket Q02 pending

## Outcome

Built and enqueued one new low-frequency market-neutral commodity/energy
sleeve: `QM5_13131_energy-kurt-rank`. Once per broker month, the EA calculates
Pearson historical kurtosis from each leg's prior 252 completed D1 returns,
buys the higher-kurtosis energy leg, shorts the lower-kurtosis leg, and holds
the package until the next month transition. Fixed package risk is split
equally.

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
  and instrument membership.
- Source packet: `strategy-seeds/sources/HOLLSTEIN-MAX-2021/source.md`.
- Canonical card: `strategy-seeds/cards/energy-kurt-rank_card.md`.
- Approved fleet card:
  `artifacts/cards_approved/QM5_13131_energy-kurt-rank.md`.
- R1/R2/R3/R4: PASS/PASS/PASS/PASS.
- G0 schema/ML lint: PASS with zero ML hits.

The source's full-sample tercile historical-kurtosis spread is positive, but
its directly relevant two-portfolio result and Fama-MacBeth slope are
statistically insignificant. Its December 2000-December 2015
post-financialization spread reverses sign and is insignificant. The QM 2017+
baseline is therefore a genuine out-of-sample falsification. The paper ranks
at least six collateralized futures; this EA ranks two continuous CFDs. Those
are kill risks, not assumed waivers.

## Mechanic And Non-Duplicate Evidence

For each leg, with exactly 252 simple D1 returns:

`kurtosis = mean((r - mean(r))^4) / sample_variance(r)^2`.

The source's full-sample relation fixes the direction: buy the higher-kurtosis
leg and short the lower-kurtosis leg for one broker month.

- `QM5_13118_energy-skew-rank` uses the third moment and low-skew direction.
- `QM5_13129_energy-rsj` uses one completed month of signed semivariance.
- `QM5_13130_xti-xng-lowmax` averages only the five largest upside returns and
  buys the lower-MAX leg.
- `QM5_1212_carver-kurtsabs` and `QM5_1221_carver-kurtsrv` use skew-conditioned
  daily forecasts with volatility scaling and smoothing.
- `QM5_10322_realized-moments` is a weekly H1 composite rather than a pure
  monthly D1 cross-sectional rank.

Pre-allocation command:

`python framework/scripts/research_dedup_check.py check --slug energy-kurt-rank --strategy-id HOLLSTEIN-MAX-2021_XTI_XNG_S02 --author "Hollstein Prokopczuk Tharann" --mechanic "monthly XTI XNG market neutral cross sectional historical Pearson kurtosis rank prior 252 completed simple D1 returns buy higher kurtosis sell lower kurtosis one month hold equal fixed risk"`

The tool required fuzzy review because the strategy ID shares its approved
paper with `QM5_13130`; mechanic similarity was zero. Manual repository review
of formulas, direction, inputs, cadence, and exits returned
`CLEAN_AFTER_MANUAL_REVIEW` before allocating `QM5_13131`.

As expected, a post-allocation rerun reports an exact match against the new
`13131` registry row itself. `HEAD` before this change contains no `13131` row;
the self-match is not a second implementation.

## Registry Evidence

- EA registry:
  `13131,energy-kurt-rank,HOLLSTEIN-MAX-2021_XTI_XNG_S02,active`.
- Magic slot 0: `XTIUSD.DWX -> 131310000`.
- Magic slot 1: `XNGUSD.DWX -> 131310001`.
- `QM_MagicResolver.mqh` was regenerated and contains both values.

Resolver generation retained the repository's three pre-existing
missing-directory warnings for IDs `1001`, `1015`, and `1016`; no `13131`
defect remained.

## Q01 Build Evidence

- EA source:
  `framework/EAs/QM5_13131_energy-kurt-rank/QM5_13131_energy-kurt-rank.mq5`.
- Compiled artifact:
  `framework/EAs/QM5_13131_energy-kurt-rank/QM5_13131_energy-kurt-rank.ex5`.
- Compile result: PASS, 0 errors, 0 compiler warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260711_024905/QM5_13131_energy-kurt-rank.compile.log`.
- Build check: PASS, 0 failures, 0 warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260711_024905.json`.
- SPEC validator: PASS.
- Build prerequisite guard: PASS.
- Guardrail validator: PASS.
- Symbol scope: `BASKET_OK`, 0 violations.
- MQ5 SHA256:
  `db37c9f31644a683635215884733a56ea7357995238da8e0be87c959eb4dac93`.
- EX5 SHA256:
  `040bfc0cbb46389df351d5462be6c293c33d23c00ee466353219154c3ff1d96a`.

## Risk And Setfile Evidence

- Logical symbol: `QM5_13131_XTI_XNG_HKURT_D1`.
- Host: `XTIUSD.DWX`, D1.
- Basket symbols: `XTIUSD.DWX`, `XNGUSD.DWX`.
- Setfile:
  `framework/EAs/QM5_13131_energy-kurt-rank/sets/QM5_13131_energy-kurt-rank_QM5_13131_XTI_XNG_HKURT_D1_D1_backtest.set`.
- Setfile SHA256:
  `f78a0e9ddf4ba60d8090cc55d0930472dd469a8df3af2403f6652016a4344aef`.
- `RISK_FIXED=1000`.
- `RISK_PERCENT=0`.
- `PORTFOLIO_WEIGHT=1`.
- Friday close is disabled only for the source-aligned monthly holding period.
- Each leg receives half package risk, a frozen `ATR(20) * 3.5` hard stop,
  orphan cleanup, and a 35-day stale-package guard.

## Q02 Queue Evidence

- Build task: `c844ea38-89c8-45d3-9cd9-29f422a49722` (`done`).
- Work item: `4697672b-b54a-46b9-979a-12cff2d1e578`.
- Phase: `Q02`.
- Kind: `backtest`.
- Symbol: `QM5_13131_XTI_XNG_HKURT_D1`.
- Status at verification: `pending`.
- Attempt count: `0`.
- Claimed by: none.
- Enqueued at: `2026-07-11T02:46:13+00:00`.
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
