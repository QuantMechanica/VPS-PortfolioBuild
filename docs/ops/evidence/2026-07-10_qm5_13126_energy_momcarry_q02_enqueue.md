# QM5_13126 Energy Momentum-Carry Q02 Enqueue Evidence

Date: 2026-07-10
Branch: `agents/board-advisor`
Actor: Codex paced fleet
Status: Q01 PASS; logical-basket Q02 pending

## Outcome

Built and enqueued one new low-frequency commodity/energy sleeve:
`QM5_13126_energy-momcarry`. The EA trades a paired XTI/XNG package at most
once per broker month. It ranks both legs by synchronized last-completed-month
return and separately by broker long-minus-short swap carry, then opens only
when the two ranks agree. Fixed package risk is split equally.

This is a Q02 candidate, not a certified portfolio admission. No portfolio
correlation or source performance is claimed before downstream evidence.

## Source And Card Evidence

- Primary source: Fuertes, Miffre, and Rallis (2010), "Tactical Allocation in
  Commodity Futures Markets: Combining Momentum and Term Structure Signals",
  *Journal of Banking & Finance* 34(10), 2530-2548, DOI
  `10.1016/j.jbankfin.2010.04.009`.
- The complete 47-page accepted manuscript, including tables and appendices,
  was read end to end from City Research Online.
- Source packet: `strategy-seeds/sources/FMR-MOMTS-2010/source.md`.
- Canonical card: `strategy-seeds/cards/energy-momcarry_card.md`.
- Approved fleet card:
  `artifacts/cards_approved/QM5_13126_energy-momcarry.md`.
- R1/R2/R3/R4: PASS/PASS/PASS/PASS.

The paper observes front-end futures curves across 37 commodities. The EA has
only XTI/XNG CFDs and uses broker swap as an explicitly falsifiable proxy. The
`.DWX` tester exposes zero swap, so the Q02 setfile predeclares a fixed `+1`
carry rank and still requires independent one-month momentum agreement. Q02
therefore tests that conditional interaction, not historical carry variation.

## Non-Duplicate Evidence

- `QM5_12567_cum-rsi2-commodity`: short RSI pullback; no overlap.
- `QM5_12733_xti-xng-xmom`: raw 12-month relative momentum without carry.
- `QM5_13089_xti-xng-carry`: weekly carry-only rank with a 12-month adverse
  return guard; the new EA requires a last-completed-month momentum/carry
  agreement and renews monthly.
- `QM5_13121_energy-tfmom`: 12-month momentum plus a seven-month price-trend
  overlay and inverse-volatility weighting, not swap carry.
- `QM5_13113`, `QM5_13115`, `QM5_13118`, `QM5_13120`, and `QM5_13123`:
  residual volatility, same-calendar history, skewness, reversal, and value
  interactions rather than momentum/carry agreement.

Pre-allocation command:

`python framework/scripts/research_dedup_check.py check --slug energy-momcarry --strategy-id FMR-MOMTS-2010_XTI_XNG_S01 --author "Fuertes Miffre Rallis" --mechanic "monthly XTI XNG market neutral double screen rank one completed month momentum and broker native swap carry agreement buy winner high carry sell loser low carry one month hold equal fixed risk"`

Verdict: `CLEAN`.

## Registry Evidence

- EA registry:
  `13126,energy-momcarry,FMR-MOMTS-2010_XTI_XNG_S01,active`.
- Magic slot 0: `XTIUSD.DWX -> 131260000`.
- Magic slot 1: `XNGUSD.DWX -> 131260001`.
- `QM_MagicResolver.mqh` was regenerated and contains both values.

Resolver generation retained the repository's three pre-existing
missing-directory warnings for IDs `1001`, `1015`, and `1016`; no `13126`
defect remained.

## Q01 Build Evidence

- EA source:
  `framework/EAs/QM5_13126_energy-momcarry/QM5_13126_energy-momcarry.mq5`.
- Compiled artifact:
  `framework/EAs/QM5_13126_energy-momcarry/QM5_13126_energy-momcarry.ex5`.
- Compile result: PASS, 0 errors, 0 compiler warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260710_210355/QM5_13126_energy-momcarry.compile.log`.
- Build check: PASS, 0 failures, 4 advisory warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260710_210355.json`.
- The four advisories identify `.DWX` zero-swap behavior; the approved
  fixed-direction tester fallback resolves the zero-trade gate while keeping
  momentum agreement mandatory.
- Strategy-card lint: PASS; no ML hits.
- SPEC validator: PASS.
- Build prerequisite guard: PASS.
- Symbol scope: `BASKET_OK`.
- MQ5 SHA256:
  `d6cfd8f098d97cbdd771e199af6fceb272d41e3a6acf19aa5cdc12fdfedf46d8`.
- EX5 SHA256:
  `e0d93ade49841c1312991140ba1004495450eedd2232414d8c214a668719f960`.

## Risk And Setfile Evidence

- Logical symbol: `QM5_13126_ENERGY_MOMCARRY_D1`.
- Host: `XTIUSD.DWX`, D1.
- Basket symbols: `XTIUSD.DWX`, `XNGUSD.DWX`.
- Setfile:
  `framework/EAs/QM5_13126_energy-momcarry/sets/QM5_13126_energy-momcarry_QM5_13126_ENERGY_MOMCARRY_D1_D1_backtest.set`.
- `RISK_FIXED=1000`.
- `RISK_PERCENT=0`.
- `PORTFOLIO_WEIGHT=1`.
- Friday close is disabled only for the source-aligned monthly holding period.
- Each leg receives half package risk, a frozen `ATR(20) * 3.5` hard stop,
  orphan cleanup, and a 35-day stale-package guard.

## Q02 Queue Evidence

- Build task: `7e1aae76-0f35-421b-a172-6d41b2aba465` (`done`).
- Work item: `03354f53-f0a4-4d55-9193-d7badf2a83ce`.
- Phase: `Q02`.
- Kind: `backtest`.
- Symbol: `QM5_13126_ENERGY_MOMCARRY_D1`.
- Status at verification: `pending`.
- Attempt count: `0`.
- Enqueued at: `2026-07-10T21:07:23+00:00`.
- Queue path: `record_build_result.auto_q02`.
- Basket manifest: two traded symbols, host `XTIUSD.DWX`, timeframe D1.

No manual smoke or backtest was started. The factory scan reported no running
pipeline terminals, so the Q02 item was left pending for paced dispatch.

## Safety Boundary

- No T_Live path changed.
- No AutoTrading setting changed.
- No live setfile or deploy manifest created.
- No portfolio gate or portfolio admission file changed.
- No gate threshold changed.
