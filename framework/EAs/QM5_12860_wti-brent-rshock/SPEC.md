# QM5_12860_wti-brent-rshock - Strategy Spec

**EA ID:** QM5_12860
**Slug:** `wti-brent-rshock`
**Source:** `CME-WTI-BRENT-SPREAD-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-01

## 1. Strategy Logic

This EA implements a low-frequency, market-neutral crude benchmark basket on
`XTIUSD.DWX` and `XBRUSD.DWX`. It computes the completed-bar
Brent-minus-WTI return spread:

`ln(XBR_t / XBR_t-N) - beta * ln(XTI_t / XTI_t-N)`

The EA standardizes that return spread against a rolling D1 history. A positive
shock opens a short-spread package, selling Brent and buying WTI. A negative
shock opens a long-spread package, buying Brent and selling WTI. Both legs are
closed when the shock normalizes, max hold is exceeded, Friday close fires, or
package integrity breaks.

This is intentionally not a duplicate of `QM5_12843_wti-brent-spread` because
it fades relative-return displacement rather than the price-spread level. It is
also distinct from `QM5_12848_wti-brent-brk`, which follows a channel breakout.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_return_lookback_d1` | 5 | 3-10 | D1 bars in the short relative-return shock |
| `strategy_z_lookback_d1` | 120 | 80-180 | D1 return-spread samples for z-score |
| `strategy_beta` | 1.0 | 0.8-1.2 | Hedge coefficient in return spread |
| `strategy_entry_z` | 2.0 | 1.8-2.3 | Absolute z-score threshold for entry |
| `strategy_exit_z` | 0.35 | 0.25-0.5 | Absolute z-score threshold for exit |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | Per-leg stop multiplier |
| `strategy_max_hold_days` | 10 | 5-15 | Stale package close guard |
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | WTI spread cap |
| `strategy_xbr_max_spread_pts` | 1500 | 1000-2500 | Brent spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Broker deviation points for market legs |

## 3. Symbol Universe

- `XTIUSD.DWX` - host chart and WTI leg, magic slot 0.
- `XBRUSD.DWX` - Brent leg, magic slot 1.
- Logical basket symbol: `QM5_12860_WTI_BRENT_RSHOCK_D1`.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected paired packages/year: about 6-14 before Q02.
- Typical hold: days to two weeks.
- Regime preference: crude benchmark relative-return shock normalization.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

CME Group WTI-Brent Financial Futures, ICE Brent/WTI Futures Spread, and EIA
Brent-WTI spread analysis. No source performance claim is imported.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, AutoTrading, `T_Live`, portfolio admission, or portfolio gate
file is touched by this build.
