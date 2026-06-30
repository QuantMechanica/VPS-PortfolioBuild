# QM5_12831_wti-audusd-brk - Strategy Spec

**EA ID:** QM5_12831
**Slug:** `wti-audusd-brk`
**Source:** `EIA-RBA-WTI-AUD-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-30

## 1. Strategy Logic

This EA implements a low-frequency structural energy/FX relative-value sleeve
as a two-leg basket on `XTIUSD.DWX` and `AUDUSD.DWX`. It computes the D1 log
spread `ln(XTIUSD) - beta * ln(AUDUSD)`. A break above the prior spread channel
buys WTI and sells AUDUSD; a break below the channel sells WTI and buys AUDUSD.
The package exits on opposite channel failure, max-hold expiry, broken-package
repair, Friday close, or per-leg ATR stops.

This is not a duplicate of `QM5_12825_wti-eurusd-spread`: that EA fades
XTI/EURUSD z-score extremes, while this build follows XTI/AUDUSD channel
breakouts. It is also distinct from WTI/CAD, WTI event/calendar, XTI/XNG,
energy/metal, XAU/XAG, and XNG RSI sleeves.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_lookback_d1` | 120 | 90-180 | Prior spread channel used for breakout entries |
| `strategy_exit_lookback_d1` | 40 | 20-60 | Prior spread channel used for exits |
| `strategy_beta` | 1.0 | 0.75-1.25 | AUDUSD coefficient in the log spread |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | Per-leg stop multiplier |
| `strategy_max_hold_days` | 35 | 20-55 | Calendar-day package time stop |
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | XTI entry spread cap |
| `strategy_audusd_max_spread_pts` | 80 | 50-120 | AUDUSD entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Broker deviation points for market legs |
| `strategy_entry_hour_broker` | 0 | 0 | Earliest broker hour for daily entry attempt |
| `strategy_entry_minute_broker` | 0 | 0 | Earliest broker minute for daily entry attempt |

## 3. Symbol Universe

- `XTIUSD.DWX` - host chart and WTI leg, magic slot 0.
- `AUDUSD.DWX` - commodity-FX proxy leg, magic slot 1.
- Logical basket symbol: `QM5_12831_XTI_AUDUSD_BRK_D1`.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: one entry attempt per D1 bar through the framework new-bar gate.

## 5. Expected Behaviour

- Expected spread packages/year: about 4-9.
- Typical hold: days to several weeks.
- Regime preference: persistent energy/commodity-FX divergence.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Primary: Beckmann, Czudaj, and Arora, "The Relationship between Oil Prices and
Exchange Rates", U.S. Energy Information Administration working paper, June
2017. Supplement: Reserve Bank of Australia, "Drivers of the Australian Dollar
Exchange Rate". The sources are used only for structural mechanism; no
performance claim is imported.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
