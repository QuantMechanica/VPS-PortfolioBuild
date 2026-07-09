# QM5_13091_xbr-vrp-proxy - Strategy Spec

**EA ID:** QM5_13091
**Slug:** `xbr-vrp-proxy`
**Source:** `TROLLE-SCHWARTZ-ENERGY-VRP-2008_XBR_PROXY`
**Author of this spec:** Codex
**Last revised:** 2026-07-09

## 1. Strategy Logic

This EA implements a low-frequency Brent realized-volatility proxy for the energy
variance-risk-premium literature on `XBRUSD.DWX`. It does not consume option
chains or variance swap rates. On each new D1 bar it computes a 20-D1
realized-volatility estimate and ranks it against a one-year rolling realized
volatility history.

Entries are allowed only in top-quartile realized-volatility regimes. The EA
then fades short-horizon return stretches back toward a slow D1 mean: long
after a high-volatility downside stretch with a bullish reversal candle, short
after the mirrored upside stretch with a bearish reversal candle. Positions use
ATR hard stop, SMA mean-reversion exit, realized-volatility percentile exit,
max-hold exit, standard V5 news and Friday close handling, and no runtime
external data.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rv_period` | 20 | 10-30 | D1 log-return window for realized volatility |
| `strategy_rv_rank_lookback` | 252 | 126-378 | Rolling RV samples for percentile rank |
| `strategy_entry_rv_percentile` | 0.75 | 0.65-0.90 | Minimum RV percentile for entries |
| `strategy_exit_rv_percentile` | 0.50 | 0.35-0.65 | Vol-normalization exit threshold |
| `strategy_return_lookback` | 5 | 3-10 | D1 return-stretch lookback |
| `strategy_min_return_atr` | 1.20 | 0.80-1.80 | Minimum absolute return stretch in ATR units |
| `strategy_mean_period` | 50 | 40-100 | D1 mean-reversion SMA period |
| `strategy_min_stretch_atr` | 0.40 | 0.20-0.80 | Minimum close-to-SMA stretch in ATR units |
| `strategy_atr_period` | 20 | 14-30 | ATR period for stop and stretch scaling |
| `strategy_atr_sl_mult` | 2.75 | 2.0-3.5 | ATR stop distance |
| `strategy_max_hold_days` | 10 | 5-15 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XBRUSD.DWX` only, magic slot 0.
- `XBRUSD.DWX` has active local Brent routes in `framework/registry/magic_numbers.csv`;
  Q02 validates current synchronized D1 history and fills.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 5-12.
- Direction: symmetric long/short.
- Typical hold: several D1 bars, capped by ATR stop, SMA mean-reversion,
  realized-volatility normalization, and stale-position guards.
- Regime preference: high realized-volatility Brent stretches.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

- Trolle, Anders B. and Schwartz, Eduardo S., "Variance risk premia in energy
  commodities", July 2008 public paper copy:
  https://www.anderson.ucla.edu/documents/areas/fac/finance/schwartz_risk_premia.pdf
- BIS Working Papers No. 619, "Volatility risk premia and future commodities
  returns": https://www.bis.org/publ/work619.pdf

The sources define energy volatility-risk-premium lineage. Runtime uses only
Darwinex MT5 OHLC and broker state; this EA is an explicit realized-volatility
spot-CFD proxy, not an option-implied VRP replication.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
