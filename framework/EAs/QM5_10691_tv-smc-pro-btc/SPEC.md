# QM5_10691_tv-smc-pro-btc - Strategy Spec

**EA ID:** QM5_10691
**Slug:** tv-smc-pro-btc
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades a closed-bar H4/H1 structure confluence. A long entry requires bullish H4 and H1 structure breaks, the most recent bearish order-block candle before the bullish displacement, a bullish fair-value gap overlapping that order-block zone, and a recent sell-side liquidity sweep. A short entry mirrors the same logic with bearish structure, the last bullish order-block candle, bearish fair-value-gap overlap, and a buy-side liquidity sweep. Baseline exits are the broker stop below or above the order block with a 0.3 percent buffer, capped at 3 ATR(14), and a fixed 2R take-profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_direction_tf | PERIOD_H4 | H4, D1 | Higher timeframe used for direction BOS or CHoCH confirmation |
| strategy_confirmation_tf | PERIOD_H1 | H1, H4 | Lower confirmation timeframe used for entry structure, OB, FVG, and sweep checks |
| strategy_selective_mode | false | true or false | Enables premium or discount filter when true; P2 baseline uses Aggressive mode |
| strategy_swing_length | 10 | 6-20 | Number of closed bars used to define structure breaks and liquidity sweeps |
| strategy_ob_lookback | 15 | 10-20 | Number of confirmation timeframe bars searched for the last opposite candle order block |
| strategy_fvg_lookback | 15 | 10-20 | Number of confirmation timeframe bars searched for fair-value-gap overlap |
| strategy_sweep_memory_bars | 20 | 10-30 | Number of confirmation timeframe bars allowed since the liquidity sweep |
| strategy_atr_period | 14 | 1+ | ATR period used for the 3 ATR stop-distance cap |
| strategy_sl_buffer_pct | 0.30 | 0.0+ | Percent buffer beyond the order-block low or high for the raw stop |
| strategy_max_stop_atr | 3.00 | 0.1+ | Maximum allowed stop distance in ATR units |
| strategy_rr | 2.00 | 1.5-2.5 | Take-profit distance as risk:reward multiple |
| strategy_max_spread_points | 0 | 0+ | Optional spread gate; 0 disables it |

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - Primary P2 index port from the BTC source to a liquid DWX Nasdaq CFD.
- GDAXI.DWX - Matrix-valid DAX custom symbol used as the available replacement for the card's GER40.DWX label.
- XAUUSD.DWX - Liquid metal CFD with OHLC structure suitable for OB, FVG, and sweep rules.
- EURUSD.DWX - Liquid FX major with DWX OHLC data suitable for the structure rules.
- GBPJPY.DWX - Liquid FX cross named in the card's P2 basket.

**Explicitly NOT for:**
- BTCUSDT - Source market only; no DWX crypto feed is required or registered for P2.
- GER40.DWX - Card label is not present in `dwx_symbol_matrix.csv`; GDAXI.DWX is the registered DAX equivalent.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | H4 direction, H1 confirmation |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 18 |
| Typical hold time | Not specified in card; expected to be hours to several days from H4/H1 structure plus 2R target |
| Expected drawdown profile | Low-frequency SMC confluence with risk from over-selectivity and HTF signal lag |
| Regime preference | Volatility-expansion structure break after liquidity sweep |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView strategy
**Pointer:** https://www.tradingview.com/script/QMvHkvdQ-SMC-Pro-BTC-ICT-Order-Blocks-FVG-DOE/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10691_tv-smc-pro-btc.md`

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
| v1 | 2026-06-14 | Initial build from card | 1a9d4e6e-e845-444c-8140-a68b187c4153 |
