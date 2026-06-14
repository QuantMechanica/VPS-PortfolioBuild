# QM5_10782_tv-smc-btc-r3 - Strategy Spec

**EA ID:** QM5_10782
**Slug:** `tv-smc-btc-r3`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see TradingView source citation in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades M15 mitigation touches of a recent order-block zone only in the direction of the H1 EMA trend. A long setup requires M15 close above H1 EMA(200), bullish break of structure above a confirmed swing high, a bearish previous-candle order block, optional bullish fair value gap confirmation, a recent liquidity sweep, and a discount-zone order block below the midpoint of the active swing range. A short setup mirrors the rule below H1 EMA(200), with bearish BOS, bullish previous-candle order block, optional bearish FVG, recent buy-side liquidity sweep, and premium-zone location. Stop loss is placed at the order block edge with optional ATR buffer, target is fixed R:R, and discretionary exit occurs on opposite BOS.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_htf_ema_tf` | `PERIOD_H1` | M15-H4 tested axis | Higher timeframe for trend EMA. |
| `strategy_ema_period` | `200` | 100-200 tested axis | EMA length for trend permission. |
| `strategy_swing_length` | `4` | 3-8 tested axis | Bars on each side used to confirm swing highs/lows. |
| `strategy_structure_lookback` | `80` | 20-200 | Closed M15 bars scanned for recent swing structure. |
| `strategy_liquidity_lookback` | `7` | 5-10 tested axis | Bars used to define recent liquidity. |
| `strategy_liquidity_tol_pct` | `0.10` | 0.05-0.20 tested axis | Percent tolerance around recent liquidity for sweep validation. |
| `strategy_require_fvg` | `true` | true/false tested axis | Require three-candle fair value gap confirmation near the order block. |
| `strategy_require_pd_zone` | `true` | true/false tested axis | Require long OB in discount and short OB in premium. |
| `strategy_atr_period` | `14` | 5-50 | ATR period for optional OB stop buffer. |
| `strategy_atr_buffer_mult` | `0.0` | 0.0-2.0 | ATR buffer added beyond the order-block stop edge. |
| `strategy_rr_target` | `3.0` | 2.0-3.0 tested axis | Fixed reward:risk target. |
| `strategy_max_spread_points` | `0.0` | 0.0+ | Optional spread cap; zero disables because the card has no spread filter. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - Card R3 includes gold CFDs for OHLC-derived SMC transfer.
- `GDAXI.DWX` - Matrix-valid DAX proxy for card-stated `GER40.DWX`.
- `NDX.DWX` - Card R3 includes Nasdaq index CFD transfer.
- `WS30.DWX` - Card R3 includes Dow index CFD transfer.
- `EURUSD.DWX` - Card R3 includes major FX transfer.
- `GBPUSD.DWX` - Card R3 includes major FX transfer.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `PERIOD_H1` EMA(200), with H4 as later parameter axis |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` |
| Typical hold time | Card does not state a numeric hold time; trades hold until SL, 1:3 TP, opposite BOS, or framework flat. |
| Expected drawdown profile | Transfer risk is elevated because source was BTC/EUR-specific; fixed R:R and OB stops bound per-trade loss. |
| Regime preference | Trend-following SMC mitigation after BOS and liquidity sweep. |
| Win rate target (qualitative) | Medium; source uses fixed 1:3 R:R, so win rate can be below 50%. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** `https://www.tradingview.com/script/ZyPd3ENh/`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10782_tv-smc-btc-r3.md`

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
| v1 | 2026-06-14 | Initial build from card | 5e904ac3-6b98-4401-ab60-9c154e31dbc9 |
