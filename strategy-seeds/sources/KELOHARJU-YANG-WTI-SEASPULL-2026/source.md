---
source_id: KELOHARJU-YANG-WTI-SEASPULL-2026
title: WTI same-calendar seasonal pullback
publisher: The Journal of Finance / SSRN
source_type: peer_reviewed_and_academic_composite_lineage
status: approved
created: 2026-07-25
created_by: Codex
last_updated: 2026-07-25
approved_by: "OWNER commodity/energy sleeve mission"
approved_at: 2026-07-25
strategy_ids:
  - KELOHARJU-YANG-WTI-SEASPULL-2026_S01
parent_sources:
  - KELOHARJU-RETSEAS-2016
  - YANG-COMM-REVERSAL-2017
---

# WTI Same-Calendar Seasonal Pullback Source

## Source Identity

This packet joins two already governed commodity source lineages:

1. Keloharju, Matti; Linnainmaa, Juhani T.; and Nyberg, Peter (2016),
   "Return Seasonalities," *The Journal of Finance* 71(4), 1557-1590,
   DOI https://doi.org/10.1111/jofi.12398. The complete open NBER working
   paper is https://www.nber.org/papers/w20815.
2. Yang, Hongbing; Goncu, Ahmet; and Pantelous, Athanasios A. (2017),
   "Momentum and Reversal in Commodity Futures," SSRN 3069253,
   https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3069253.

The bounded repository packets
`strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md` and
`strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md` were read
completely before this extraction. The first packet records a complete
57-page review of the peer-reviewed return-seasonality paper and its explicit
crude-oil membership. The second is the governed academic commodity-reversal
lineage for fixed-horizon loser/winner behavior.

## Findings Used

- Keloharju, Linnainmaa, and Nyberg find recurring same-calendar-month return
  information in a broad commodity-futures cross-section that explicitly
  contains crude oil.
- Yang, Goncu, and Pantelous study systematic commodity momentum and reversal
  at fixed return horizons.
- Neither source tests a single WTI seasonal-sign carrier conditioned on an
  immediately preceding counter-seasonal monthly return, a Darwinex
  continuous CFD, fixed-risk monthly renewal, or an ATR hard stop. Those are
  explicit QM hypotheses, not imported author claims.

No source return, hit rate, profit factor, drawdown, trade count, or
correlation statistic is used as a forecast for this candidate.

## Bounded Mechanization

`KELOHARJU-YANG-WTI-SEASPULL-2026_S01` is one predeclared interaction:

- host and only traded symbol: `XTIUSD.DWX`, D1, magic slot 0;
- decision: first tradable D1 bar of each broker month;
- seasonal state: arithmetic mean of WTI's completed log return for the
  decision calendar month over up to ten prior years, with at least five
  valid samples;
- pullback state: WTI's immediately completed broker-calendar-month log
  return, reconstructed from completed D1 month-end closes;
- buy only when the seasonal state is strictly positive and the completed
  prior-month return is strictly negative;
- sell only when the seasonal state is strictly negative and the completed
  prior-month return is strictly positive;
- aligned signs, exact zero, invalid arithmetic, missing consecutive
  month-ends, or insufficient history: remain flat for that month;
- close and, when the interaction remains eligible, renew at the next
  broker-month boundary;
- frozen `3.5 * ATR(20)` hard stop, 35-day stale guard, 1,500-point spread
  ceiling, and one consumed attempt per broker month; and
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, backtest-only execution.

The seasonal state supplies direction. The recent return is only a
counter-move gate; it is never faded without the recurring calendar sign.
There is no fitted displacement threshold: strict non-zero sign disagreement
is the locked baseline.

## Non-Duplicate Boundary

The pre-allocation deterministic check scanned 4,194 EA-registry rows and 376
research cards and returned `CLEAN` for slug `wti-seas-pb`, strategy ID
`KELOHARJU-YANG-WTI-SEASPULL-2026_S01`, and the complete mechanic fingerprint.

Manual semantic review resolves the closest systems:

- `QM5_20099_wti-samecal` always follows the historical same-calendar sign;
  it does not require a counter-seasonal immediately completed month.
- `QM5_20136_wti-caltrend` requires agreement with a completed 63-D1 trend
  sign. This card instead requires disagreement with the exact prior
  broker-month return and therefore selects the opposite recent-return state.
- `QM5_12709_commodity-reversal-1m` ranks four commodities and trades a
  two-leg winner/loser basket; it has no historical month-of-year estimator.
- `QM5_12594_yang-wti-reversal` is a weekly medium-horizon overextension fade
  toward an SMA; it has no same-calendar direction.
- `QM5_20047_wti-mon-loss-bnc` is a one-session Tuesday bounce after a Monday
  loss, not a monthly seasonality interaction.
- `QM5_13120_energy-momrev` is a two-leg XTI/XNG 12/18-month opposite-rank
  package, not a single-WTI calendar-conditioned pullback.
- `QM5_12567_cum-rsi2-commodity` uses cumulative RSI(2) and a short holding
  clock; this card uses neither an oscillator nor that signal family.

Removing the prior-month disagreement gate recreates `QM5_20099`. Replacing
disagreement with medium-horizon agreement recreates the information object
used by `QM5_20136`. The gate, exact prior-calendar-month reconstruction, and
seasonal direction are jointly load-bearing.

## Reputable-Source Criteria

- R1: PASS. The primary source is a peer-reviewed *Journal of Finance* paper
  with DOI and a complete reviewed NBER version; the reversal supplement is a
  named-author academic commodity-futures paper with a durable governed
  packet.
- R2: PASS. The seasonal estimator, immediately completed-month return,
  strict disagreement rule, monthly cadence, direction, stop, stale exit,
  spread cap, and retry state are deterministic and locked.
- R3: PASS. Registered `XTIUSD.DWX` D1 history supplies every runtime input.
- R4: PASS. Runtime uses native MT5 OHLC, ATR, broker calendar, quotes,
  positions, deal history, and framework state only; there is no trained
  model, banned indicator, external feed, grid, martingale, scale-in, or
  pyramiding.

## Claim And Safety Boundary

The sources do not establish profitability, CFD/futures equivalence, trade
density, decorrelation, or portfolio admission for this interaction. WTI
gaps, continuous-CFD roll/basis, financing, limited same-month samples,
calendar-signal decay, and sparse sign disagreement are binding kill risks.

This OWNER-approved packet authorizes one Strategy Card, deterministic
registry allocation, V5 build, strict compile, one `RISK_FIXED` backtest
setfile, and one paced Q02 enqueue. It does not authorize a live setfile,
AutoTrading, `T_Live`, a deploy or T_Live manifest, portfolio admission, a
portfolio-gate change, or a correlation waiver.
