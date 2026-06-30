# QM5_1446_demark-td-open-range-h4 - Strategy Spec

**EA ID:** QM5_1446
**Slug:** demark-td-open-range-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

The EA trades a DeMark TD Open fade on H4 bars. At the first H4 bar of a new broker day it compares the session open with the prior broker-day high-low envelope; a gap above the prior high creates a sell setup, while a gap below the prior low creates a buy setup. The setup must return into the prior-day envelope within the first four H4 bars, the trigger bar must close in the fade direction, the gap must be between 0.40 and 2.50 D1 ATR(20), and the D1 SMA(50) slope must be flat or aligned with the fade. Exits are a 60% partial at half gap close, broker TP at prior-day close, end-of-day close, or six-H4-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_signal_tf | PERIOD_H4 | H4 expected | Base timeframe for TD Open detection. |
| strategy_atr_period | 20 | >0 | ATR period for H4 stop distance and D1 gap qualifier. |
| strategy_d1_sma_period | 50 | >1 | D1 SMA period for macro-bias slope. |
| strategy_gap_min_d1_atr_mult | 0.40 | >=0 | Minimum absolute open gap versus prior close as D1 ATR multiple. |
| strategy_gap_max_d1_atr_mult | 2.50 | > min | Maximum absolute open gap versus prior close as D1 ATR multiple. |
| strategy_return_window_h4_bars | 4 | 1-12 | Number of first-day H4 bars allowed to return into the prior envelope. |
| strategy_entry_slippage_atr | 0.15 | >=0 | Card slippage model for entry interpretation; market entry executes through framework. |
| strategy_sl_atr_mult | 0.50 | >0 | ATR buffer beyond the day open extreme for initial SL. |
| strategy_sl_cap_atr_mult | 2.00 | >0 | Maximum initial SL distance from entry in H4 ATR multiples. |
| strategy_tp1_close_fraction | 0.60 | 0-1 | Fraction closed at the midpoint between reference open and prior close. |
| strategy_time_stop_bars | 6 | >0 | Time-stop in H4 bars after entry. |
| strategy_eod_close_hour_broker | 22 | 0-23 | Broker hour for same-day forced exit. |
| strategy_news_filter_enabled | true | true/false | Enables card-level high-impact news blackout around the reference open. |
| strategy_news_window_h4_bars | 2 | >=0 | High-impact news blackout width on each side of the reference open, in H4 bars. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - FX major with native H4 OHLC and daily broker session boundaries.
- GBPUSD.DWX - FX major with native H4 OHLC and daily broker session boundaries.
- USDJPY.DWX - FX major with native H4 OHLC and daily broker session boundaries.
- AUDUSD.DWX - FX major with native H4 OHLC and daily broker session boundaries.
- USDCAD.DWX - FX major with native H4 OHLC and daily broker session boundaries.
- NDX.DWX - DWX index CFD named in the card's R3 portable index basket.
- WS30.DWX - DWX index CFD named in the card's R3 portable index basket.
- GDAXI.DWX - DWX DAX index CFD named in the card's R3 portable index basket.
- UK100.DWX - DWX FTSE index CFD named in the card's R3 portable index basket.
- XAUUSD.DWX - DWX metal CFD named by the card's XAUUSD portability statement.
- XTIUSD.DWX - DWX oil CFD resolving the card's oil CFD portability statement.

**Explicitly NOT for:**
- SPX500.DWX, SPY.DWX, ES.DWX - unavailable canonical DWX symbols; use SP500.DWX only when a card specifically calls for S&P exposure.
- Non-DWX symbols - build and backtest registries require the `.DWX` suffix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 ATR(20), D1 SMA(50) slope |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) via framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Same broker day; maximum six H4 bars, but usually exits by end-of-day. |
| Expected drawdown profile | Intraday mean-reversion losses cluster when gap continuation persists. |
| Regime preference | Mean-reversion after meaningful daily-open gaps. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum and book lineage
**Pointer:** D:/QM/strategy_farm/artifacts/cards_approved/QM5_1446_demark-td-open-range-h4.md
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1446_demark-td-open-range-h4.md`

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
| v1 | 2026-06-30 | Initial build from card | 90ddccc0-2e60-40f8-9bbd-72593342c43d |
