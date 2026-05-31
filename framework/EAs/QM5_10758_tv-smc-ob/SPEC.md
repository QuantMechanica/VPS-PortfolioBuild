# QM5_10758_tv-smc-ob - Strategy Spec

**EA ID:** QM5_10758
**Slug:** `tv-smc-ob`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades a Smart Money Concepts family with two entry paths on closed H1 bars. Breakout mode buys when the latest close breaks above a recent confirmed resistance pivot and sells when it breaks below a recent confirmed support pivot, with ATR percentile volatility confirmation. Order-block mode buys after consecutive bearish candles create a bullish order-block zone and a strong bullish rejection closes out of that zone; short entries mirror the rule after consecutive bullish candles. Exits are handled by the initial ATR or optional structure stop, optional fixed 2R cap, ATR trailing after the configured R-multiple, and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_pivot_lookback` | 20 | 10-40 | Bars searched for support, resistance, and order-block context. |
| `strategy_pivot_wing` | 2 | 1-5 | Left/right bars required to confirm a pivot high or low. |
| `strategy_mode` | `STRATEGY_MODE_COMBINED` | breakout/order-block/combined | Selects breakout-only, order-block-only, or combined family logic. |
| `strategy_atr_period` | 14 | 10-20 | ATR period for volatility, stops, and trailing. |
| `strategy_vol_lookback` | 50 | 20-100 | ATR sample window used for percentile-style volatility filtering. |
| `strategy_vol_percentile_min` | 50.0 | 40.0-60.0 | Minimum ATR percentile rank required before entry. |
| `strategy_atr_sl_mult` | 2.0 | 1.5-2.5 | Initial ATR stop multiplier. |
| `strategy_trail_activation_r` | 1.5 | 1.0-2.0 | Profit in R before ATR trailing activates. |
| `strategy_trail_atr_mult` | 2.0 | 1.5-2.5 | ATR multiplier used by the trailing stop. |
| `strategy_use_fixed_2r_cap` | false | true/false | Enables the card's fixed 2R cap variant when true. |
| `strategy_use_structure_stop` | false | true/false | Uses pivot or order-block structure stop instead of default ATR stop when true. |
| `strategy_structure_atr_buffer` | 0.25 | 0.0-1.0 | ATR buffer beyond the active pivot or order-block zone for structure stops. |
| `strategy_max_stop_atr_mult` | 4.0 | 2.0-6.0 | Maximum stop distance cap in ATR units. |
| `strategy_ob_min_candles` | 2 | 2-5 | Consecutive opposite-color candles required to define an order block. |
| `strategy_rejection_body_min` | 0.55 | 0.4-0.8 | Minimum body-to-range ratio for a rejection candle. |
| `strategy_supertrend_enabled` | false | true/false | Enables the source-noted Supertrend-style confirmation filter. |
| `strategy_supertrend_period` | 10 | 10 or 14 | Period used by the Supertrend-style confirmation filter. |
| `strategy_supertrend_mult` | 3.0 | 2.0-4.0 | ATR multiplier used by the Supertrend-style confirmation filter. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid DWX FX pair named in the card's R3 basket.
- `GBPUSD.DWX` - liquid DWX FX pair named in the card's R3 basket.
- `USDJPY.DWX` - liquid DWX FX pair named in the card's R3 basket.
- `XAUUSD.DWX` - DWX gold symbol normalized from the card's `XAUUSD` name.
- `GDAXI.DWX` - canonical DWX DAX symbol used for the card's `GER40.DWX` index exposure.
- `NDX.DWX` - liquid DWX Nasdaq index symbol named in the card's R3 basket.
- `WS30.DWX` - liquid DWX Dow index symbol named in the card's R3 basket.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; registered as `GDAXI.DWX`.
- `XAUUSD` - missing the DWX suffix required for registry and backtest artifacts.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | Card frontmatter does not specify; expected hours to days from H1/H4 ATR trailing. |
| Expected drawdown profile | Card frontmatter does not specify; fixed-risk volatility-breakout drawdown should cluster in failed breakout regimes. |
| Regime preference | Volatility-expansion breakout and order-block rejection regimes. |
| Win rate target (qualitative) | Medium; source relies on ATR stop/trailing rather than fixed high win-rate targeting. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView protected-source strategy page
**Pointer:** `https://www.tradingview.com/script/BEXoyi7K-Smart-Money-Breakout-Order-Block-Strategy/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10758_tv-smc-ob.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-31 | Initial build from card | 242b0f38-2758-43d9-9b0b-2c471895e284 |
