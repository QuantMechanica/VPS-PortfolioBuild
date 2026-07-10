# QM5_13123 Energy Value Q02 Enqueue Evidence

Date: 2026-07-10
Branch: `agents/board-advisor`
Actor: Codex paced fleet
Status: Q01 PASS; logical-basket Q02 pending

## Outcome

Built and enqueued one new low-frequency commodity/energy sleeve:
`QM5_13123_energy-val-rank`. The EA trades a paired XTI/XNG package once per
broker month. It buys the leg with the higher log ratio of its average
54-through-66-month historical price anchor to its latest completed price and
sells the lower-value leg. Fixed package risk is split equally.

This is a new pure commodity-value mechanic, not a renamed momentum, reversal,
carry, seasonality, skew, RSI, or recent-spread EA. The repository dedup helper
returned `CLEAN` before atomic ID allocation.

## Source And Card Evidence

- Primary source: Asness, Moskowitz, and Pedersen (2013), "Value and Momentum
  Everywhere", *The Journal of Finance* 68(3), 929-985, DOI
  https://doi.org/10.1111/jofi.12021.
- Full 57-page paper and complete 11-page Internet Appendix read end to end.
- Source packet: `strategy-seeds/sources/AMP-VALUE-2013/source.md`.
- Canonical card: `strategy-seeds/cards/energy-val-rank_card.md`.
- Approved fleet card:
  `artifacts/cards_approved/QM5_13123_energy-val-rank.md`.
- R1/R2/R3/R4: PASS/PASS/PASS/PASS.

The source uses 27 commodity futures, including WTI and natural gas. The card
preserves the 4.5-to-5.5-year commodity-value definition and cross-sectional
long-short direction, while treating completed Darwinex CFD D1 closes as an
explicitly falsifiable spot proxy. No source performance is imported.

## Non-Duplicate Evidence

- `QM5_12567_cum-rsi2-commodity`: short RSI pullback; no overlap.
- `QM5_12733_xti-xng-xmom`: 12-month relative momentum.
- `QM5_12840_xti-xng-rspread`: recent return-spread z-score fade.
- `QM5_12895_xng-6m-reversal` and `QM5_12979_wti-6m-reversal`: single-leg
  medium-horizon reversal rather than a paired 54-66-month value rank.
- `QM5_13089_xti-xng-carry`: swap/carry rank.
- `QM5_13113`, `QM5_13115`, `QM5_13118`, `QM5_13120`, and `QM5_13121`:
  residual volatility, same-calendar history, skew, momentum/reversal
  disagreement, and trend-confirmed momentum respectively.
- `QM5_12919_amp-value-momentum-xasset`: combined value/momentum on an
  index/FX universe that excludes commodities; it uses one 60-month endpoint,
  not the source's 54-66-month commodity anchor average.

Pre-allocation command:

`python framework/scripts/research_dedup_check.py check --slug energy-val-rank --strategy-id AMP-VALUE-2013_XTI_XNG_S01 --author "Asness Moskowitz Pedersen" --mechanic "monthly XTI XNG cross-sectional commodity value log average 54-66 month completed price anchors over latest completed price long higher short lower equal fixed risk"`

Verdict: `CLEAN`.

## Registry Evidence

- EA registry:
  `13123,energy-val-rank,AMP-VALUE-2013_XTI_XNG_S01,active`.
- Magic slot 0: `XTIUSD.DWX -> 131230000`.
- Magic slot 1: `XNGUSD.DWX -> 131230001`.
- `QM_MagicResolver.mqh` was regenerated from `magic_numbers.csv` and contains
  both new values.

Targeted card, registry, magic, build, and symbol-scope checks pass. Resolver
generation retained the repository's three pre-existing missing-directory
warnings for IDs `1001`, `1015`, and `1016`; no `13123` defect was reported.

## Q01 Build Evidence

- EA source:
  `framework/EAs/QM5_13123_energy-val-rank/QM5_13123_energy-val-rank.mq5`.
- Compiled artifact:
  `framework/EAs/QM5_13123_energy-val-rank/QM5_13123_energy-val-rank.ex5`.
- Compile result: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260710_195628/QM5_13123_energy-val-rank.compile.log`.
- Build check: PASS, 0 failures, 0 warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260710_195637.json`.
- Card schema: PASS; no ML hits.
- SPEC validator: PASS.
- Build guardrails: PASS.
- Symbol scope: `BASKET_OK`.
- MQ5 SHA256:
  `bd1da501f08c870147f278263630a7f7baac20f26092789419718f5255e7218b`.
- EX5 SHA256:
  `0560a992ab3002916d6751f6d92bc32cdd9ca1d6557a030f7308a445088580f0`.

## Risk And Setfile Evidence

- Logical symbol: `QM5_13123_ENERGY_VALUE_D1`.
- Host: `XTIUSD.DWX`, D1.
- Basket symbols: `XTIUSD.DWX`, `XNGUSD.DWX`.
- Setfile:
  `framework/EAs/QM5_13123_energy-val-rank/sets/QM5_13123_energy-val-rank_QM5_13123_ENERGY_VALUE_D1_D1_backtest.set`.
- `RISK_FIXED=1000`.
- `RISK_PERCENT=0`.
- `PORTFOLIO_WEIGHT=1`.
- Friday close is disabled only for the source-aligned monthly holding period.
- Each leg has half package risk, a frozen `ATR(20) * 3.5` hard stop, orphan
  cleanup, and a 35-day stale-package guard.

## Q02 Queue Evidence

- Build task: `b74b448b-22ce-4a92-9574-4216f6847f52` (`done`).
- Work item: `f50a1355-50ff-4637-a4f8-c482adc5abee`.
- Phase: `Q02`.
- Kind: `backtest`.
- Symbol: `QM5_13123_ENERGY_VALUE_D1`.
- Status at verification: `pending`.
- Attempt count: `0`.
- Enqueued at: `2026-07-10T19:50:44+00:00`.
- Queue path: `record_build_result.auto_q02`.
- Basket manifest: two symbols, host `XTIUSD.DWX`, timeframe D1.

No manual smoke/backtest was started. T3 and T7 were already occupied when
the fleet ceiling was checked, so the new Q02 item was left pending for paced
dispatch.

## Safety Boundary

- No T_Live path changed.
- No AutoTrading setting changed.
- No live setfile or deploy manifest created.
- No portfolio gate or portfolio admission file changed.
- No gate threshold changed.
