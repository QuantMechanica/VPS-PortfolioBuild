# WTI Monthly Seasonal-Surprise Reversion — Source Approval

- Date: 2026-09-09
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one structural low-frequency WTI card, deterministic allocation,
  branch-only non-live build, strict Q01, and one paced Q02 enqueue only below
  the hard CPU ceiling
- Proposed slug: `wti-seas-surprise-rv`
- Strategy ID: `KELOHARJU-YANG-WTI-SEASSURPRISE-2026_S01`
- Dedup receipt:
  `artifacts/qm5_wti_seas_surprise_rv_preallocation_dedup_20260909.json`

## Authority And Source Quality

The current explicit OWNER pacer instruction authorizes one reputable-source,
structural, low-frequency commodity/energy card and build. The bounded
extraction must preserve two completely read governed parents:

1. `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, recording the
   complete 57-page open version of Keloharju, Linnainmaa, and Nyberg (2016),
   *The Journal of Finance* 71(4), 1557-1590, DOI `10.1111/jofi.12398`, with
   explicit crude-oil membership.
2. `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`, the governed
   named-author academic commodity-futures reversal lineage for fixed return
   horizons, including WTI extractions and with no peer-review claim.

Keloharju supplies the recurring same-calendar commodity expectation and WTI
carrier. Yang supplies only a broad fixed-horizon commodity-reversal lineage.
Neither tests the exact standardized WTI residual, the half-sigma threshold,
the following-month hold, or a continuous CFD. The conjunction is an untested
QM mechanization, and no source or sibling efficacy or diversification result
transfers.

## Locked Mechanic

At the first executable `XTIUSD.DWX` D1 tick of broker month `M`:

1. Repair malformed owned exposure, close a surviving prior-month package,
   and persist month `M` before every fallible entry gate. Never retry `M`.
2. Under one uniform native or `+1` energy-D1 label convention, reconstruct
   the just-completed month `J=M-1` and
   `realized_J=ln(close_end_J/close_end_(J-1))` from completed bars only.
3. Load the same calendar month `J` in up to ten earlier years, excluding the
   realized observation. Skip missing years without replacement and require
   at least five valid returns.
4. Compute the arithmetic mean, `n-1` sample standard deviation, and
   `surprise_z=(realized_J-seasonal_mean)/seasonal_sd`.
5. Sell only above `+0.50+1e-10`; buy only below `-0.50-1e-10`; consume the
   interior band and equality flat.
6. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, one frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.
7. Close at the next genuine broker-month boundary; 40 elapsed days is stale
   repair only.

Both news axes, legacy news, and Friday close are OFF in the setfile. They are
framework inputs and must not be equality-pinned in source. No current-month
signal, upcoming-month seasonal forecast, unconditional reversal fallback,
learned component, banned indicator, external feed, magnitude sizing, target,
trail, scale-in, grid, martingale, pyramid, or retry is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_ACADEMIC_SUPPLEMENT_CONJUNCTION_AND_CFD_RISK`: a complete-read
  peer-reviewed Journal of Finance lineage supplies same-calendar commodity
  evidence and explicit crude-oil membership; a named-author academic paper
  supplies broad reversal lineage. The exact conjunction is untested.
- R2 `PASS`: clock, labels, endpoints, realized-sample exclusion, bounded
  sample, mean, `n-1` scale, strict band, side, attempt, fixed risk, stop,
  spread, rollover, and repair are deterministic.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_RISK`: registered native
  `XTIUSD.DWX` D1 data and MT5 state supply every runtime input.
- R4 `PASS`: timestamps, completed prices, logarithms, arithmetic, square
  root, comparisons, ATR risk plumbing, and execution state only; no ML or
  prohibited signal component.

## Duplicate Decision

The canonical checker scanned 4,877 registry rows and 1,489 cards. The
configured Strategy Wiki root was unavailable and is recorded as such. It
raised three expected fuzzy neighbors:

- `QM5_41208` applies the same estimator and contrarian side to XNG, not WTI.
- `QM5_41209` applies the same estimator to WTI but follows the residual.
- `QM5_41393` applies the continuation direction to XNG.

No existing identity combines the direct WTI carrier, standardized
just-completed-minus-same-calendar residual, strict half-sigma band, and
contrarian next-month side. Carrier and direction are both load-bearing;
changing either recreates a fuzzy sibling. `QM5_12567` instead uses a
two-day cumulative-RSI pullback above a slow trend with a short holding clock.

Verdict:
`DISTINCT_WTI_STANDARDIZED_SEASONAL_SURPRISE_REVERSION_AFTER_FAMILY_REVIEW`.

## Authorization Boundary

This approval permits one bounded source packet, approved card and G0
decision, deterministic identity/magic allocation, branch-only V5 build,
mandatory PACER input-pin audit before compile enqueue, strict Q01, and one
paced Q02 enqueue below the CPU ceiling. It excludes manual backtests,
optimization, portfolio admission, correlation waivers, portfolio-gate edits,
deployment, live manifests, `T_Live`, AutoTrading, and live use.
