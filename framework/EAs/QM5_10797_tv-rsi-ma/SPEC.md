# QM5_10797_tv-rsi-ma - Strategy Spec

**EA ID:** QM5_10797
**Slug:** tv-rsi-ma
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA trades the TradingView RSI + MA crossover rule on the H1 baseline. It computes RSI on close and a simple moving average of that RSI; a long setup occurs when RSI crosses below its RSI moving average, and a short setup occurs when RSI crosses above it. Existing positions are closed on the cached opposite setup or after the optional 24 H1-bar time stop. Every entry gets the V5 safety stop at ATR(14) times 2.0, with position size supplied by the framework risk model.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `signal_timeframe` | `PERIOD_CURRENT` | `PERIOD_CURRENT`, `PERIOD_H4` | Timeframe used for RSI and RSI-MA signal reads. |
| `rsi_period` | `14` | `7`, `14`, `21` | RSI lookback length from the card test axis. |
| `rsi_ma_period` | `9` | `5`, `9`, `14` | Simple moving average length applied to RSI values. |
| `use_reverse_trade` | `false` | `false`, `true` | Swaps long and short crossover interpretation for the card's P3 ablation. |
| `atr_period` | `14` | `14` baseline | ATR lookback for the V5 safety stop. |
| `atr_sl_mult` | `2.0` | `1.5`, `2.0`, `3.0` | ATR multiplier for the hard stop. |
| `time_stop_h1_bars` | `24` | `0`, `24`, `48` | Optional maximum holding time measured in H1 bars; `0` disables it. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Liquid DWX forex major from the card's P2 basket.
- `GBPUSD.DWX` - Liquid DWX forex major from the card's P2 basket.
- `USDJPY.DWX` - Liquid DWX forex major from the card's P2 basket.
- `XAUUSD.DWX` - Canonical DWX gold symbol for the card's `XAUUSD` basket item.
- `GDAXI.DWX` - Canonical DAX DWX symbol used in place of card-stated `GER40.DWX`.
- `NDX.DWX` - Liquid DWX Nasdaq 100 index from the card's P2 basket.
- `WS30.DWX` - Liquid DWX Dow 30 index from the card's P2 basket.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `dwx_symbol_matrix.csv`; DAX exposure is registered as `GDAXI.DWX`.
- `XAUUSD` - Unsuffixed symbols are not used in research or backtest artifacts.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | Optional `H4` signal timeframe via `signal_timeframe` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` |
| Typical hold time | Up to 24 H1 bars when the time stop is enabled; otherwise until opposite crossover or ATR stop. |
| Expected drawdown profile | Choppy-market overtrading risk from oscillator crossovers. |
| Regime preference | Mean-reversion / oscillator crossover. |
| Win rate target (qualitative) | Medium; card does not publish a numeric target. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** TradingView script `RSI + MA Strategy`, author `The-4xdev-company`, published 2021-11-23, https://www.tradingview.com/script/EZTODAmX-RSI-MA-Strategy/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10797_tv-rsi-ma.md`

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
| v1 | 2026-06-05 | Initial build from card | 8f603062-d85b-4168-81bf-474526afa903 |
