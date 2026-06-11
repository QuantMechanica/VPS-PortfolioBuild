# QM5_11740_rfs-momentum-sma-m15 - Strategy Spec

**EA ID:** QM5_11740
**Slug:** rfs-momentum-sma-m15
**Source:** b5a932a2-40b6-5628-840b-d5069ac35c4a (see `sources/rfs-robo-forex-strategy-compilation`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades M15 momentum continuation on major FX pairs. A long entry is opened on the new bar after Momentum(30) crosses above 100, SMA(11) is above SMA(21), and the last closed price is above both SMA lines. A short entry mirrors the rule with Momentum crossing below 100, SMA(11) below SMA(21), and the last closed price below both SMA lines. Positions close when RSI(14) reaches the card exit zone: above 70 for longs or below 30 for shorts; initial protection is 2x ATR(14) stop loss plus a 3x ATR(14) safety take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_timeframe | PERIOD_M15 | M15 expected | Signal timeframe from the card |
| strategy_momentum_period | 30 | >= 1 | Momentum lookback period |
| strategy_momentum_level | 100.0 | > 0 | Momentum crossing level |
| strategy_fast_sma_period | 11 | >= 1 | Fast SMA trend confirmation |
| strategy_slow_sma_period | 21 | >= 1 | Slow SMA trend confirmation |
| strategy_rsi_period | 14 | >= 1 | RSI exit period |
| strategy_rsi_overbought | 70.0 | 0-100 | Long exit threshold |
| strategy_rsi_oversold | 30.0 | 0-100 | Short exit threshold |
| strategy_atr_period | 14 | >= 1 | ATR period for stop and safety target |
| strategy_atr_sl_mult | 2.0 | > 0 | Stop loss distance in ATR multiples |
| strategy_atr_tp_mult | 3.0 | > 0 | Hard safety take profit distance in ATR multiples |
| strategy_session_start_hour | 9 | 0-23 | Broker-time session start |
| strategy_session_end_hour | 24 | 0-24 | Broker-time session end |
| strategy_max_spread_points | 0 | >= 0 | Optional spread block; 0 disables because the card does not specify a threshold |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed major FX pair with DWX M15 data.
- GBPUSD.DWX - card-listed major FX pair with DWX M15 data.
- USDJPY.DWX - card-listed major FX pair with DWX M15 data.
- USDCHF.DWX - card-listed major FX pair with DWX M15 data.
- AUDUSD.DWX - card-listed major FX pair with DWX M15 data.

**Explicitly NOT for:**
- Non-FX index and commodity symbols - the approved card targets FX majors only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Not specified by card; expected intraday to multi-session from RSI exit mechanics |
| Expected drawdown profile | Not specified by card; ATR stop bounds per-trade loss |
| Regime preference | Trend-following momentum during London/New York sessions |
| Win rate target (qualitative) | Not specified by card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b5a932a2-40b6-5628-840b-d5069ac35c4a
**Source type:** strategy compilation PDF
**Pointer:** Anonymous, "Momentum Forex Trading", Robo-forex Strategy Compilation, `362359657-Robo-forex-strategy.pdf`, page 36, robofx.com
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11740_rfs-momentum-sma-m15.md`

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
| v1 | 2026-06-11 | Initial build from card | 88faa09b-6951-4c9f-8d55-7341eb3f7a75 |
