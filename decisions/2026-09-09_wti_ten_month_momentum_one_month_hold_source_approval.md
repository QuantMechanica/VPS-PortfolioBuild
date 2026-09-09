# WTI Ten-Month Momentum / One-Month Hold — Source Approval

- Date: 2026-09-09
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one structural low-frequency WTI card, deterministic allocation,
  branch-only non-live build, strict Q01, and one paced Q02 enqueue only below
  the hard CPU ceiling
- Proposed slug: `wti-tsmom10-h1`
- Strategy ID: `MOP-TSMOM-2012_XTI_K10H1_S41`
- Parent source: `strategy-seeds/sources/MOP-TSMOM-2012/source.md`
- Dedup receipt: `artifacts/qm5_wti_tsmom10_h1_preallocation_dedup_20260909.json`

## Authority And Source Quality

The current OWNER pacer instruction authorizes one reputable-source,
structural, low-frequency commodity/energy card and build under the stated
build guard. Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*,
Journal of Financial Economics 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`, is a peer-reviewed primary source. The
governed parent packet records an end-to-end read of the 23-page published
paper, an author-hosted retrieval route, and PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.

The paper tests monthly own-return continuation at lags one through sixty,
reports positive continuation over the first twelve monthly lags, defines a
family indexed by formation horizon `k` and holding horizon `h`, and includes
NYMEX WTI crude in its commodity-futures universe. It does not report a
standalone WTI `k=10, h=1` result. No paper return, significance, alpha,
Sharpe ratio, CFD equivalence, trade count, or diversification result transfers.

## Locked Mechanic

1. Trade preset-bound `XTIUSD.DWX` on D1 only.
2. At the first D1 bar of every new broker month, reconstruct eleven
   consecutive completed broker-month-end closes.
3. Compute `ln(C[10] / C[0])`; buy for a strict positive value, sell for a
   strict negative value, and consume equality or invalid history flat.
4. Persist one attempt before fallible gates and renew only at the next month boundary.
5. Hold to the next broker-month boundary, with 40 elapsed days as stale repair only.
6. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

No moving average, oscillator, learned component, volume, curve, inventory,
external runtime data, magnitude sizing, target, trail, scale-in, pyramid,
grid, martingale, or retry is permitted.

## Reputable-Source Criteria

- R1 `PASS_WITH_WTI_SPECIFIC_EFFICACY_UNPROVEN`: named authors,
  peer-reviewed JFE publication, DOI, author-hosted complete paper, durable
  receipt/hash, source-defined `k,h` family, and explicit WTI membership.
- R2 `PASS`: endpoint count/order, exact return orientation, monthly clock,
  direction, attempt, fixed risk, stop, spread, rollover, and stale repair are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history supplies all runtime market inputs.
- R4 `PASS`: native calendar/OHLC/logarithm/ATR arithmetic only; no trained or prohibited mechanic.

## Duplicate Decision

The canonical checker scanned 4,871 registry rows, 1,484 cards, and 45
Strategy Wiki nodes. It found no exact identity and returned expected family
matches. `QM5_41388` uses the same exact ten-month formation but a fixed
odd-month, non-overlapping two-month package. Existing monthly-renewal WTI
carriers use one-, two-, three-, four-, six-, nine-, or twelve-month
formation, composites, filters, or other statistics. This identity requires
both exact ten-month endpoints and a one-month renewal lifecycle.

Verdict: `DISTINCT_WTI_K10H1_MONTHLY_TSMOM`.

## Authorization Boundary

This approval permits one approved card and G0 decision, deterministic identity
and magic allocation, bounded V5 build, mandatory PACER input-pin audit before
compile enqueue, strict Q01, and one paced logical Q02 enqueue only below the
hard CPU ceiling. It excludes manual backtests, optimization, portfolio
admission, correlation waivers, portfolio-gate edits, deployment, live
manifests, `T_Live`, AutoTrading, and live use.
