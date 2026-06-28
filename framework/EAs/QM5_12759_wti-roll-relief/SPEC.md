# QM5_12759_wti-roll-relief - Strategy Spec

**EA ID:** QM5_12759
**Slug:** `wti-roll-relief`
**Source:** `CFTC-ETF-ROLL-WTI-2014`
**Author of this spec:** Codex
**Last revised:** 2026-06-29

## 1. Strategy Logic

This EA implements a low-frequency structural WTI ETF roll-relief sleeve on
`XTIUSD.DWX`. On each new D1 bar, it first checks whether the current month
already showed confirmed pressure during broker D1 trading days 5 through 9:
at least one completed D1 bar in that window must close down by the configured
threshold and below SMA(`strategy_trend_period`). If that proof exists, the EA
permits one long entry during trading days 10 through 14 when the prior
completed D1 bar closes up by the reclaim threshold and above the same SMA.

The position is flattened when the relief window ends, the month changes, the
prior close falls below the SMA, or the fixed max-hold guard is reached. This
is not a duplicate of `QM5_12736_wti-roll-fade`, which shorts inside the
pressure window, or `QM5_12743_wti-postroll-fade`, which uses CME futures
expiry timing. It is also separate from WTI weekday/month, WPSR, OPEC,
refinery, hurricane, SPR, CAD/oil, XTI/XNG, XAU/XAG, and XNG pullback sleeves.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_pressure_start_trading_day` | 5 | 4-6 | First broker D1 trading day used for pressure proof |
| `strategy_pressure_end_trading_day` | 9 | 8-10 | Last broker D1 trading day used for pressure proof |
| `strategy_relief_start_trading_day` | 10 | 9-11 | First broker D1 trading day eligible for relief entry |
| `strategy_relief_end_trading_day` | 14 | 13-15 | Last broker D1 trading day eligible for relief entry |
| `strategy_min_pressure_return_pct` | 0.10 | 0.05-0.20 | Minimum same-month pressure-bar decline |
| `strategy_min_reclaim_return_pct` | 0.10 | 0.05-0.20 | Minimum prior D1 reclaim advance |
| `strategy_trend_period` | 20 | 14-30 | SMA period for pressure, reclaim, and failure gates |
| `strategy_atr_period` | 20 | 14-30 | ATR period for the hard stop |
| `strategy_atr_sl_mult` | 2.50 | 2.0-3.0 | ATR stop distance multiplier |
| `strategy_max_hold_days` | 5 | 3-7 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-8.
- Typical hold: 1-5 D1 bars.
- Regime preference: same-month early WTI roll pressure followed by a D1
  reclaim during the post-pressure relief window.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Mou, Y., "Predatory or Sunshine Trading? Evidence from Crude Oil ETF Rolls",
CFTC Office of the Chief Economist, URL
https://www.cftc.gov/sites/default/files/idc/groups/public/@economicanalysis/documents/file/oce_predatorysunshine0314.pdf.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
