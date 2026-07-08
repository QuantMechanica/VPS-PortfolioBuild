# QM5_13054_brent-tom-mom - Strategy Spec

**EA ID:** QM5_13054
**Slug:** `brent-tom-mom`
**Source:** `VANHEMERT-MOMTOM-2014`
**Author of this spec:** Codex
**Last revised:** 2026-07-08

## 1. Strategy Logic

This EA implements a low-frequency structural Brent turn-of-month momentum
sleeve on `XBRUSD.DWX` D1. On each new D1 bar, it allows one entry per
broker-calendar turn-of-month cycle when the completed-D1 return over a fixed
lookback exceeds the positive or negative momentum threshold. The entry
direction follows the momentum sign, with window exit, max-hold exit, and ATR
stop/target.

The strategy is intentionally not a duplicate of the existing energy family:
`QM5_12983_wti-tom-mom` is WTI, `QM5_13009_xng-tom-mom` is natural gas, Brent
calendar cards are fixed month-of-year sleeves, and Brent trend/anchor/spread
cards use different timing and information sets. This EA is a pure Brent
turn-of-month momentum timing sleeve.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_tom_pre_days` | 2 | 1-3 | Calendar days at month end eligible for entry |
| `strategy_tom_post_days` | 3 | 1-3 | Calendar days at month start eligible for entry |
| `strategy_momentum_lookback_days` | 63 | 42-126 | Completed-D1 return lookback |
| `strategy_min_momentum_pct` | 4.0 | 2.5-6.0 | Minimum absolute momentum threshold |
| `strategy_atr_period` | 20 | 14-30 | ATR period for stop/target |
| `strategy_atr_sl_mult` | 2.5 | 2.0-3.0 | ATR stop distance multiplier |
| `strategy_atr_tp_mult` | 3.0 | 2.0-4.0 | ATR target distance multiplier |
| `strategy_max_hold_days` | 6 | 3-8 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1200 | 800-1800 | Brent entry spread cap |

## 3. Symbol Universe

- `XBRUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 6-12.
- Typical hold: several D1 bars inside the turn-of-month window.
- Regime preference: Brent momentum continuation around turn-of-month windows.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Van Hemert, Otto. "The MOM-TOM Effect: Detecting the Market Impact of CTA
Trading." SSRN, 2014, URL
https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2515900.

Moskowitz, Tobias J., Yao Hua Ooi and Lasse Heje Pedersen. "Time Series
Momentum." Journal of Financial Economics, 104(2), 2012, URL
https://docs.lhpedersen.com/TimeSeriesMomentum.pdf.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-08 | Initial build from card | Q02 queued as work_item a803f980-7675-46ca-8498-b22d43ed69b4 |
