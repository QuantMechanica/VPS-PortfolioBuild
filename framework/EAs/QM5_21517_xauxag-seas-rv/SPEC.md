# QM5_21517_xauxag-seas-rv — Strategy Spec

**EA ID:** QM5_21517

**Slug:** `xauxag-seas-rv`

**Strategy ID:** `KELOHARJU-SCHWEIKERT-XAUXAG-SEASRV-2026_S01`

**Source:** `KELOHARJU-SCHWEIKERT-XAUXAG-SEASRV-2026`

**Author:** Codex

**Last revised:** 2026-08-14

## 1. Strategy Logic

On the first tradable `XAUUSD.DWX` D1 bar of each broker month, reconstruct
the exact just-completed XAU-minus-XAG monthly log return. Compare it with the
arithmetic mean and sample standard deviation of the same relative calendar-
month return in up to ten earlier years, requiring at least five exactly
synchronized samples and excluding the realized observation.

Fade a strict positive seasonal surprise above `+0.50 + 1e-10` by selling XAU
and buying XAG. Fade a strict negative surprise below `-0.50 - 1e-10` with the
opposite package. Consume inside-band or invalid months flat. Close and
recompute at the next broker-month transition.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_history_years` | 10 | Earlier same-calendar years inspected |
| `strategy_min_history_years` | 5 | Minimum synchronized paired samples |
| `strategy_history_bars` | 4000 | Bounded D1 reconstruction buffer |
| `strategy_completed_months` | 1 | Exact just-completed formation month |
| `strategy_surprise_entry_z` | 0.50 | Strict seasonal-surprise entry band |
| `strategy_signal_epsilon` | 1e-10 | Threshold comparison tolerance |
| `strategy_variance_epsilon` | 1e-16 | Fail-closed variance floor |
| `strategy_atr_period_d1` | 20 | Completed per-leg ATR estimator |
| `strategy_atr_sl_mult` | 3.5 | Frozen per-leg stop distance |
| `strategy_max_hold_days` | 40 | Monthly stale guard |
| `strategy_xau_max_spread_pts` | 1500 | XAU entry spread cap |
| `strategy_xag_max_spread_pts` | 3000 | XAG entry spread cap |
| `strategy_deviation_points` | 20 | Basket order deviation |

All baseline values are locked; no parameter sweep is authorized.

## 3. Symbol Universe

- Logical basket: `QM5_21517_XAU_XAG_SEASRV_D1`.
- Host/traded slot 0: `XAUUSD.DWX`, magic `215170000`.
- Companion/traded slot 1: `XAGUSD.DWX`, magic `215170001`.
- Both legs are orders. There is no read-only or external state symbol.

## 4. Timeframe

- Host and both signal inputs: D1.
- Decision/reset: first genuine D1 bar of each broker-calendar month.
- Formation uses completed month-end D1 observations only.

## 5. Expected Behaviour

- Approximately 6-9 two-leg packages/year after warm-up; Q02 retires below
  five completed packages per full year.
- Direction: always one long metal and one short metal.
- Risk: one `RISK_FIXED=1000` package budget split equally by stop risk.
- Hold: one broker month, capped by 40 days, orphan repair, or per-leg stop.
- Friday close and both news axes are disabled for the monthly native-price
  Q02 baseline.

## 6. Source Citation

Keloharju, Linnainmaa, and Nyberg (2016), *The Journal of Finance* 71(4),
1557-1590, supplies the same-calendar commodity expectation. Schweikert
(2018), *Journal of Banking & Finance* 88, and Yaya, Vo, and Olayinka (2021),
*Resources Policy* 72, supply the state-dependent gold/silver relationship.
CME supplies the relative-value carrier. The exact conjunction is a QM
falsification hypothesis.

The evidence boundary is
`strategy-seeds/sources/KELOHARJU-SCHWEIKERT-XAUXAG-SEASRV-2026/source.md`;
the approved execution card is
`strategy-seeds/cards/approved/QM5_21517_xauxag-seas-rv_card.md`.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each leg receives half the aggregate stop-risk budget
and a frozen `3.5*ATR(20,D1)` hard stop. Any order or final-package failure
flattens the owned exposure and consumes the month.

Opposite legs do not prove dollar, beta, volatility, factor, or portfolio
neutrality. There is no live setfile, deploy artifact, correlation waiver, or
portfolio-gate change.

## 8. Framework Alignment

- No-Trade: exact host/slot/input, risk/news/Friday contract, magic, spread,
  quote, stop, lot, package, and consumed-month guards.
- Entry: completed-month mapping, synchronized same-calendar sample,
  realized-minus-mean sample score, inverse package, shared fixed risk, and
  atomic repair.
- Management: old-month, 40-day stale, orphan, direction, magic, and missing-
  stop repair before entry-only gates.
- Close: framework basket close, per-leg broker stops, and kill switch.

## 9. Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-14 | Initial build from approved G0 card | Q01 PASS; Q02 enqueued |
