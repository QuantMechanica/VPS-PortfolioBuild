# WTI Two-Month Momentum / Two-Month Hold — Source Approval

- Date: 2026-09-08
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one structural low-frequency WTI card, deterministic allocation,
  branch-only non-live build, strict Q01, and one paced Q02 enqueue only below
  the hard CPU ceiling
- Proposed slug: `wti-tsmom2-h2`
- Strategy ID: `MOP-TSMOM-2012_XTI_K2H2_S35`
- Parent source: `strategy-seeds/sources/MOP-TSMOM-2012/source.md`
- Dedup receipt: `artifacts/qm5_wti_tsmom2_h2_preallocation_dedup_20260908.json`

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
reports positive continuation over the first twelve lags, defines a family
indexed by formation horizon `k` and holding horizon `h`, and includes NYMEX
WTI crude in its commodity-futures universe. It does not report a standalone
WTI `k=2, h=2` result. No paper return, significance, alpha, Sharpe ratio, CFD
equivalence, trade count, or diversification result transfers.

## Locked Mechanic

1. Trade preset-bound `XTIUSD.DWX` on D1 only.
2. At the first D1 bar of each odd-numbered broker month, reconstruct three
   consecutive completed broker-month-end closes.
3. Compute `ln(C[2] / C[0])`; buy for a strict positive value, sell for a
   strict negative value, and consume equality or invalid history flat.
4. Persist one attempt before fallible gates and do nothing at even-month boundaries.
5. Hold until the next odd-month boundary, with 70 elapsed days as stale repair only.
6. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

No moving average, oscillator, learned component, volume, curve, inventory,
external runtime data, magnitude sizing, target, trail, scale-in, pyramid,
grid, martingale, or retry is permitted.

## Reputable-Source Criteria

- R1 `PASS_WITH_WTI_SPECIFIC_EFFICACY_UNPROVEN`: named authors,
  peer-reviewed JFE publication, DOI, author-hosted complete paper, durable
  receipt/hash, source-defined `k,h` family, and explicit WTI membership.
- R2 `PASS`: endpoint count/order, exact return orientation, odd-month clock,
  direction, attempt, fixed risk, stop, spread, rollover, and stale repair are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history supplies all runtime market inputs.
- R4 `PASS`: native calendar/OHLC/logarithm/ATR arithmetic only; no ML or prohibited mechanic.

## Duplicate Decision

The canonical checker scanned 4,864 registry rows, 1,477 cards, and 45
Strategy Wiki nodes. It found no exact identity and returned expected family
matches. `QM5_20064` uses two-month formation but renews every month.
`QM5_20281` shares the fixed odd-month two-month clock but uses twelve-month
formation; `QM5_41379` through `QM5_41383` use three-, one-, nine-, six-, and
four-month formation. This identity requires both exact two-month endpoints
and the non-overlapping two-month lifecycle.

Verdict: `DISTINCT_WTI_K2H2_NONOVERLAPPING_MONTHLY_TSMOM`.

## Authorization Boundary

This approval permits one approved card and G0 decision, deterministic identity
and magic allocation, bounded V5 build, mandatory PACER input-pin audit before
compile enqueue, strict Q01, and one paced Q02 enqueue only below the hard CPU
ceiling. It excludes manual backtests, optimization, portfolio admission,
correlation waivers, portfolio-gate edits, deployment, live manifests,
`T_Live`, AutoTrading, and live use.

