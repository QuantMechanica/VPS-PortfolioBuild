# QM5_20206 XAU/XAG Momentum–IVol G0 Authorization

Date: 2026-08-03

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch.

## Decision

Authorize one bounded V5 research card and non-live build for
`QM5_20206_xauxag-momivol`. On the first tradable `XAUUSD.DWX` D1 bar of a new
broker month, the candidate ranks XAU and XAG by synchronized completed 63-D1
momentum and by residual volatility from separate 63-return OLS regressions on
an equal-weight XTI/XNG/XAU/XAG commodity factor. It buys the higher-momentum
metal and shorts the lower-momentum metal only when the momentum winner is also
the lower-IVol metal. Rank disagreement, ties, or invalid state remains flat
for the consumed month.

The candidate may proceed through deterministic card lint, EA and magic
allocation, strict compile, one logical-basket `RISK_FIXED` backtest setfile,
and one paced Q02 enqueue. G0 does not pre-approve profitability, neutrality,
decorrelation, certification, or portfolio admission.

## Source Boundary

The governed packet is
`strategy-seeds/sources/FUERTES-MOMIVOL-2015/source.md`:

- Fuertes, Ana-Maria; Miffre, Joelle; and Fernandez-Perez, Adrian (2015),
  "Commodity Strategies Based on Momentum, Term Structure and Idiosyncratic
  Volatility," *Journal of Futures Markets* 35(3), 274-297, DOI
  `10.1002/fut.21656`.
- The complete open accepted manuscript is recorded as reviewed in the packet.
  Its momentum-IVol double screen, 3-month formation case, monthly hold,
  one-top/one-bottom sensitivity, and explicit gold/silver source membership
  bound this extraction.

The paper tests diversified commodity-futures portfolios. It does not test a
two-metal Darwinex CFD package, a four-CFD factor, fixed cash risk, paired
execution, hard stops, or the QM portfolio. No source performance or
correlation statistic transfers to the card.

## Non-Duplicate Decision

Before allocation, `research_dedup_check.py` scanned 4,262 EA registry rows and
385 cards. It found no exact duplicate and returned three expected fuzzy
neighbors requiring manual resolution:

- `QM5_13113_energy-mom-ivol` trades XTI/XNG; XAU/XAG are factor-only members.
- `QM5_20192_xauxag-ivol` uses a 252-D1 pure-IVol rank and has no momentum gate.
- `QM5_20184_xauxag-xmom3` uses the 63-D1 momentum rank and has no IVol gate.

The new candidate trades XAU/XAG only when its 63-D1 momentum and 63-D1 IVol
ranks agree. That conjunction and its flat disagreement regime are not built.
Existing ratio z-score, OLS residual-level, conditional-quantile, calendar,
pure momentum, pure IVol, and long-horizon reversal packages use different
information objects or lifecycle gates.

## Allocation

- EA ID: `QM5_20206`
- Slug: `xauxag-momivol`
- Strategy ID: `FUERTES-MOMIVOL-2015_XAU_XAG_S04`
- Magic slot 0: `XAUUSD.DWX` / `202060000`
- Magic slot 1: `XAGUSD.DWX` / `202060001`

## Safety Boundary

This authorization excludes live, demo, and shadow setfiles; `T_Live`;
AutoTrading; deploy or T_Live manifests; portfolio admission; portfolio-gate
edits; correlation waivers; manual tester launches; and parameter rescue after
results. Q02 uses one shared `RISK_FIXED=1000` package budget,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

