# QM5_12835_wti-usdchf-brk - Strategy Spec

**EA ID:** QM5_12835
**Slug:** `wti-usdchf-brk`
**Source:** `EIA-SNB-WTI-CHF-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-30

## 1. Strategy Logic

This EA implements a low-frequency structural energy/FX relative-value sleeve
as a two-leg basket on `XTIUSD.DWX` and `USDCHF.DWX`. It computes WTI in CHF
terms as `ln(XTIUSD) + beta * ln(USDCHF)`. A break above the prior spread
channel buys WTI and buys USDCHF; a break below the channel sells WTI and sells
USDCHF. The package exits on opposite channel failure, max-hold expiry,
broken-package repair, Friday close, or per-leg ATR stops.

This is not a duplicate of `QM5_12825_wti-eurusd-spread`, which fades
XTI/EURUSD z-score extremes; not `QM5_12831_wti-audusd-brk`, which follows an
AUD commodity-FX minus-log spread; and not `QM5_12834_wti-jpy-spread`, which is
WTI/USDJPY z-score mean reversion. It is also distinct from WTI/CAD, WTI
event/calendar, XTI/XNG, energy/metal, XAU/XAG, and XNG RSI sleeves.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_lookback_d1` | 120 | 90-180 | Prior CHF-terms spread channel used for breakout entries |
| `strategy_exit_lookback_d1` | 40 | 20-60 | Prior CHF-terms spread channel used for exits |
| `strategy_beta` | 1.0 | 0.75-1.25 | USDCHF coefficient in the plus-log spread |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | Per-leg stop multiplier |
| `strategy_max_hold_days` | 35 | 20-55 | Calendar-day package time stop |
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | XTI entry spread cap |
| `strategy_usdchf_max_spread_pts` | 80 | 50-120 | USDCHF entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Broker deviation points for market legs |
| `strategy_entry_hour_broker` | 0 | 0 | Earliest broker hour for daily entry attempt |
| `strategy_entry_minute_broker` | 0 | 0 | Earliest broker minute for daily entry attempt |

## 3. Symbol Universe

- `XTIUSD.DWX` - host chart and WTI leg, magic slot 0.
- `USDCHF.DWX` - CHF safe-haven FX leg, magic slot 1.
- Logical basket symbol: `QM5_12835_XTI_USDCHF_BRK_D1`.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: one entry attempt per D1 bar through the framework new-bar gate.

## 5. Expected Behaviour

- Expected spread packages/year: about 4-9.
- Typical hold: days to several weeks.
- Regime preference: persistent WTI/CHF risk repricing.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Primary: Beckmann, Czudaj, and Arora, "The Relationship between Oil Prices and
Exchange Rates", U.S. Energy Information Administration working paper, June
2017. Supplement: Swiss National Bank, "The Swiss franc as a safe-haven
currency", SNB Quarterly Bulletin 2020 Q2. The sources are used only for
structural mechanism; no performance claim is imported.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
