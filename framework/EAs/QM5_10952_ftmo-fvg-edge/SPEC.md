# QM5_10952_ftmo-fvg-edge - Strategy Spec

**EA ID:** QM5_10952
**Slug:** ftmo-fvg-edge
**Source:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades three-candle fair value gaps on closed M15 bars during London and New York broker-time sessions. A bullish setup exists when the latest closed candle's low is above the high from two bars earlier and the middle candle closed bullish; the EA places a buy limit at the near edge of that gap, with the stop at the middle candle's low and a 2.0R target. A bearish setup mirrors the rule with the latest closed candle's high below the low from two bars earlier, a bearish middle candle, a sell limit at the near edge, the stop at the middle candle's high, and a 2.0R target. Pending orders expire after four completed candles, the EA keeps only one active position or pending order per symbol and magic, moves to breakeven after the TP1 trigger, trails behind same-direction FVGs, and exits after 24 M15 bars if no broker SL/TP exit has fired.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_london_start_hour | 7 | 0-23 | Broker-time hour when the London session gate opens. |
| strategy_london_end_hour | 16 | 0-23 | Broker-time hour when the London session gate closes. |
| strategy_ny_start_hour | 13 | 0-23 | Broker-time hour when the New York session gate opens. |
| strategy_ny_end_hour | 22 | 0-23 | Broker-time hour when the New York session gate closes. |
| strategy_pending_expiry_bars | 4 | 1-96 | Number of completed bars after which an unfilled FVG limit order expires. |
| strategy_time_exit_bars | 24 | 1-288 | Maximum holding time in base-timeframe bars. |
| strategy_tp_rr | 2.0 | 0.1-10.0 | Final take-profit multiple of initial stop risk. |
| strategy_tp1_rr | 1.0 | 0.1-5.0 | Profit multiple used as the breakeven and FVG trailing activation trigger. |
| strategy_max_spread_stop_fraction | 0.12 | 0.0-1.0 | Maximum allowed spread as a fraction of planned stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid major FX pair listed in the approved R3 basket.
- GBPUSD.DWX - liquid major FX pair listed in the approved R3 basket.
- XAUUSD.DWX - liquid gold CFD listed in the approved R3 basket.
- NDX.DWX - liquid index CFD listed in the approved R3 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no DWX test data is available.
- Illiquid or weekend-only markets - the card requires liquid London and New York session FVG formation.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 |
| Typical hold time | Up to 24 M15 bars, about 6 broker-time hours |
| Expected drawdown profile | False retracements and session volatility can cluster losses; spread and news filters reduce event-slippage exposure. |
| Regime preference | Intraday price-action continuation after displacement gaps |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Source type:** blog
**Pointer:** FTMO, "Boost Your Trading Edge with the Fair Value Gap Strategy", 2025-03-28, https://ftmo.com/en/blog/boost-your-trading-edge-with-the-fair-value-gap-strategy/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10952_ftmo-fvg-edge.md`

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
| v1 | 2026-06-06 | Initial build from card | 86eed3c2-583a-4928-80f0-68edfef39d1d |
