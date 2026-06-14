# QM5_10761_tv-vortex - Strategy Spec

**EA ID:** QM5_10761
**Slug:** tv-vortex
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see TradingView source citation in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades the H1 Vortex Confluence Protocol as a directional confluence score. A long trade requires bullish structure, optional BOS/CHoCH confirmation, non-bearish RSI, MTF trend, and smart-money layers, plus enough confirming layers to reach the configured minimum score; short trades mirror the same tests bearish. The score combines structure, RSI momentum, tick-volume confirmation, higher-timeframe trend, liquidity sweep, smart-money candle context, optional fair-value-gap context, and ADX regime allowance. Exits are by the framework SL/TP, optional ATR trailing, and Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_enable_longs | true | true/false | Allow bullish confluence entries. |
| strategy_enable_shorts | true | true/false | Allow bearish confluence entries. |
| strategy_min_score | 3 | 3-5 tested | Minimum confluence score needed for entry. |
| strategy_pivot_strength | 5 | 3/5/8 tested | Pivot/BOS lookback strength. |
| strategy_require_bos | true | true/false tested | Require a close beyond recent structure. |
| strategy_require_fvg | false | true/false tested | Require a same-direction fair-value gap. |
| strategy_rsi_period | 14 | 14/21 tested | RSI momentum period. |
| strategy_volume_ma_period | 20 | >=2 | Tick-volume average period for confirmation. |
| strategy_volume_threshold | 1.0 | 1.0/1.2/1.5 tested | Required volume multiple over average. |
| strategy_adx_filter_enabled | true | true/false tested | Enable ADX trend-regime filter. |
| strategy_adx_period | 14 | >=1 | ADX period for regime check. |
| strategy_adx_min | 20.0 | >0 | Minimum ADX when the regime filter is enabled. |
| strategy_mtf_timeframe | PERIOD_H4 | MT5 timeframe | Higher timeframe used for trend confirmation. |
| strategy_mtf_trend_length | 50 | >=2 | MA length for MTF trend direction. |
| strategy_session_enabled | true | true/false | Enable session gate. |
| strategy_session_start_hour | 0 | 0-23 | Broker-hour session start. |
| strategy_session_end_hour | 24 | 0-24 | Broker-hour session end. |
| strategy_atr_period | 14 | >=1 | ATR period for stops and trailing. |
| strategy_atr_sl_mult | 1.5 | 1.0/1.5/2.0 tested | ATR stop multiplier. |
| strategy_structure_atr_buffer | 0.2 | >=0 | ATR buffer behind recent swing stop. |
| strategy_rr_target | 2.0 | 1.5/2.0/2.5 tested | Take-profit multiple of stop distance. |
| strategy_swing_lookback | 20 | >=2 | Recent swing lookback for structural stop. |
| strategy_trailing_enabled | false | true/false | Optional ATR trailing; P2 baseline starts OFF. |
| strategy_trailing_atr_mult | 1.5 | >0 | ATR multiplier for optional trailing. |
| strategy_max_spread_points | 0 | >=0 | Optional spread gate; 0 disables the gate. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - FX major from the card R3 portable basket.
- GBPUSD.DWX - FX major from the card R3 portable basket.
- USDJPY.DWX - FX major from the card R3 portable basket.
- XAUUSD.DWX - canonical DWX gold symbol for the card's XAUUSD target.
- GDAXI.DWX - available DAX DWX equivalent for the card's GER40.DWX target.
- NDX.DWX - US index from the card R3 portable basket.
- WS30.DWX - US index from the card R3 portable basket.

**Explicitly NOT for:**
- GER40.DWX - not present in dwx_symbol_matrix.csv; mapped to GDAXI.DWX.
- XAUUSD - missing the required DWX suffix; mapped to XAUUSD.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | PERIOD_H4 trend confirmation by default |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | not specified in card frontmatter |
| Expected drawdown profile | not specified in card frontmatter |
| Regime preference | trend / confluence / volatility-expansion |
| Win rate target (qualitative) | not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/XtP27UK6-Vortex-Confluence-Protocol-JOAT/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10761_tv-vortex.md`

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
| v1 | 2026-06-14 | Initial build from card | 32b31bc4-8641-432f-9edf-ebd110f42611 |
