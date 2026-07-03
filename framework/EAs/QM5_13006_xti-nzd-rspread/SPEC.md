# QM5_12837_wti-audnzd-mr - Strategy Spec

**EA ID:** QM5_12837
**Slug:** `wti-audnzd-mr`
**Source:** `EIA-RBA-RBNZ-WTI-FX-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-30

## 1. Strategy Logic

This EA implements a low-frequency structural energy/FX relative-value sleeve
as a three-leg basket on `XTIUSD.DWX`, `AUDUSD.DWX`, and `NZDUSD.DWX`. It
computes the D1 log spread:

`ln(XTIUSD) - beta_aud * ln(AUDUSD) - beta_nzd * ln(NZDUSD)`

If the spread is rich by z-score it sells WTI and buys AUDUSD/NZDUSD. If the
spread is cheap it buys WTI and sells AUDUSD/NZDUSD. The package exits on
spread z-score reversion, max-hold expiry, broken-package repair, Friday close,
or per-leg ATR stops.

This is not a duplicate of the WTI/EURUSD, WTI/AUDUSD, WTI/CAD, WTI/JPY, or
WTI/CHF builds: it uses a three-leg antipodean commodity-FX hedge basket and
z-score reversion rather than a single FX leg, channel breakout, confirmation
filter, calendar rule, inventory event, or oscillator pullback.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_z_lookback_d1` | 120 | 90-180 | Prior spread sample for z-score |
| `strategy_beta_aud` | 0.6 | 0.4-0.8 | AUDUSD coefficient in the log spread |
| `strategy_beta_nzd` | 0.4 | 0.2-0.6 | NZDUSD coefficient in the log spread |
| `strategy_entry_z` | 2.0 | 1.75-2.25 | Absolute z-score needed for entry |
| `strategy_exit_z` | 0.5 | 0.25-0.75 | Absolute z-score package exit |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | Per-leg stop multiplier |
| `strategy_max_hold_days` | 45 | 30-60 | Calendar-day package time stop |
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | XTI entry spread cap |
| `strategy_audusd_max_spread_pts` | 80 | 50-120 | AUDUSD entry spread cap |
| `strategy_nzdusd_max_spread_pts` | 90 | 60-140 | NZDUSD entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Broker deviation points for market legs |
| `strategy_entry_hour_broker` | 0 | 0 | Framework D1 new-bar entry cadence |
| `strategy_entry_minute_broker` | 0 | 0 | Earliest broker minute for daily entry attempt |

## 3. Symbol Universe

- `XTIUSD.DWX` - host chart and WTI leg, magic slot 0.
- `AUDUSD.DWX` - AUD commodity-FX leg, magic slot 1.
- `NZDUSD.DWX` - NZD commodity-FX leg, magic slot 2.
- Logical basket symbol: `QM5_12837_XTI_AUDNZD_MR_D1`.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: one entry attempt per D1 bar through the framework new-bar gate.

## 5. Expected Behaviour

- Expected spread packages/year: about 4-9, default card estimate 6.
- Typical hold: days to several weeks.
- Regime preference: temporary WTI versus AUD/NZD commodity-FX dislocations.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Primary source: U.S. Energy Information Administration working paper, Beckmann,
Czudaj, and Arora, "The Relationship between Oil Prices and Exchange Rates",
June 2017. RBA/RBNZ official material provides central-bank supplement for
commodity-FX and open-economy exchange-rate context. The sources are used only
for mechanism; no performance claim is imported.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
