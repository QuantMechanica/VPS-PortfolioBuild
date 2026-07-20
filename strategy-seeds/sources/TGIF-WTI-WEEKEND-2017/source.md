---
source_id: TGIF-WTI-WEEKEND-2017
title: TGIF? The weekend effect in energy commodities
publisher: Journal of Finance Issues
source_type: academic_paper
status: approved
created: 2026-06-28
created_by: Codex
approved_by: OWNER commodity-sleeve mission
approved_at: 2026-07-20
uri: https://jfi-aof.org/index.php/jfi/article/view/2264
open_full_text_url: https://jfi-aof.org/index.php/jfi/article/download/2264/1847
cards_extracted:
  - wti-weekend-gap-fade
  - wti-weekend-gap-bounce
  - xti-xng-mon-rv
---

# TGIF Energy Weekend Source

## Source Identity

- Publisher: Journal of Finance Issues
- Primary source: "TGIF? The weekend effect in energy commodities", URL
  https://jfi-aof.org/index.php/jfi/article/view/2264
- PDF URL: https://jfi-aof.org/index.php/jfi/article/download/2264/1847

Hoelscher, Seth A., Cedric Mbanga and Walt A. Nelson (2017), "TGIF? The
Weekend Effect in Energy Commodities," *Journal of Finance Issues* 16(1),
47-68, DOI `10.58886/jfi.v16i1.2264`. The complete official 22-page article,
including every table, subperiod result, conclusion and reference, was read on
2026-07-20.

The journal paper is a named-author empirical study with public full text and
anonymous referee acknowledgement. It is treated as quality tier B: reputable
and peer reviewed, but neither an investable track record nor an elite-journal
result.

## Selected cross-energy finding

The authors calculate daily close-to-close spot returns from U.S. Energy
Information Administration series through May 2017 and estimate Monday and
Friday indicator regressions using White-Huber OLS, three robust estimators,
and robust median regression. Table 1 reports only `0.1100` Pearson correlation
between WTI and Natural Gas Monday returns. This low historical spot-return
correlation motivates testing a paired carrier; it is not a promised Darwinex
correlation.

Across the full sample, Table 2 Panel C reports negative WTI Monday
coefficients in all five estimators (`-0.1474` to `-0.1989` percentage points),
with significance in every specification. Table 4 Panel C reports positive
Natural Gas Monday coefficients in all five estimators (`+0.3717` to
`+0.8263`), again significant in every specification. Table 5 shows that the
WTI effect is less stable: in 2007-2017 only basic OLS and median regression
remain significant. Table 7 shows the positive Gas Monday coefficient in both
subperiods and all but one estimator in 1997-2006, then all five estimators in
2007-2017.

The source therefore supports an explicit hypothesis that Monday Natural Gas
return minus Monday WTI return is positive. The paper does not itself backtest
a paired trade, prescribe sizing, stops, spreads, or a CFD execution time. The
one-package XTI/XNG implementation is a disclosed QM translation of two
oppositely signed results in the same synchronized study.

## Research Use

This source is used for structural lineage around weekday/weekend return
structure in energy commodities. Earlier QM extractions mechanize two
conditional one-sided WTI gap rules. The 2026-07-20 extraction instead tests
one unconditional cross-energy Monday relative-value package: short
`XTIUSD.DWX`, long `XNGUSD.DWX`, and flatten both at the next D1 boundary.

The implementation does not import the paper's performance claims into QM. It
uses the source only to justify a deterministic cross-sectional weekday
hypothesis, then requires Q02+ validation on synchronized Darwinex
`XTIUSD.DWX` and `XNGUSD.DWX` bars.

## Mechanization boundary

- Signal: broker-calendar Monday at the first D1-bar tick.
- Package: simultaneously short WTI and long Natural Gas.
- Exit: first tick of the next broker D1 bar, normally Tuesday.
- Hedge: target equal absolute USD notionals after broker volume rounding.
- Risk: one combined `RISK_FIXED` budget across two frozen ATR-stop legs.

The paper labels close-to-close returns by the ending weekday, so its Monday
observation includes the non-tradable weekend gap. A Monday-open CFD entry
cannot capture that gap. The carrier deliberately tests the executable Monday
session translation and records the timing mismatch as a falsification risk.
It may not be rescued after a weak result by moving entry to Friday, adding a
gap filter, selecting subperiods, or enabling either standalone leg.

## Reputable-source criteria

- R1: PASS (tier B). One peer-reviewed named-author paper, official landing
  page, complete public PDF, exact tables and data provenance.
- R2: PASS. Direction, weekday, next-boundary exit, 1:1 notional hedge,
  combined fixed risk, ATR stops, stale guard and failure repair are fully
  deterministic; QM additions are identified rather than source-attributed.
- R3: PASS. Both `.DWX` D1 carriers and a logical-basket tester path are
  registered locally; runtime requires no external data.
- R4: PASS. Calendar, native prices, ATR risk and position state only; no ML,
  banned indicator, grid, martingale, pyramid or adaptive PnL fit.

## Non-duplicate boundary

Repository dedup returned `CLEAN` for strategy
`TGIF-WTI-WEEKEND-2017_S03` and slug `xti-xng-mon-rv`. Earlier
`QM5_12596` and `QM5_12806` contain the respective standalone Monday legs,
but can hold either unhedged exposure independently. This extraction permits
neither leg alone: it is one jointly sized, jointly repaired, dollar-notional
neutral logical package. Existing XTI/XNG baskets use ratio, return-spread,
cross-momentum, carry, volatility, ranking or month-season rules rather than
this fixed one-session cross-sectional calendar differential.

## Guardrails

- Runtime uses Darwinex MT5 OHLC and broker calendar only.
- No external API calls, CSV feeds, futures curve, EIA inventory data, analyst
  forecast, discretionary override, or news scraping.
- No ML, adaptive PnL fitting, grid, or martingale.
- One position per registered leg magic and no intentional orphan package.
- No standalone-symbol test, live preset, T_Live/AutoTrading action, deploy
  manifest, portfolio gate change, or portfolio-admission claim.

## R-Rules

- R1 reputable source: PASS. Single academic-paper source with public URL.
- R2 mechanical: PASS. Fixed D1 Monday gap condition, ATR hard stop, gap-fill
  target, and deterministic time exit.
- R3 data available: PASS. XTIUSD.DWX exists in the DWX symbol matrix.
- R4 no ML/banned logic: PASS. Deterministic single-position calendar/gap
  sleeve.
