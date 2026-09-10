# QM5_41419_wti-wstreak2-cont - Strategy Spec

**EA ID:** QM5_41419  
**Slug:** `wti-wstreak2-cont`  
**Strategy ID:** `MOP-WTI-WSTREAK2-CONT-20260910_S01`  
**Source:** `MOP-WTI-WSTREAK2-CONT-20260910`

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of a new broker week, reconstruct
four consecutive completed broker-week ending closes. Follow only a fresh
two-week same-sign streak whose immediately preceding return has the opposite
strict sign: `-,+,+` buys and `+,-,-` sells for one broker week.

Zero returns, malformed history, nonconsecutive anchors, invalid session
counts, or every other sign path consumes the week flat. The position uses one
fixed-risk budget and a frozen ATR hard stop.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | first-week-bar execution window |
| `strategy_history_bars` | 45 | bounded D1 weekly-endpoint buffer |
| `strategy_required_weeks` | 4 | consecutive completed weekly endpoints |
| `strategy_min_week_bars` | 3 | minimum sessions per week |
| `strategy_max_week_bars` | 5 | maximum sessions per week |
| `strategy_return_epsilon` | 0 | strict sign boundary |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |

All `strategy_*` inputs are locked for Q02. The configuration guard checks
only strategy inputs, EA identity/slot, fixed-risk mode, and the finite `0..1`
stress range; it never equality-pins RNG, news, Friday, or stress defaults.

## 3. Symbol Universe And Timeframe

- Exact host/traded symbol: `XTIUSD.DWX`, D1, slot 0, magic `414190000`.
- Signal and execution timeframe: D1.
- Formation: four consecutive completed Monday-anchored weeks, three to five
  sessions each, using only their final closes.
- Hold: first tick of the next week; ten-day repair ceiling.

## 4. Expected Behaviour

- Approximately eight to sixteen positions per full post-warm-up year; Q02
  retires below five in any full scored year.
- A rolling third same-sign week does not re-enter because the predecessor is
  no longer opposite.
- One fixed-risk WTI position and one consumed attempt per broker week.
- The distinct direct-oil carrier is a diversification hypothesis only; Q09
  alone owns realized correlation.

## 5. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), *Time Series
Momentum*, *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. Canonical bounded packet:
`strategy-seeds/sources/MOP-WTI-WSTREAK2-CONT-20260910/source.md`.

The paper supplies commodity continuation lineage and explicit WTI carrier
membership. The weekly horizon, fresh two-week state, and execution contract
are disclosed QM hypotheses; no source result transfers.

## 6. Risk And Safety Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
There is no live/demo/shadow/stress/optimization setfile, manual tester,
AutoTrading, `T_Live`, deploy/live manifest, portfolio admission, correlation
waiver, portfolio-gate change, external feed, retry, scale-in, grid,
martingale, pyramid, target, trail, or partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-10 | approved new WTI fresh two-week continuation identity | G0 APPROVED; build pending |
| v1-build | 2026-09-10 | governed compile and strict build check | COMPILE_OK; 0 errors/warnings; build-check PASS; 6/6 tests; pin audit clean |
| v1-q02 | 2026-09-10 | paced first-Q02 intake | pending `e1d50eea-cf61-45bd-b897-e4c692461733`; CPU max 70.32% |
