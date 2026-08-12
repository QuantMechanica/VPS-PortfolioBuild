---
source_id: LUCEY-TULLY-DOW-2006
title: Seasonality, risk and return in daily COMEX gold and silver data 1982-2002
publisher: Applied Financial Economics 16(4), 319-333
source_type: peer_reviewed_open_access_author_copy
status: approved
approved_by: OWNER commodity-sleeve mission
approved_at: 2026-07-24
primary_url: https://www.tandfonline.com/doi/full/10.1080/09603100500386586
open_full_text_url: https://www.tcd.ie/triss/assets/PDFs/iiis/iiisdp57.pdf
strategy_ids:
  - LUCEY-TULLY-DOW-2006_S01
---

# Lucey-Tully Gold/Silver Monday Source

## Source identity and review boundary

Brian M. Lucey and Edel Tully (2006), "Seasonality, risk and return in
daily COMEX gold and silver data 1982-2002," *Applied Financial Economics*
16(4), 319-333, DOI `10.1080/09603100500386586`. The complete 39-page
Trinity College Dublin author copy was reviewed on 2026-07-24, including the
data construction, unconditional and conditional tests, tables, conclusion,
limitations, and references.

The paper is a named-author, peer-reviewed empirical study with a complete
public author copy. It is quality tier B: reputable academic evidence, not a
realized trading record or evidence on Darwinex CFDs.

## Selected observation

The authors study 5,256 daily COMEX cash observations and 5,225 continuous
futures observations from January 1982 through November 2002. Their futures
series uses a published linear near/next-contract roll method.

Table 2 reports the following unconditional Monday means:

- cash gold: `-0.0007`;
- cash silver: `-0.0011`;
- futures gold: `-0.0002`; and
- futures silver: `-0.0007`.

An equal-notional long-gold/short-silver arithmetic translation therefore has
a gross historical Monday differential of about `+0.0004` in cash and
`+0.0005` in futures. The paper does not estimate, test, or recommend that
two-leg spread. It reports both individual futures Monday coefficients as
insignificant, says first-moment seasonality is weak and statistically
non-robust, and finds stronger evidence for weekday variance seasonality.
Those negative findings are binding; this source authorizes a weak,
predeclared falsification candidate rather than a profitability claim.

The conditional LGARCH result is also bounded carefully. Monday mean dummies
remain significant and negative for cash gold and cash silver, while the
paper explicitly does not confirm the futures Monday mean. The QM carrier
does not implement GARCH, conditional variance, or any fitted model.

## Mechanization boundary

On the first executable tick of a genuine broker-Monday D1 bar, open one
equal-USD-notional package: BUY `XAUUSD.DWX` and SELL `XAGUSD.DWX`. Close the
complete package at the first following host D1 boundary, normally Tuesday.
This isolates the broker-Monday session and suppresses common precious-metal
directional exposure.

The mapping is a QM research translation, not a source-authored trade:

- COMEX cash/futures closes and Darwinex broker D1 boundaries differ;
- entering at the broker-Monday open can omit a weekend gap embedded in a
  close-to-close Monday return;
- equal notional is not an estimated hedge ratio; and
- the source never tests the gold-minus-silver differential.

The shared fixed-risk budget, ATR hard stops, spread caps, synchronized-bar
gate, no-retry marker, atomic broken-package repair, stale guard, and Friday
emergency close are V5 risk/execution plumbing. No neighboring weekday,
direction flip, alternative hedge, parameter sweep, or conditional model is
authorized after Q02 results are observed.

## Reputable-source criteria

- R1: TIER_B. Peer-reviewed journal article, named authors, DOI, publisher
  landing page, and complete institutional author copy.
- R2: PASS. Monday D1 entry, directions, equal notional, next-D1 exit, risk
  budget, stops, spread gates, and no-retry behavior are deterministic and
  frozen.
- R3: PASS. Both Darwinex symbols and D1 histories are registered and already
  supported by governed two-leg basket builds.
- R4: PASS. Broker-calendar arithmetic and ATR risk only; no banned or ML
  indicator, external runtime feed, adaptive fit, grid, martingale, pyramid,
  scale-in, or PnL-conditioned rescue.

## Non-duplicate boundary

The deterministic dedup tool returned CLEAN for `auag-mon-diff`,
`LUCEY-TULLY-DOW-2006_S01`, the authors, and the exact Monday-session basket.
Repository-wide card, source, and EA searches found no XAU-long/XAG-short
package opened on Monday D1 and flattened at the next D1 boundary.

`QM5_20019_xauxag-wkend` opens Friday 21:00 and exits at the first Monday H1
bar; this candidate starts only at the Monday D1 boundary, after that
weekend interval. Ratio reversion, threshold cointegration, ratio breakout,
return-spread reversion, and monthly cross-sectional momentum use price state
or longer formation windows rather than an unconditional one-session weekday
differential. Different mechanics do not establish decorrelation; Q09 and the
unchanged portfolio gate remain authoritative.

## Safety boundary

This record authorizes one research card, V5 build, strict compile,
`RISK_FIXED` backtest preset, basket manifest, and paced Q02 enqueue. It does
not authorize a live preset, AutoTrading, T_Live access, a deploy/T_Live
manifest, portfolio admission, or any portfolio-gate change.
