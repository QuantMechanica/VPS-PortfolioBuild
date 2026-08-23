# QM5_41105_wti-mclose-location-mom - Strategy Spec

**EA ID:** QM5_41105

**Slug:** `wti-mclose-location-mom`

**Strategy ID:** `MOP-WTI-MCLOSE-LOCATION-MOM-2026_S01`

**Source:** `MOP-WTI-MCLOSE-LOCATION-MOM-2026`

**Author:** Codex

**Last revised:** 2026-08-22

## 1. Strategy Logic

At the first tradable normalized `XTIUSD.DWX` D1 bar of a new broker month,
reconstruct the two immediately preceding completed calendar months. Require
17 through 23 sessions in each package. Let `C0`, `H0`, and `L0` be the newest
month's final close, high, and low, and `C1` the parent month's final close.

```text
r   = ln(C0 / C1)
clv = (C0 - L0) / (H0 - L0)

r > 0 and clv > 0.75  => BUY
r < 0 and clv < 0.25  => SELL
otherwise              => FLAT
```

The position closes at the first later broker-month boundary. The current
month never contributes signal data.

## 2. Parameters

| Parameter | Locked value | Meaning |
|---|---:|---|
| `strategy_history_bars_d1` | 70 | Bounded completed D1 buffer |
| `strategy_min_month_sessions` | 17 | Complete-month lower bound |
| `strategy_max_month_sessions` | 23 | Complete-month upper bound |
| `strategy_long_clv_min` | 0.75 | Strict upper-quartile boundary |
| `strategy_short_clv_max` | 0.25 | Strict lower-quartile boundary |
| `strategy_entry_grace_minutes` | 180 | First-month-bar attachment window |
| `strategy_atr_period_d1` | 20 | Completed D1 ATR estimator |
| `strategy_atr_sl_mult` | 3.5 | Frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | Stale repair guard |
| `strategy_max_spread_points` | 1500 | Entry spread ceiling |

All baseline values are locked; no parameter sweep is authorized.

## 3. Symbol Universe

- Host/traded symbol: exact `XTIUSD.DWX`.
- Timeframe: exact D1.
- Magic slot: 0; governed magic `411050000` after allocation.
- No companion symbol or external runtime dependency.

## 4. Expected Behaviour

- Approximately 6-10 completed positions per full post-warm-up year; Q02
  retires below five/year.
- Symmetric long/short direct-WTI exposure.
- One `RISK_FIXED=1000` position with a frozen `3.5*ATR(20,D1)` hard stop.
- Full-next-month hold, capped by a 40-day stale repair.
- Friday close and both news axes disabled for the monthly native-price
  baseline.

## 5. Source Citation

Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`, supplies the monthly own-return continuation
and explicit WTI carrier lineage. The close-location gate is a disclosed QM
translation.

The complete evidence boundary is
`strategy-seeds/sources/MOP-WTI-MCLOSE-LOCATION-MOM-2026/source.md`; the
approved card is
`strategy-seeds/cards/approved/QM5_41105_wti-mclose-location-mom_card.md`.

## 6. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The EA uses no target, retry, scale-in, grid,
martingale, pyramid, partial close, or external data.

No live setfile, live authorization, deploy manifest, `T_Live` change,
portfolio admission, correlation waiver, or portfolio-gate change exists.

## 7. Framework Alignment

- No-Trade: exact host/D1/EA/slot/input, label, month, history, spread, quote,
  ATR, fixed-risk, and consumed-month guards.
- Entry: two completed monthly packages, strict return/location agreement,
  one market order, and frozen hard stop.
- Management: malformed, later-month, and 40-day stale repair before entry
  gates.
- Close: framework close reason, broker stop, and kill switch.

## 8. Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-22 | Initial scaffold from approved Q00 card | Magic allocation pending |
