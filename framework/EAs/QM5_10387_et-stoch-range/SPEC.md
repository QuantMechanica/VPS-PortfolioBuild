# QM5_10387_et-stoch-range - Strategy Spec

**EA ID:** QM5_10387
**Slug:** et-stoch-range
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA runs on M1 bars and treats each broker day as a session. It tracks the session high and low until Stochastic %K first reaches the configured extreme threshold, then freezes those two prices as the buy and sell breakout levels for the rest of the day. It opens long when the last closed bar crosses above the frozen high and opens short when the last closed bar crosses below the frozen low, with one position per symbol and magic. It exits on the opposite frozen-level cross or in the final 30 minutes of the broker-day session.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_stoch_k_period` | 14 | 5-30 | Stochastic %K period used for the first oscillator extreme. |
| `strategy_stoch_d_period` | 3 | 1-10 | Stochastic %D period. |
| `strategy_stoch_slowing` | 3 | 1-10 | Stochastic slowing period. |
| `strategy_trigger_threshold` | 90.0 | 80.0-95.0 | %K value that freezes the session range. |
| `strategy_atr_period` | 20 | 10-50 | ATR period used for the protective stop cap. |
| `strategy_atr_stop_cap_mult` | 1.0 | 0.75-1.0 | Maximum stop distance as a multiple of ATR. |
| `strategy_min_range_spreads` | 6.0 | 4.0-10.0 | Minimum frozen range width measured in current spreads. |
| `strategy_session_start_hour` | 0 | 0-23 | Broker-hour session start. |
| `strategy_session_end_hour` | 24 | 1-24 | Broker-hour session end. |
| `strategy_no_entry_final_minutes` | 30 | 0-120 | Minutes before session end when new entries are blocked and open positions are closed. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 index exposure named in the card; valid backtest-only custom symbol.
- `NDX.DWX` - Nasdaq 100 index exposure from the portable US index basket.
- `WS30.DWX` - Dow 30 index exposure from the portable US index basket.
- `GDAXI.DWX` - DWX DAX 40 equivalent used for the card's GER40 target.
- `EURUSD.DWX` - Liquid FX pair named in the approved card.
- `XAUUSD.DWX` - Liquid metals symbol named in the approved card.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P 500 variants; use `SP500.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | intraday, minutes to one broker session |
| Expected drawdown profile | Noisy M1 breakout profile with ATR-capped protective stops and same-day exits. |
| Regime preference | breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/need-help-to-code.53610/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10387_et-stoch-range.md`

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
| v1 | 2026-05-25 | Initial build from card | af7dc956-d284-489c-8e15-6e4f57fcfc07 |
