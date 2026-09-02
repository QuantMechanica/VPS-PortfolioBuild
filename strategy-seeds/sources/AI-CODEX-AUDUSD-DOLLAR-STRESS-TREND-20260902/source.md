---
source_id: AI-CODEX-AUDUSD-DOLLAR-STRESS-TREND-20260902
source_type: governed_synthesis
title: AUDUSD Dollar-Stress Trend Continuation
authors: OpenAI Codex; QuantMechanica OWNER
status: approved_source_bounded
created: 2026-09-02
created_by: Research
source_approval: decisions/2026-09-02_audusd_dollar_stress_trend_source_approval.md
---

# AUDUSD Dollar-Stress Trend Continuation

This packet bounds one transparent, pre-result translation of candidate 14 in
`docs/research/ORTHOGONAL_RETURN_SOURCES_PROGRAM_2026-08-13.md`. It does not
import a published trading rule, profitability result, parameter estimate, or
portfolio-correlation claim.

## Completely Read Source Boundary

The following bounded records were read completely before card extraction:

1. The complete OWNER research program, SHA-256
   `5032C7492C5A57A71D46C4176E6D6E48A1312C566BFD28CB955B104D40E061BD`.
   Its candidate 14 is a `BUILD_CANDIDATE` and specifies the D1 carrier,
   SP500 50-day/20-day stress gate, five-day broad-USD gate, prior-20-day-low
   target break, short AUD/NZD direction, two-ATR stop, ATR/time/gate exits,
   and approximately ten lumpy trades per year.
2. The complete public American Economic Association article page and
   abstract for Avdjiev, Du, Koch, and Shin (2019), DOI
   `10.1257/aeri.20180322`. The abstract documents that a stronger dollar is
   associated with larger covered-interest-parity deviations and contracting
   cross-border dollar bank lending, and frames the dollar as a barometer of
   global risk-taking capacity.
3. The complete public American Economic Association article page and
   abstract for Maggiori (2017), DOI `10.1257/aer.20130479`. The abstract
   states that the reserve currency appreciates during global crises and
   thereby provides a hedge.
4. The complete local adverse-evidence record
   `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, SHA-256
   `E513CC785DF2DFC7C74F2D89A03C47A9A90E00DCC9E14902839EE80946C13DF7`.
   It kills simple next-day SP500-to-AUDUSD lead-lag and beta-spread
   reversion. This candidate does neither: all cross-market observations are
   contemporaneous completed-bar regime gates, while the traded trigger is
   AUDUSD's own strict channel break. That distinction is a hypothesis, not
   contrary performance evidence.

The durable access record is `retrieval_route_aea_20260902.json`. Only the
official metadata and abstracts were read from the AEA pages; neither full
paper was claimed as reviewed. The informal Jen “dollar smile” label in the
OWNER program is descriptive lineage only and supplies no imported fact here.

## Locked Mechanization Boundary

On each new exact `AUDUSD.DWX` D1 bar, align the just-completed D1 close time
across `AUDUSD.DWX`, `EURUSD.DWX`, `GBPUSD.DWX`, and `SP500.DWX`. Use only
completed bars and exclude the just-completed bar from every historical
reference window.

- Global stress requires the completed SP500 close `S0` to be strictly below
  the arithmetic mean of `S1..S50`, and the simple twenty-session return
  `S0/S20-1` to be strictly negative.
- Broad USD strength is the arithmetic mean of the simple five-session
  returns `C0/C5-1` for EURUSD, GBPUSD, and AUDUSD. Require the mean to be at
  most `-0.010`.
- The traded trigger requires the completed AUDUSD close to be strictly below
  the minimum of the prior twenty completed AUDUSD lows, `L1..L20`.
- Open one market SELL only when all four conditions hold. Freeze the signal
  bar `ATR(14,D1)` for the initial hard stop at two ATR above entry.
- On later completed D1 bars, tighten (never loosen) the stop to the completed
  close plus two times that bar's completed `ATR(14,D1)`. Exit after ten D1
  bar shifts from broker position-open time or when any global-stress or
  broad-USD gate clears.

The single-symbol baseline intentionally trades only `AUDUSD.DWX`; an NZDUSD
sibling would require a separate identity and approval. There is no long
signal, forecast, scaling, retry loop, averaging, pyramid, grid, martingale,
external runtime feed, or current-bar signal. Both news axes and Friday close
are OFF. Q02-Q10 use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

## Source Scope And Falsification

The AEA abstracts support only the economic carrier: global funding stress
can coincide with dollar appreciation. They do not identify AUDUSD, a daily
channel rule, the gates, thresholds, ATR management, activity, costs, or
returns. Every executable detail is untested QuantMechanica synthesis fixed
before Q02. The earlier local null result is preserved as direct warning
against reinterpreting this as an SP500 lead-lag strategy.

Retire zero trades, fewer than ten distinct entry days in any full
post-warm-up year, nonpositive governed economics, failed walk-forward or
stress gates, timestamp misalignment, or any implementation drift. No
threshold rescue is authorized.

## Reputable-Source Criteria

- R1: `PASS_WITH_UNTESTED_MECHANIZATION`. A complete OWNER research ticket and
  two official peer-reviewed-journal metadata/abstract pages establish the
  exact research lane and structural dollar-stress carrier; no trading result
  transfers.
- R2: `PASS`. Bar alignment, sample endpoints, strict/equality boundaries,
  side, stop, trail, exits, risk, and activity floor are fixed.
- R3: `PASS`. All four exact `.DWX` symbols are registered D1 research inputs;
  only AUDUSD is an execution target.
- R4: `PASS`. Completed native OHLC, ATR, quote, position, and framework state
  only; no trained/adaptive output or banned strategy family.

## Safety Boundary

This packet authorizes no manual test, optimization, portfolio admission,
live preset, live routing, deploy manifest, `T_Live`, terminal control, or
AutoTrading action.
