# QM5_20050 XAU/XAG Momentum Build And Q02 Enqueue

- Date: 2026-07-23
- Branch: `agents/board-advisor`
- EA: `QM5_20050_xauxag-xmom12`
- Logical symbol: `QM5_20050_XAU_XAG_XMOM12_D1`
- Card: `strategy-seeds/cards/xauxag-xmom12_card.md`
- Source: `strategy-seeds/sources/FMR-MOMTS-2010/source.md`

## Decision

Build one monthly precious-metals cross-sectional-momentum package: calculate
the arithmetic mean of twelve completed monthly simple returns for XAU and
XAG, buy the winner, short the loser, and hold to the next broker month. This
is distinct from existing XAU/XAG ratio reversion, ratio breakout,
return-spread reversion, conditional-quantile reversion, and weekend/calendar
packages. The source-sibling fuzzy match is an XTI/XNG one-month momentum plus
swap-agreement strategy and was manually rejected as a duplicate.

## Validation

- Strategy-card schema lint: PASS; no missing sections and no ML hits.
- Magic rows: `200500000` XAU slot 0 and `200500001` XAG slot 1, active.
- Magic resolver regenerated from the canonical registry.
- `compile_one.ps1 -Strict`: PASS, 0 errors, 0 warnings.
- `build_check.ps1 -EALabel QM5_20050_xauxag-xmom12 -SkipCompile`: PASS,
  0 failures, 0 warnings.
- Compiled binary SHA256:
  `08B18D41EAABB2F8B6B6AAD87E6C4D391D853A88F4F970C5033B6CB720F48FBF`.
- Q02 work item: `8a36f351` (full UUID begins with this stable short ID),
  pending, attempt 0, one logical basket rather than physical-leg fanout.

Repository-wide dedup audit emitted pre-existing registry debt and was not used
as a clean global assertion. Exact candidate dedup was clean; the one
same-source fuzzy match received the manual formula/carrier review above.

No backtest was started here. No T_Live, AutoTrading, live setfile, deploy
manifest, portfolio gate, or T_Live manifest was touched.
