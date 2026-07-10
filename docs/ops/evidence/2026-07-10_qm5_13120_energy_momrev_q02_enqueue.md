# QM5_13120 Energy Momentum-Reversal Build And Q02 Enqueue

Date: 2026-07-10
Branch: `agents/board-advisor`
Outcome: strict build PASS; one logical-basket Q02 work item enqueued pending.

## Edge Selected

`QM5_13120_energy-momrev` is a low-frequency market-neutral XTI/XNG package.
At the first tradable D1 bar of each broker month it reconstructs synchronized
completed month-end closes, ranks XTI and XNG by 12-month and 18-month log
returns, and trades only when those rankings disagree:

- long the 12-month winner / 18-month loser;
- short the 12-month loser / 18-month winner;
- flat when both horizons agree, either rank ties, or an endpoint fails.

The package closes at the next month transition, has a 35-day stale guard,
splits `RISK_FIXED=1000` equally across both legs, and gives each leg a frozen
`ATR(20) * 3.5` broker stop. Friday close is disabled only to preserve the
source's one-month holding period.

## Reputable Source And Translation Boundary

Primary source: Bianchi, Robert J.; Drew, Michael E.; and Fan, John Hua
(2015), "Combining Momentum with Reversal in Commodity Futures", *Journal of
Banking & Finance* 59, 423-444, DOI
https://doi.org/10.1016/j.jbankfin.2015.07.006.

The complete 59-page accepted manuscript from the Griffith University
Research Repository was reviewed. The paper tests a 27-future cross-section
and an independent 26-contract dataset. Its strongest reported combination is
the 12-month momentum first sort with an 18-month contrarian second sort, no
skipped month, and a one-month hold.

This build is not presented as a source replication. Reducing extreme groups
from a broad futures cross-section to two Darwinex energy CFDs can reduce both
signal density and diversification, and it does not reproduce roll, collateral,
or term-structure economics. The paper's low correlations motivate Q09; they
do not establish this carrier's correlation.

## Non-Duplicate Gate

Repository-wide exact search was clean for the 12/18 opposite-rank rule.
The mechanic differs from:

- `QM5_12567`: RSI(2) long-only commodity pullback;
- `QM5_12623`: single-XAU 3-month trend with 4-week confirmation;
- `QM5_12733`: raw XTI/XNG 126-D1 relative momentum rank;
- `QM5_12840`: XTI/XNG return-spread z-score fade;
- `QM5_13089`: XTI/XNG carry/swap rank;
- `QM5_13113`: momentum plus residual-volatility agreement;
- `QM5_13115`: same-calendar-month return seasonality;
- `QM5_13118`: realized-skewness rank.

No RSI, MACD, COT, inventory, weather, external feed, ML, adaptive PnL fit,
grid, martingale, pyramiding, or post-hoc entry threshold is present.

## Identity And Artifacts

- EA ID: `QM5_13120`; strategy ID:
  `BIANCHI-MOMREV-2015_XTI_XNG_S01`.
- Source packet:
  `strategy-seeds/sources/BIANCHI-MOMREV-2015/source.md`.
- Approved card:
  `strategy-seeds/cards/approved/QM5_13120_energy-momrev_card.md`.
- EA: `framework/EAs/QM5_13120_energy-momrev/QM5_13120_energy-momrev.mq5`.
- SPEC: `framework/EAs/QM5_13120_energy-momrev/SPEC.md`.
- Basket manifest:
  `framework/EAs/QM5_13120_energy-momrev/basket_manifest.json`.
- Fixed-risk setfile:
  `framework/EAs/QM5_13120_energy-momrev/sets/QM5_13120_energy-momrev_QM5_13120_ENERGY_MOMREV_D1_D1_backtest.set`.
- Build result: `artifacts/qm5_13120_build_result.json`.
- Magics: `131200000` XTI slot 0; `131200001` XNG slot 1.

## Validation

- Strategy-card schema lint: PASS; no ML hits or missing sections.
- SPEC validator: PASS.
- Symbol-scope validator: `BASKET_OK`, zero violations.
- Build guardrails: PASS, zero findings.
- Magic resolver regeneration: PASS; both 13120 rows present in generated
  resolver. The skill-named `verify_magic_registry.py` is absent on this
  branch, so CSV/resolver presence was checked directly.
- Strict MetaEditor compile: PASS, 0 errors, 0 warnings.
- Strict integrated `build_check.ps1 -SkipCompile`: PASS, 0 failures,
  0 warnings; report
  `D:/QM/reports/framework/21/build_check_20260710_163925.json`.
- EX5 SHA-256:
  `5b8e59f5a50af8786f19b32874589a0369c20eb0201372a53779aee7021ce7e5`.
- Setfile contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; no live setfile exists.

## Q02 Queue And CPU Ceiling

The canonical build record auto-enqueued exactly one logical-basket work item:

- work item: `24943b6e-5388-4c4c-9e75-b7b2bad0c02f`;
- phase/status: `Q02` / `pending`;
- logical symbol: `QM5_13120_ENERGY_MOMREV_D1`;
- timeframe: D1;
- attempt count: 0; claimed by: none.

At enqueue preflight the farm reported seven active work items, exactly the
paced-fleet CPU ceiling. Therefore no manual smoke, dispatch tick, or extra MT5
tester was started. Q02 remains pending for the existing fleet. The card's
hard density rule is retirement below five completed packages/year; the gate
must not be loosened to rescue a sparse result.

No `T_Live`, AutoTrading setting, deploy manifest, portfolio gate, portfolio
admission, or portfolio KPI path was touched.
