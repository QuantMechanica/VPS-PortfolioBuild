# XNG Shoulder-Season Weekly Reversal — Source Approval

- Date: 2026-09-09
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one structural low-frequency XNG card, deterministic allocation,
  branch-only non-live build, strict Q01, and one paced Q02 enqueue only below
  the hard CPU ceiling
- Proposed slug: `xng-shoulder-wrev`
- Strategy ID: `EIA-XNG-SHOULDER-WREV-2026_S01`
- Source packet: `strategy-seeds/sources/EIA-XNG-SHOULDER-WREV-2026/source.md`
- Dedup receipt: `artifacts/qm5_xng_shoulder_wrev_preallocation_dedup_20260909.json`

## Authority And Source Quality

The current OWNER pacer instruction authorizes one reputable-source,
structural, low-frequency commodity/energy card and build. The bounded source
packet inherits its structural context from an already-preserved official U.S.
Energy Information Administration source packet. The mandatory reader refused
fresh generic-web retrieval as `DEFERRED:SOURCE_POLICY`; that limitation is
retained rather than bypassed.

EIA's locally preserved finding is limited to recurring natural-gas demand
seasonality and lower-demand spring/fall shoulder periods. The completed-week
fade, exact months, risk, stop, spread, and lifecycle are disclosed QM
mechanizations. No efficacy or diversification claim transfers.

## Locked Mechanic

1. Trade preset-bound `XNGUSD.DWX` on D1 only.
2. Decide once at the first tradable D1 bar of each normalized broker week
   whose Monday anchor lies in April, May, September, or October.
3. Aggregate the immediately completed adjacent three-to-five-session week and
   compute `ln(final_close / first_open)`.
4. Fade its strict sign: negative buys, positive sells, exact zero remains flat.
5. Consume the attempt before fallible gates and close at the next normalized
   week; ten elapsed days is stale repair only.
6. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` stop, no target, and a 1,500-point spread ceiling.

No oscillator, moving average, volatility rank, magnitude threshold, external
runtime feed, learned component, target, trail, scale-in, pyramid, grid,
martingale, or retry is permitted.

## Reputable-Source Criteria

- R1 `PASS_WITH_TRANSLATION_RISK`: one governed source ID with official U.S.
  government lineage and the fresh-reader policy limitation recorded.
- R2 `PASS`: calendar, weekly aggregation, sign, contrarian side, attempt,
  fixed risk, stop, spread, and rollover are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XNGUSD.DWX` D1 history
  supplies all runtime market inputs.
- R4 `PASS`: native timestamps, OHLC, logarithm, ATR, quotes, positions, deals,
  and persistent state only; no ML, grid, or martingale.

## Duplicate Decision

The canonical checker scanned 4,872 registry rows, 1,485 cards, and 45
Strategy Wiki nodes and returned `CLEAN`. Manual family review separates
`QM5_12567` (cumulative RSI plus slow trend), `QM5_13102` (all-year five-day
reversal plus high-volatility rank), and existing shoulder trend/breakout/fade
systems. The four-month Monday-anchor gate plus exact normalized prior-week
open-to-close fade and one-week lifecycle are jointly load-bearing.

Verdict: `DISTINCT_XNG_SHOULDER_NORMALIZED_WEEK_REVERSAL`.

## Authorization Boundary

This approval permits one approved card and G0 decision, deterministic
identity/magic allocation, bounded V5 build, mandatory PACER input-pin audit
before compile enqueue, strict Q01, and one paced Q02 enqueue below the CPU
ceiling. It excludes manual backtests, optimization, portfolio admission,
correlation waivers, portfolio-gate edits, deployment, live manifests,
`T_Live`, AutoTrading, and live use.
