# QM5_10419_et-spm-macd - Strategy Spec

**EA ID:** QM5_10419
**Slug:** et-spm-macd
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA trades the completed-bar MACD(5,13,6) signal on M5. It opens long when both MACD and signal are above zero and MACD crosses above the signal line; it opens short when both are below zero and MACD crosses below the signal line. The initial stop is 1.5 times ATR(20), and trades with a stop distance below four times the current spread are rejected. Positions close on the opposite MACD cross, histogram zero-line loss, or after 24 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_M5` | M5, M15 from card tests | Timeframe used for MACD, ATR, and max-hold bars |
| `strategy_macd_fast` | 5 | > 0 and below slow | MACD fast EMA period |
| `strategy_macd_slow` | 13 | > fast | MACD slow EMA period |
| `strategy_macd_signal` | 6 | > 0 | MACD signal smoothing period |
| `strategy_atr_period` | 20 | > 0 | ATR period for initial stop distance |
| `strategy_atr_stop_mult` | 1.5 | > 0 | Multiplier applied to ATR for the initial stop |
| `strategy_max_hold_bars` | 24 | > 0 | Time exit in signal-timeframe bars |
| `strategy_session_filter_on` | true | true / false | Enables the broker-time session gate |
| `strategy_session_start_hhmm` | 800 | 0000-2359 | Broker-time start of the liquid-session window |
| `strategy_session_end_hhmm` | 2200 | 0000-2359 | Broker-time end of the liquid-session window |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - card primary S&P 500 index proxy; backtest-only custom symbol is available.
- `NDX.DWX` - Nasdaq 100 index CFD fits the liquid US large-cap index basket.
- `WS30.DWX` - Dow 30 index CFD fits the liquid US large-cap index basket.
- `GDAXI.DWX` - available DAX custom symbol used as the DWX equivalent for the card's `GER40.DWX`.
- `XAUUSD.DWX` - liquid metal symbol explicitly listed by the card.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | Intraday, capped at 24 M5 bars |
| Expected drawdown profile | Whipsaw-prone in ranging markets due to simple MACD crosses |
| Regime preference | Intraday momentum / reversal after zero-line confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/spm-boot-camp.141888/page-9
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10419_et-spm-macd.md`

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
| v1 | 2026-05-25 | Initial build from card | 868cf9e2-3816-4591-9344-47af112e16db |
