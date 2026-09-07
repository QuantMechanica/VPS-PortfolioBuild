# QM5_41375 WTI pure weekly momentum build and Q02 handoff

## Outcome

`QM5_41375_wti-wmom1` is a committed new low-frequency energy sleeve. On
the first tradable D1 bar of a normalized WTI broker week, it follows the
strict sign of `ln(final close / first open)` from the exact immediately
completed three-to-five-session week and exits at the next week boundary.
There is no volatility, body/range, magnitude, calendar, inventory, or event
signal gate.

The mechanic is distinct from `QM5_13049` (load-bearing low-volatility
filter), `QM5_41092` (load-bearing two-thirds body/range filter), multi-week
WTI momentum variants, monthly energy cross-sectional momentum, and the
certified XNG RSI2 pullback.

## Source and validation

The approved source is Kwon, Kang, and Yun (2020), “Weekly Momentum in the
Commodity Futures Market,” *Finance Research Letters* 35, 101306,
DOI `10.1016/j.frl.2019.101306`. The card discloses that its cross-sectional
`CMOM1,1` evidence does not prove a standalone WTI time-series CFD edge.

Canonical dedup was CLEAN across 4,855 registry rows, 1,468 cards, and 45
Strategy Wiki nodes. Twelve deterministic reference cases, card/ML lint, and
build guardrails pass.

## PACER guard and governed compile

The mandatory input-pin audit was run after each source version and before
each governed compile enqueue. Both runs returned exit code 0 and zero
`EA_FRAMEWORK_INPUT_PINNED` findings. The implementation does not compare
RNG, news, or Friday-close inputs; stress rejection is only checked for finite
inclusive `0..1`; fixed-risk mode requires `RISK_FIXED>0` and
`RISK_PERCENT=0`.

The first governed compile produced 0 errors/0 warnings but build-check
correctly rejected a source symbol literal. The repaired source takes an empty
`strategy_symbol` default and requires the factory setfile to supply the
symbol. Governed successor `9349c325-5440-48bc-bd4d-6f22ad8ad728` then
returned `COMPILE_OK` and build-check PASS. Binary SHA-256 is
`e839bc71a36918687619d0997c094c7062d2c873e4a5d9ddf12d0f7f79b4d482`.

## Q02

Fresh whole-host CPU samples were 27.2%, 28.3%, 31.3%, 28.2%, and 28.9%,
below the 97% stop ceiling. The canonical first-Q02 intake enqueued exactly
one `XTIUSD.DWX` D1 fixed-risk row:
`e9ebd527-13f3-4913-8bf5-13dc8d7c229a`.

The setfile binds `RISK_FIXED=1000`, `RISK_PERCENT=0`, and exact
`strategy_symbol=XTIUSD.DWX`. Q02 owns activity and economics; Q09 alone
may establish portfolio decorrelation.

No `T_Live`, AutoTrading, deploy/live manifest, portfolio gate, admission,
or correlation waiver was touched.
