# QM5_9970_ff-369ema-scalp-m5 - Strategy Spec

**EA ID:** QM5_9970
**Slug:** ff-369ema-scalp-m5
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades the ForexFactory 3/6/9 EMA M5 scalp. It enters long on the next M5 bar when EMA(3) crosses from below to above both EMA(6) and EMA(9), provided EMA(6) is at least EMA(9) or is rising over the prior two closed bars. It enters short on the mirrored cross below both slower EMAs. Each trade uses a 20-pip hard stop, a 10-pip fixed target, a cross-back exit if EMA(3) reverses through EMA(6) or EMA(9), and a 12-bar M5 time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_signal_tf | PERIOD_M5 | M5 expected | Timeframe used for EMA signals and time-stop bar duration. |
| strategy_ema_fast | 3 | 2-20 | Fast EMA period from the source system. |
| strategy_ema_mid | 6 | 3-50 | Middle EMA period from the source system. |
| strategy_ema_slow | 9 | 4-100 | Slow EMA period from the source system. |
| strategy_stop_pips | 20 | 1-100 | Fixed hard stop in pips. |
| strategy_take_profit_pips | 10 | 1-100 | Fixed profit target in pips. |
| strategy_max_hold_bars | 12 | 1-100 | Maximum holding time in signal-timeframe bars. |
| strategy_max_spread_stop_fraction | 0.10 | 0.01-1.00 | Maximum spread as a fraction of stop distance. |
| strategy_session_filter_enabled | true | true/false | Enables London/NY entry-hour filter. |
| strategy_london_start_hour_broker | 7 | 0-23 | Broker-hour start for London entry window. |
| strategy_london_end_hour_broker | 12 | 0-23 | Broker-hour end for London entry window. |
| strategy_ny_start_hour_broker | 13 | 0-23 | Broker-hour start for New York entry window. |
| strategy_ny_end_hour_broker | 20 | 0-23 | Broker-hour end for New York entry window. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - primary liquid FX major suited to M5 EMA scalping.
- GBPUSD.DWX - liquid FX major from the approved P2 basket.
- USDJPY.DWX - liquid FX major from the approved P2 basket.
- AUDUSD.DWX - liquid FX major from the approved P2 basket.

**Explicitly NOT for:**
- Non-FX index and commodity symbols - the card R3 basket is FX-only and does not authorize cross-asset expansion.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) through the framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 240 |
| Typical hold time | Up to 12 M5 bars, about 60 minutes before time stop |
| Expected drawdown profile | Frequent small winners and fixed 20-pip loss events, sensitive to spread. |
| Regime preference | Intraday momentum scalp during liquid London and New York FX hours |
| Win rate target (qualitative) | Medium to high, due to 10-pip target versus 20-pip stop |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** https://www.forexfactory.com/thread/252779-369-ema-system
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9970_ff-369ema-scalp-m5.md`

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
| v1 | 2026-06-11 | Initial build from card | 57db94db-7837-4038-ba87-0b24d685db6a |
