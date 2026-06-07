# QM5_11120_ma-price-cross - Strategy Spec

**EA ID:** QM5_11120
**Slug:** ma-price-cross
**Source:** 0693c604-4f96-56ef-be79-15efe9f48b86 (see `strategy-seeds/sources/0693c604-4f96-56ef-be79-15efe9f48b86/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

This EA trades the close crossing a 25-period simple moving average on completed H4 bars. It goes long when the previous completed close was below SMA(25) and the latest completed close is above SMA(25). It goes short when the previous completed close was above SMA(25) and the latest completed close is below SMA(25). Positions exit on the opposite close-through-SMA signal or after 12 H4 bars, with an initial stop at 2.0 x ATR(14).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | MT5 timeframe enum | Timeframe used for the close, SMA, ATR, and max-hold rules. |
| `strategy_sma_period` | `25` | `> 0` | Simple moving average period used for the price-cross signal. |
| `strategy_atr_period` | `14` | `> 0` | ATR period used for initial stop placement. |
| `strategy_atr_sl_mult` | `2.0` | `> 0.0` | ATR multiplier for the initial stop distance. |
| `strategy_max_hold_bars` | `12` | `>= 0` | Maximum holding period in strategy timeframe bars; `0` disables the time exit. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 includes this liquid major FX pair for OHLC/SMA/ATR testing.
- `GBPUSD.DWX` - Card R3 includes this liquid major FX pair for OHLC/SMA/ATR testing.
- `USDJPY.DWX` - Card R3 includes this liquid major FX pair for OHLC/SMA/ATR testing.
- `XAUUSD.DWX` - Card R3 includes gold, which supports OHLC/SMA/ATR testing in the DWX matrix.

**Explicitly NOT for:**
- Symbols outside the card's R3 basket - they are not registered for this EA in `magic_numbers.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | Up to 12 H4 bars, about 48 hours, unless an opposite cross exits first. |
| Expected drawdown profile | Stop-defined single-position exposure with 2.0 x ATR(14) initial risk. |
| Regime preference | Trend transition and price-cross continuation regimes. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Source type:** GitHub repository
**Pointer:** EarnForex `Moving-Average-with-Alert`, `MQL5/Indicators/MQLTA MT5 Moving Average With Alert.mq5`, function `IsSignal`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11120_ma-price-cross.md`

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
| v1 | 2026-06-07 | Initial build from card | a55fbfd1-effe-4a37-8443-2451860eed4e |
