# QM5_39005_forexfactory-genesis-matrix-scalper — Strategy Spec

**EA ID:** QM5_39005
**Slug:** `forexfactory-genesis-matrix-scalper`
**Source:** `forexfactory-genesis-matrix-scalper-official-source`
**Author of this spec:** Gemini
**Last revised:** 2026-08-18

---

## 1. Strategy Logic

The strategy implements Realtrader's Genesis Matrix 4-Bar Scalping System on the 5-minute (M5) timeframe. It calculates a 4-layer multi-indicator confluence score evaluating TVI (Tick Volume Indicator), CCI (20), T3-filtered CCI, and Gann High-Low Activator (GHL).

Long entry executes on a closed M5 bar when the Matrix confluence score rises to 4 (all 4 indicators bullish/green) from a previous score below 4 and Close is above the 5-period EMA. Short entry executes when the Matrix score drops to 0 (all 4 indicators bearish/red) from a previous score above 0 and Close is below the 5-period EMA. Stop loss is placed beyond recent swing structure with a 2.0-pip buffer, clamped between 0.5 and 3.5 ATR, and take profit is targeted at 2.0 times the stop distance (1:2.0 R:R). Open trades are closed when any Matrix indicator changes color (Matrix score drops below 4 for longs or rises above 0 for shorts).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `InpCCIPeriod` | 20 | 14-30 | Matrix CCI lookback period |
| `InpT3Period` | 5 | 3-8 | T3 smoothing factor |
| `InpT3Hot` | 0.618 | 0.5-0.8 | T3 volume hot factor (b) |
| `InpGHLPeriod` | 10 | 5-15 | Gann High-Low activator period |
| `InpTVIPeriod` | 12 | 8-20 | TVI EMA lookback period |
| `strategy_atr_period` | 14 | 7-28 | ATR period on M5 |
| `strategy_sl_buffer_pips` | 2.0 | 1.0-5.0 | Stop loss buffer beyond swing structure in pips |
| `strategy_tp_rr` | 2.0 | 1.5-3.5 | Take profit risk-to-reward multiple |
| `strategy_swing_lookback` | 10 | 5-20 | Swing structure lookback bars |
| `strategy_be_trigger_pips` | 15.0 | 10.0-25.0 | Break-even trigger distance in pips |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Primary liquid FX pair with tight spread and high tick volume suitable for M5 matrix scalping.
- `GBPUSD.DWX` — Volatile FX pair with distinct directional runs aligning with 4-indicator matrix confluence.

**Explicitly NOT for:**
- Non-DWX symbols absent from `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `PERIOD_M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_M5)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 150 |
| Typical hold time | 15-60 minutes |
| Expected drawdown profile | < 2.9% maximum drawdown |
| Regime preference | High-momentum intraday trends and clean multi-indicator breakout scalps |
| Win rate target (qualitative) | High (70-75% win rate) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `forexfactory-genesis-matrix-scalper-official-source`
**Source type:** `forum`
**Pointer:** `Realtrader (2012-2024). Genesis Matrix Trading System. Forex Factory.`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_39005_forexfactory-genesis-matrix-scalper.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-18 | Initial build from card | Gemini build pass |
