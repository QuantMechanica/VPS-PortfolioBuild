# QM5_1117_hopwood-rsi-pullback-h1 - Strategy Spec

**EA ID:** QM5_1117
**Slug:** hopwood-rsi-pullback-h1
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades H1 pullbacks in the direction of an EMA(200) trend filter. It buys when price is above EMA(200) and RSI(14) crosses back above 30 from oversold on the last closed H1 bar, and sells when price is below EMA(200) and RSI(14) crosses back below 70 from overbought. Each entry uses a market order on the next bar with an ATR(14) x 1.5 initial stop. The EA exits when RSI touches the opposite band, when the last closed H1 close crosses the wrong side of EMA(200), or when the position has been held for 48 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 14 | 2-100 | RSI lookback on H1 closes. |
| `strategy_ema_period` | 200 | 20-400 | H1 EMA period for trend direction. |
| `strategy_atr_period` | 14 | 2-100 | ATR lookback for initial stop sizing. |
| `strategy_atr_sl_mult` | 1.5 | 0.5-5.0 | ATR multiple used for the initial stop. |
| `strategy_rsi_oversold` | 30.0 | 1.0-49.0 | Long trigger and short exit RSI band. |
| `strategy_rsi_overbought` | 70.0 | 51.0-99.0 | Short trigger and long exit RSI band. |
| `strategy_max_hold_h1_bars` | 48 | 1-240 | Maximum H1 holding period before exit. |
| `strategy_max_spread_points` | 20 | 0-200 | Blocks new trades only when modeled spread exceeds this cap. |
| `strategy_session_filter_on` | false | true/false | Optional London/New York style session filter; default P2 is 24/5. |
| `strategy_session_start_h` | 0 | 0-23 | Broker-time session start hour when the optional filter is enabled. |
| `strategy_session_end_h` | 24 | 0-24 | Broker-time session end hour when the optional filter is enabled. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major listed in the card's R3 PASS basket.
- `GBPUSD.DWX` - FX major listed in the card's R3 PASS basket.
- `USDJPY.DWX` - FX major listed in the card's R3 PASS basket.
- `AUDUSD.DWX` - FX major listed in the card's R3 PASS basket.
- `USDCAD.DWX` - FX major listed in the card's R3 PASS basket.
- `EURJPY.DWX` - FX cross listed in the card's R3 PASS basket.

**Explicitly NOT for:**
- Non-FX index and commodity `.DWX` symbols - not listed in the approved card basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | Intraday to 48 H1 bars maximum |
| Expected drawdown profile | ATR-stopped trend-pullback losses with one position per symbol per magic |
| Regime preference | Pullback in trend with RSI mean reversion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** ForexFactory Steve Hopwood hub at `https://www.forexfactory.com/thread/282290`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1117_hopwood-rsi-pullback-h1.md`

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
| v1 | 2026-06-18 | Initial build from card | 4516e4f5-66c1-4be1-9c5d-4015e26330ad |
