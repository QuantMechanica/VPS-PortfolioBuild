# QM5_20221 WTI Winter Return-Sign Momentum G0 Authorization

Date: 2026-08-05

Authority: OWNER commodity/energy portfolio mission delivered to Codex on
the `agents/board-advisor` branch.

## Decision

Authorize one bounded V5 research card and non-live build for
`QM5_20221_wti-win-signmom`. On the first tradable `XTIUSD.DWX` D1 bar of
each November-May broker month, the candidate counts the non-negative signs
of WTI's twelve completed monthly returns. It buys when the sign probability
is at least 0.40, otherwise sells, and remains flat June through October. It
closes and, when eligible, renews at every broker-month boundary.

The candidate may proceed through deterministic card lint, EA and magic
allocation, strict compile, one `RISK_FIXED` backtest setfile, and one paced
Q02 enqueue. G0 does not pre-approve profitability, decorrelation,
certification, execution-contract promotion, or portfolio admission.

## Source boundary

The governed composite packet is
`strategy-seeds/sources/BURAKOV-PAPAILIAS-WTI-WINSIGN-2026/source.md`. Its
fully reviewed parents are:

- Burakov, Freidin, and Solovyev (2018), "The Halloween Effect on Energy
  Markets: An Empirical Study," *International Journal of Energy Economics
  and Policy* 8(2), 121-126; and
- Papailias, Liu, and Thomakos (2021), "Return Signal Momentum," *Journal of
  Banking & Finance* 124, 106063, DOI `10.1016/j.jbankfin.2021.106063`.

The first supplies the fixed November-May WTI regime. The second supplies the
twelve binary monthly signs, fixed 0.40 threshold, direction map, and monthly
renewal. Neither tests this interaction, a Darwinex CFD, broker-month
reconstruction, fixed cash risk, an ATR stop, restart state, or the QM book.
No source performance or correlation statistic transfers.

## Non-duplicate decision

Before allocation, `research_dedup_check.py` scanned 4,278 registry rows and
394 canonical cards. It found no exact identity and flagged the expected
same-signal relatives. Manual review fixes the boundary:

- `QM5_13150_wti-signmom` is year-round; this candidate is forced flat
  June-October.
- `QM5_13116_xng-signmom` uses natural gas, not WTI.
- `QM5_20209_wti-winter-mom1` uses only the exact previous monthly return.
- `QM5_20218_wti-winter-rev1` reverses that one-month return.
- unconditional winter, 252-D1 winter trend, and `QM5_12567` oscillator
  builds use different formation objects or clocks.

The twelve binary signs, 0.40 threshold, winter gate, five-month flat state,
and monthly renewal are jointly load-bearing. Removing either signal or
seasonal state recreates a built parent.

## Allocation and kill boundary

- EA ID: `QM5_20221`
- slug: `wti-win-signmom`
- strategy ID: `BURAKOV-PAPAILIAS-WTI-WINSIGN-2026_S01`
- slot 0: `XTIUSD.DWX` / magic `202210000`
- maximum cadence: seven decisions/year after warm-up
- retire below five completed packages/year on average
- no parameter sweep, regime shift, statistic change, threshold change,
  direction flip, or post-result rescue is authorized

## Safety boundary

This authorization excludes manual backtests; live, demo, and shadow
setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests; portfolio
admission; portfolio-gate edits; correlation waivers; and downstream
promotion. Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.
