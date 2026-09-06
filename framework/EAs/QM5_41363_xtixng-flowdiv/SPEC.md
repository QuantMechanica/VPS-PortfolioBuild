# QM5_41363_xtixng-flowdiv - Strategy Spec

**EA ID:** QM5_41363
**Slug:** `xtixng-flowdiv`
**Strategy ID:** `AI-CODEX-XTIXNG-FLOWDIV-20260906_S01`
**Source:** `AI-CODEX-XTIXNG-FLOWDIV-20260906`
**Author:** Codex
**Last revised:** 2026-09-06

## 1. Strategy Logic

On the first executable tick of an exact synchronized broker Monday, read the
six immediately preceding completed XTI/XNG D1 bars: prior Friday through
Monday plus the preceding Friday anchor. For the five formation sessions,
separately sum XTI-minus-XNG close-to-open and open-to-close log returns.

Trade only when the two relative components have strict opposite signs.
Follow the session-relative sign with opposed legs: positive buys XTI and
sells XNG; negative sells XTI and buys XNG. Current-Monday prices are excluded.
The package targets equal absolute notionals, shares one fixed-risk budget,
uses frozen per-leg ATR hard stops, and closes both legs Friday at broker 21.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | Monday execution window |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.0 | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | equal entry-notional target |
| `strategy_max_notional_mismatch_pct` | 20.0 | lot-step mismatch ceiling |
| `strategy_max_hold_days` | 8 | stale package repair |
| `strategy_xti_max_spread_points` | 1500 | XTI cost guard |
| `strategy_xng_max_spread_points` | 3000 | XNG cost guard |
| `strategy_deviation_points` | 20 | order deviation |
| `qm_friday_close_enabled` | true | paired Friday closure |

All parameters are locked for Q02.

## 3. Symbol Universe

- Host: exact `XTIUSD.DWX`, D1, slot 0, magic `413630000`.
- Companion: exact `XNGUSD.DWX`, D1, slot 1, magic `413630001`.
- Logical symbol: `QM5_41363_XTI_XNG_FLOWDIV_D1`.

## 4. Timeframe

- Decision timeframe: D1.
- Formation: exact synchronized completed Monday-Friday price flows.
- Hold: Monday through Friday, with later-week/eight-day stale repair.

## 5. Expected Behaviour

Expected density is fifteen to thirty paired packages per full post-warm-up
year; Q02 retires below five. This is a market-neutral-style construction, not
a claim of exact neutrality or decorrelation. Q09 alone owns realized overlap.

## 6. Source Citation

Williams (1999), *Long-Term Secrets to Short-Term Trading*; Villar and Joutz
(2006), U.S. EIA; Ramberg and Parsons (2012), *The Energy Journal* 33(2), DOI
`10.5547/01956574.33.2.2`.

Canonical packet:
`strategy-seeds/sources/AI-CODEX-XTIXNG-FLOWDIV-20260906/source.md`. The exact
XTI/XNG conjunction is a disclosed QM hypothesis; no source or XAU/XAG parent
performance transfers.

## 7. Risk Model

Q02 uses aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. News is OFF. No live/demo/shadow/stress/optimization
preset, AutoTrading, `T_Live`, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, external feed, retry, scale-in,
grid, pyramid, target, trail, break-even, or partial exit is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-06 | approved build identity | source/G0 approval and governed magics |
| v1 | 2026-09-06 | governed Q01/Q02 handoff | compile work item `7647b8cd-c5d2-4f51-9872-3db6dda57da3` passed; one logical Q02 work item `551274fc-dab0-4e92-a092-2cd13bd98790` is pending |
