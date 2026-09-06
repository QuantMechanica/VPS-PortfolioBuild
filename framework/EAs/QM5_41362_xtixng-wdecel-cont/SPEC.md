# QM5_41362_xtixng-wdecel-cont - Strategy Spec

**EA ID:** QM5_41362

**Slug:** `xtixng-wdecel-cont`

**Strategy ID:** `AI-CODEX-XTIXNG-WDECEL-CONT-20260906_S01`

**Source:** `AI-CODEX-XTIXNG-WDECEL-CONT-20260906`

**Author:** Codex

**Last revised:** 2026-09-06

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of a new broker week, reconstruct
three consecutive synchronized XTI/XNG completed-week-end closes and compute
two adjacent changes in `ln(XTI)-ln(XNG)`. When both changes have the same
strict sign and the newest absolute move is strictly smaller, follow that
decelerating relative trend for one week: positive opens BUY XTI / SELL XNG;
negative opens SELL XTI / BUY XNG. All other states consume the week flat.

The package targets equal absolute notionals, shares one `RISK_FIXED` budget,
and carries frozen per-leg ATR hard stops.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | first-week-bar execution window |
| `strategy_history_bars_d1` | 30 | bounded D1 week-end buffer |
| `strategy_atr_period_d1` | 20 | completed-bar per-leg range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | equal entry-notional target |
| `strategy_max_notional_mismatch_pct` | 20.0 | lot-step mismatch ceiling |
| `strategy_max_hold_days` | 10 | stale package repair |
| `strategy_xti_max_spread_points` | 1500 | XTI cost guard |
| `strategy_xng_max_spread_points` | 3000 | XNG cost guard |
| `qm_friday_close_enabled` | false | preserve complete weekly hold |

All parameters are locked for Q02.

## 3. Symbol Universe

- Host: exact `XTIUSD.DWX`, D1, slot 0.
- Companion: exact `XNGUSD.DWX`, D1, slot 1.
- Logical symbol: `QM5_41362_XTI_XNG_WDECEL_CONT_D1`.

## 4. Timeframe

- Host chart and companion history: D1.
- Formation: two adjacent completed weekly relative returns.
- Trigger: strict same signs and strictly smaller newest magnitude.
- Hold: first tick of the next broker week, with ten-day stale repair.

## 5. Expected Behaviour

Expected density is eight to twenty paired packages per full post-warm-up year;
Q02 retires below five. This is a market-neutral-style construction, not a
claim of exact neutrality or decorrelation. Q09 alone owns realized overlap.

## 6. Source Citation

Villar and Joutz (2006), U.S. EIA; Ramberg and Parsons (2012), *The Energy
Journal* 33(2), DOI `10.5547/01956574.33.2.2`; and Moskowitz, Ooi, and Pedersen
(2012), *Journal of Financial Economics* 104(2), DOI
`10.1016/j.jfineco.2011.11.003`.

Canonical packet:
`strategy-seeds/sources/AI-CODEX-XTIXNG-WDECEL-CONT-20260906/source.md`.
The exact weekly relative-spread rule is a disclosed QM hypothesis; no source
performance or CFD result transfers.

## 7. Risk Model

Q02 uses aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both news axes and Friday close are OFF. There is no
live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`, deploy or
live manifest, portfolio admission, correlation waiver, external feed,
retry, scale-in, grid, pyramid, target, trail, break-even, or partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-06 | approved build identity | source/G0 approval and governed magics |
| v2 | 2026-09-06 | governed Q01 build | COMPILE_OK on T4; Q02 stopped at the 97% CPU ceiling |
