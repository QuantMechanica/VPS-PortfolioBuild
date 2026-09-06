# XTI/XNG Weekly Decoupling-Shock Reversion — Source Approval

- Date: 2026-09-06
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one market-neutral XTI/XNG card, deterministic allocation,
  branch-only non-live build, strict Q01, and one paced Q02 enqueue below the
  hard CPU ceiling
- Proposed slug: `xtixng-decouple-rv`
- Strategy ID: `AI-CODEX-XTIXNG-DECOUPLE-RV-20260906_S01`
- Proposed source packet:
  `strategy-seeds/sources/AI-CODEX-XTIXNG-DECOUPLE-RV-20260906/source.md`
- Dedup receipt:
  `artifacts/qm5_xtixng_decouple_rv_preallocation_dedup_20260906.json`

## Authority And Complete-Read Evidence

The current explicit OWNER mission authorizes one new reputable-source,
low-frequency commodity/energy edge and expressly permits a market-neutral
structural commodity construction. Before this approval, the complete governed
`VILLAR-RAMBERG-OILGAS-2026` packet was read. It records an end-to-end read of
Villar and Joutz (2006), U.S. Energy Information Administration, and Ramberg
and Parsons (2012), *The Energy Journal* 33(2), DOI
`10.5547/01956574.33.2.2`, including their adverse evidence.

Those sources support a physical and economic oil/gas relative-value carrier
whose relationship is weak and time varying. They do not test a one-week
opposite-direction return fade. The exact weekly arithmetic, CFD mapping,
thresholds, equal-notional target, aggregate fixed-risk budget, and lifecycle
are bounded QM translations whose efficacy remains wholly unproven.

## R1-R4 Decision

- R1 `PASS_WITH_DECOUPLING_TRANSLATION_RISK`: complete U.S. government and
  peer-reviewed oil/gas evidence with adverse instability retained; no source
  alpha, neutrality, or correlation claim transfers.
- R2 `PASS`: two synchronized consecutive completed-week endpoints, strict
  opposite individual-return signs, loser-long/winner-short sides, durable
  weekly attempt, aggregate risk, hard stops, and one-week lifecycle are exact.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native `XTIUSD.DWX` and `XNGUSD.DWX` D1 histories provide every market input.
- R4 `PASS`: deterministic timestamps, logarithms, comparisons, ATR, quotes,
  positions, deals, and durable state only; no trained or external runtime
  input, grid, martingale, or banned indicator exists.

## Duplicate Decision

The canonical checker covered 4,845 registry rows and 1,458 repository cards.
It found no exact identity and no fuzzy match above threshold. The optional
external Strategy Wiki root was unavailable, so the tool correctly returned
`INPUT_ERROR_FAIL_CLOSED`; this limitation is preserved in the receipt rather
than relabeled as a complete-universe pass. Under the current direct OWNER
mission, manual review accepts the bounded repository scopes and records the
unavailable external scope explicitly.

Nearest mechanics are distinct:

- `QM5_41361_xtixng-commonshock-rv` requires same-sign individual weekly
  returns and fades only their relative dispersion. This proposal requires
  opposite signs and reverses both completed moves.
- `QM5_12840_xti-xng-rspread` standardizes a configurable multi-day return
  spread over a rolling z-score window and exits at its fitted mean. This
  proposal has no fitted center, beta, or z-score and uses one exact completed
  broker week with a fixed next-week exit.
- `QM5_41358` and `QM5_41360` classify two adjacent returns of the oil/gas
  ratio. This proposal uses one return from each individual energy leg.
- `QM5_12709` and `QM5_41056` are monthly and eighteen-month cross-sectional
  reversal constructions, not a completed-week decoupling state.
- `QM5_12567` is a single-symbol, long-only, two-day XNG oscillator pullback.

The exact XTI/XNG carrier, synchronized prior-two-week endpoints, strict
opposite individual-return signs, two-sided loser-long/winner-short package,
weekly attempt, aggregate fixed risk, equal notionals, and next-week exit are
jointly load-bearing. Q09 receives no correlation waiver.

## Authorization Boundary

This source approval permits one card extraction and the bounded build path
named above. It excludes manual backtests, optimization, portfolio-gate edits,
portfolio admission, deployment, live manifests, `T_Live`, AutoTrading, and
live use. Q02 must retire the edge on zero packages, fewer than five packages
per full post-warm-up year, or nonpositive governed economics; no result-driven
parameter or direction change is authorized.

