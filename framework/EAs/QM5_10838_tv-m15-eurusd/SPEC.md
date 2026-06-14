# QM5_10838_tv-m15-eurusd - Strategy Spec

**EA ID:** QM5_10838
**Slug:** `tv-m15-eurusd`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

This EA trades a session-filtered Bollinger mean-reversion setup in the direction of an EMA(200) trend filter. A long setup requires the setup bar to close above EMA(200), below the lower Bollinger Band(20, 2), with RSI(14) above 30; the next closed bar must close back inside the lower band or above the setup bar high. Shorts mirror the rule above EMA and the upper band. The EA uses a 1 ATR stop, capped to the nearer recent swing point, a 1.5R target, dynamic breakeven after 1R, middle-band early exit, and end-of-day flattening before the IST session close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 200 | 50-300 | EMA trend-bias period. |
| `strategy_bb_period` | 20 | 10-40 | Bollinger Band lookback. |
| `strategy_bb_deviation` | 2.0 | 1.0-3.0 | Bollinger Band deviation multiplier. |
| `strategy_rsi_period` | 14 | 5-30 | RSI guard period. |
| `strategy_rsi_long_min` | 30.0 | 20.0-40.0 | Long entries require setup-bar RSI above this value. |
| `strategy_rsi_short_max` | 70.0 | 60.0-80.0 | Short entries require setup-bar RSI below this value. |
| `strategy_atr_period` | 14 | 5-30 | ATR period for initial stop distance. |
| `strategy_atr_sl_mult` | 1.0 | 0.5-2.0 | ATR multiple for the initial stop. |
| `strategy_target_rr` | 1.5 | 1.0-2.5 | Fixed target as a multiple of initial risk. |
| `strategy_swing_lookback` | 5 | 2-20 | Recent swing lookback for stop cap. |
| `strategy_ist_start_hour` | 11 | 0-23 | IST session start hour. |
| `strategy_ist_start_minute` | 30 | 0-59 | IST session start minute. |
| `strategy_ist_end_hour` | 22 | 0-23 | IST session end hour. |
| `strategy_ist_end_minute` | 0 | 0-59 | IST session end minute. |
| `strategy_eod_flat_minutes_before` | 15 | 0-60 | Minutes before session end to flatten open positions. |
| `strategy_max_spread_points` | 0 | 0-500 | Optional spread cap in points; 0 preserves the card by disabling this extra cap. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - primary source market named by the card.
- `GBPUSD.DWX` - portable major FX pair from the card's R3 P2 basket.
- `USDJPY.DWX` - portable major FX pair from the card's R3 P2 basket.
- `XAUUSD.DWX` - liquid DWX metal from the card's R3 P2 basket.
- `GDAXI.DWX` - verified DWX DAX custom symbol used for the card's `GER40.DWX` basket leg.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; registered as `GDAXI.DWX` instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` |
| Typical hold time | Intraday, flat before IST session close |
| Expected drawdown profile | Session-filtered trend-continuation losses during strong news-driven moves |
| Regime preference | Mean-reversion with trend filter |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `TradingView open-source strategy`
**Pointer:** `https://www.tradingview.com/script/sbopOeJ5-M15-v2/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10838_tv-m15-eurusd.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-14 | Initial build from card | 5008f970-97dd-4c05-b391-d4af98334418 |
