# QM5_9941_ff-5x5-hilo-break-h1 — Strategy Spec

**EA ID:** QM5_9941
**Slug:** `ff-5x5-hilo-break-h1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

On each completed H1 bar, compute a "5x5" channel: EMA(5) applied to H1 High prices and EMA(5) applied to H1 Low prices, each read at buffer position (ema_shift + 1) to emulate a 5-bar forward shift. A long entry fires when the completed H1 bar opens AND closes above the high channel AND the prior bar did NOT close above its channel (fresh break). Short mirrors: completed bar opens AND closes below the low channel AND prior bar did not close below. Entry executes at the next H1 open (market order at tick). Exit: 2R TP at entry, 10-bar time stop, or when a completed H1 bar opens AND closes on the opposite side of the channel.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 5 | 2-20 | EMA period for the H/L channel |
| `strategy_ema_shift` | 5 | 1-20 | Forward-shift (buffer offset) for channel read |
| `strategy_sl_pips` | 40 | 10-100 | Fixed SL in pips when use_atr_sl=false |
| `strategy_use_atr_sl` | false | bool | Switch to ATR-based volatility SL |
| `strategy_atr_period` | 14 | 5-50 | ATR period when use_atr_sl=true |
| `strategy_atr_sl_mult` | 0.8 | 0.5-2.0 | ATR floor multiplier for SL |
| `strategy_atr_sl_cap_mult` | 1.5 | 1.0-3.0 | ATR cap multiplier for SL ceiling |
| `strategy_tp_rr` | 2.0 | 1.0-5.0 | TP = tp_rr × SL distance (R-multiple) |
| `strategy_max_hold_bars` | 10 | 3-50 | Time stop: max H1 bars before forced exit |
| `strategy_spread_pct_max` | 12.0 | 5-30 | Max spread as % of SL; skip if exceeded |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX pair; H1 5x5 channel well-suited to EUR/USD trend structure
- `GBPUSD.DWX` — liquid GBP/USD; similar trend characteristics to EUR/USD
- `USDCAD.DWX` — USD/CAD; commodity-linked moves with clean H1 breakout patterns
- `USDJPY.DWX` — USD/JPY; risk-on/risk-off trending pair suitable for channel-break entries

**Explicitly NOT for:**
- Index CFDs (NDX.DWX, WS30.DWX) — card specifies FX major basket only

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
| Trades / year / symbol | ~65 |
| Typical hold time | 2-10 H1 bars (2-10 hours) |
| Expected drawdown profile | Intraday; multiple small losses between breakout wins |
| Regime preference | trend-continuation / breakout |
| Win rate target (qualitative) | medium (2R target partially compensates) |

---

## 6. Source Citation

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** jamesagnew, "1 hour system trade with stochastics", ForexFactory, 2025, https://www.forexfactory.com/thread/1346623-1-hour-system-trade-with-stochastics?page=2 (posts #27–#33)
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9941_ff-5x5-hilo-break-h1.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-11 | Initial build from card | 6900a237-d065-4885-830d-d2db0100e234 |
