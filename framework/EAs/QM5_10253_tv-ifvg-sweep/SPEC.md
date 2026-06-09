# QM5_10253_tv-ifvg-sweep - Strategy Spec

**EA ID:** QM5_10253
**Slug:** tv-ifvg-sweep
**Source:** c84ae47e-8ea0-56f1-8b25-4436b6dda5b5
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA trades an M15 retest after a liquidity sweep and a completed imbalance. Direction is confirmed by an H4 EMA stack, where EMA(13) must be above EMA(21) above EMA(34) for longs and below for shorts, plus H1 continuation where price and EMA(13) are on the same side of EMA(21). A long setup requires an M15 sell-side sweep, a bullish displacement candle with body at least 1.0 x ATR(14), and a bullish three-bar imbalance; the EA then buys the first retest into that zone. Shorts use the mirrored buy-side sweep and bearish imbalance, with a 2R target, an ATR-buffered sweep stop, and a 32 M15-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_h4_fast_ema | 13 | >= 2 | Fast H4 EMA for directional bias. |
| strategy_h4_mid_ema | 21 | >= 2 | Middle H4 EMA for directional bias. |
| strategy_h4_slow_ema | 34 | >= 2 | Slow H4 EMA for directional bias. |
| strategy_h1_fast_ema | 13 | >= 2 | Fast H1 EMA for continuation confirmation. |
| strategy_h1_mid_ema | 21 | >= 2 | Middle H1 EMA and close filter. |
| strategy_sweep_lookback | 20 | >= 5 | Prior M15 bars used for liquidity sweep high/low. |
| strategy_atr_period | 14 | >= 2 | M15 ATR period for displacement and SL buffer. |
| strategy_displacement_atr | 1.0 | > 0 | Minimum displacement body as a multiple of ATR. |
| strategy_sl_atr_buffer | 0.25 | >= 0 | ATR buffer beyond the sweep extreme for SL. |
| strategy_reward_risk | 2.0 | > 0 | Fixed target in R multiples. |
| strategy_time_stop_m15_bars | 32 | >= 0 | Maximum hold time in M15 bars. |
| strategy_pending_bars | 8 | >= 1 | Pending retest order lifetime in M15 bars. |
| strategy_max_spread_points | 500 | >= 0 | No-trade gate for current spread points. |
| strategy_london_start_hour | 8 | 0-23 | Broker-hour start for London volatility window. |
| strategy_london_end_hour | 11 | 0-23 | Broker-hour end for London volatility window. |
| strategy_ny_start_hour | 13 | 0-23 | Broker-hour start for NY volatility window. |
| strategy_ny_end_hour | 16 | 0-23 | Broker-hour end for NY volatility window. |
| strategy_enforce_m15 | true | true/false | Blocks trading if the chart/test period is not M15. |

---

## 3. Symbol Universe

**Designed for:**
- XAUUSD.DWX - primary card symbol; gold is liquid and suited to sweep/IFVG volatility.
- EURUSD.DWX - card P2 default FX symbol with liquid London and NY sessions.
- GBPUSD.DWX - card P2 default FX symbol with liquid London and NY sessions.
- NDX.DWX - card P2 default index symbol with strong open-window volatility.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - the build must use DWX-backed tester data only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | H4 EMA(13/21/34), H1 close plus EMA(13/21) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 90 |
| Typical hold time | Intraday, capped at 32 M15 bars |
| Expected drawdown profile | Volatility-window continuation drawdowns, controlled by fixed 2R brackets |
| Regime preference | Pullback-continuation / volatility-expansion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c84ae47e-8ea0-56f1-8b25-4436b6dda5b5
**Source type:** TradingView public open-source script
**Pointer:** https://www.tradingview.com/script/x6Xam693-Multicator-Sweeps-IFVG-Zone-Alerts-by-Olu777/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10253_tv-ifvg-sweep.md`

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
| v1 | 2026-06-09 | Initial build from card | 9cd0c4f3-85b8-4ab6-8435-d9f05b684143 |
