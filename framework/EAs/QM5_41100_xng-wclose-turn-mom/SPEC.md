# QM5_41100_xng-wclose-turn-mom - Strategy Spec

**EA ID:** QM5_41100

**Slug:** `xng-wclose-turn-mom`

**Strategy ID:** `BIANCHI-MOP-XNG-WCLOSE-TURN-MOM-2026_S01`

**Source:** `BIANCHI-MOP-XNG-WCLOSE-TURN-MOM-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-22

## 1. Strategy Logic

On the first tradable `XNGUSD.DWX` D1 bar of a new broker week, load every
session close from the exact immediately completed Monday-anchored week. The
package must contain three to five unique, strictly ordered sessions under
one uniform energy-label convention.

Buy only when the chronological closes strictly decrease into exactly one
interior trough, then strictly increase, and the final close is above the
first close. Sell the exact mirror: one strict interior peak followed by a
decline whose final close is below the first close. Equality, no turn,
multiple turns, endpoint-only extrema, incomplete recovery, malformed
history, current-week leakage, and nonadjacent week anchors consume the week
flat.

Hold for one broker week with fixed-dollar risk and a frozen completed-bar
ATR hard stop. Opens, highs, lows, and current-week prices do not contribute
to the signal.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_label_offset_seconds` | 86400 | uniform raw-to-energy-session label offset |
| `strategy_entry_grace_minutes` | 180 | first-week-bar execution window |
| `strategy_history_bars` | 16 | bounded D1 close buffer |
| `strategy_required_weeks` | 1 | exact immediately completed package |
| `strategy_min_week_bars` | 3 | minimum sessions in the package |
| `strategy_max_week_bars` | 5 | maximum sessions in the package |
| `strategy_require_single_turn` | true | equality, no-turn, and multi-turn paths stay flat |
| `strategy_require_full_recovery` | true | final close must pass the first close |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale-position repair |
| `strategy_max_spread_points` | 1500 | XNG entry cost guard |
| `qm_friday_close_enabled` | false | preserve full-week ownership |

All strategy parameters are frozen for the Q02 baseline.

## 3. Symbol Universe

- Host and traded symbol: exact `XNGUSD.DWX`, D1.
- Symbol slot: 0.
- Magic: `411000000`.
- No companion, hedge, conversion, ratio, or external signal symbol exists.

## 4. Timeframe And Lifecycle

- Formation: exact immediately completed three-to-five-session broker week.
- Trigger: one strict adjacent-close sign change plus full endpoint recovery.
- Entry: first new-week D1 bar, within 180 raw-session minutes.
- Hold: close at the first tick in a later broker week; ten days is repair.
- Attempt: persist the decision-week Monday anchor before every fallible
  history, signal, news, spread, quote, ATR, sizing, or order gate.

## 5. Expected Behaviour

- Approximately six to eighteen completed positions per full post-warm-up
  year; Q02 owns the binding floor of five per full year.
- Symmetric direct-XNG continuation after a completed-week reversal and full
  recovery.
- One fixed-risk position and one durable attempt per broker week.
- A different mechanic and lifecycle from certified `QM5_12567` do not prove
  decorrelation on the shared XNG carrier; Q09 owns that verdict.

## 6. Source Citation

Bianchi, R. J., Drew, M. E., and Fan, J. H. (2015), "Combining Momentum with
Reversal in Commodity Futures," *Journal of Banking & Finance* 59, 423-444, DOI
`10.1016/j.jbankfin.2015.07.006`.

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Canonical bounded source packet:
`strategy-seeds/sources/BIANCHI-MOP-XNG-WCLOSE-TURN-MOM-2026/source.md`.
The papers supply commodity reversal/continuation lineage and explicit XNG
membership. The exact within-week close path, one-turn rule, full recovery,
and continuous-CFD execution are disclosed QM translation hypotheses.

## 7. Risk Model And Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
Position sizing uses a frozen completed-bar `3.5*ATR(20,D1)` stop through the
V5 risk helper. Both news axes and Friday close are OFF.

There is no live/demo/shadow/stress/optimization preset, AutoTrading,
`T_Live`, deploy manifest, portfolio-gate change, portfolio admission,
correlation waiver, open/high/low signal, parent week, sign-count threshold,
excursion ratio, indicator, external feed, retry, scale-in, target, trail,
break-even move, or partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-22 | approved build-directory identity | source approval `e0fd6935a`; source packet `9b4508ba8`; EA-ID reservation `5df526f05`; Q00 card `1cde56339`; governed magic `df713dd70` |
