# QM5_11697_pl-bb20-m5-scalp-d1trend - Strategy Spec

**EA ID:** QM5_11697
**Slug:** pl-bb20-m5-scalp-d1trend
**Source:** 53a42802-5c56-515a-af4e-2c89ce420488
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades M5 Bollinger Band pullbacks only in the direction of the D1 trend. A bullish D1 trend is current D1 close above SMA(200); in that regime, the EA waits for the last closed M5 bar to touch or pierce the lower BB(20,2), close bullish, and then places a buy stop one pip above that bar high. A bearish D1 trend mirrors the rule with an upper-band touch, bearish M5 candle, and sell stop one pip below the bar low.

Pending stop orders expire after one M5 bar. Protective risk is a 2x ATR(14,M5) stop, take profit is fixed at 20 pips, and open positions move stop loss to break-even after 10 pips in profit. The session gate defaults to the card's 07:00-17:00 CET/CEST intent translated to 08:00-18:00 broker time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_bb_period | 20 | >=2 | Bollinger Band period on M5. |
| strategy_bb_deviation | 2.0 | >0 | Bollinger Band standard deviation multiplier. |
| strategy_d1_sma_period | 200 | >=2 | D1 SMA period used for trend direction. |
| strategy_atr_period | 14 | >=1 | ATR period on M5 for protective stop distance. |
| strategy_atr_sl_mult | 2.0 | >0 | ATR multiplier for initial stop loss. |
| strategy_entry_offset_pips | 1 | >=0 | Stop-entry offset beyond the trigger candle high or low. |
| strategy_take_profit_pips | 20 | >0 | Fixed take-profit distance in pips. |
| strategy_breakeven_pips | 10 | >0 | Profit threshold that moves SL to entry. |
| strategy_pending_expire_bars | 1 | >=1 | Number of bars before an unfilled stop order expires. |
| strategy_session_start_hour_broker | 8 | 0-23 | Broker-time session start after CET/CEST translation. |
| strategy_session_end_hour_broker | 18 | 0-23 | Broker-time session end after CET/CEST translation. |
| strategy_max_spread_pips | 0 | >=0 | Optional spread cap; 0 disables the cap and allows zero-spread DWX tests. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed liquid M5 FX major.
- GBPUSD.DWX - card-listed liquid M5 FX major.
- USDJPY.DWX - card-listed liquid M5 FX major.
- AUDUSD.DWX - card-listed liquid M5 FX major.
- USDCAD.DWX - card-listed liquid M5 FX major.

**Explicitly NOT for:**
- Indices, metals, energy, and non-listed FX crosses - the approved card targets the five listed FX pairs only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | D1 close and SMA(200) trend filter |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 400 |
| Typical hold time | Not specified in card frontmatter; expected intraday M5 scalp hold due 20-pip TP and 10-pip break-even. |
| Expected drawdown profile | Not specified in card frontmatter; fixed 2x ATR initial risk per trade. |
| Regime preference | D1 trend with M5 pullback continuation. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 53a42802-5c56-515a-af4e-2c89ce420488
**Source type:** book
**Pointer:** Paul Langer, "A Scalping Strategy", in The Black Book of Forex Trading, Alura Publishing, 2015, pp. 64-70; local PDF archive.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11697_pl-bb20-m5-scalp-d1trend.md` frontmatter.

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
| v1 | 2026-06-20 | Initial build from card | caec0fcd-df89-4c5a-b2cb-8fa7f6101fbe |
