# QM5_12363_nikh-aroon - Strategy Spec

**EA ID:** QM5_12363
**Slug:** nikh-aroon
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA evaluates one completed D1 bar at a time. It computes Aroon Up and Aroon Down over the last 25 completed D1 bars. It opens a long position when Aroon Up is at least 70 and Aroon Down is at most 30, then exits that long position when Aroon Up is at most 30 and Aroon Down is at least 70. The protective stop is fixed at 2.0 times ATR(14) from entry, with no card-defined take-profit, trailing stop, partial close, or add-on entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_aroon_lookback` | 25 | `2+` | Completed D1 bars used to locate the most recent high and low for Aroon. |
| `strategy_entry_up_level` | 70.0 | `0-100` | Minimum Aroon Up value required for long entry. |
| `strategy_entry_down_level` | 30.0 | `0-100` | Maximum Aroon Down value allowed for long entry. |
| `strategy_exit_up_level` | 30.0 | `0-100` | Maximum Aroon Up value for reversal exit. |
| `strategy_exit_down_level` | 70.0 | `0-100` | Minimum Aroon Down value for reversal exit. |
| `strategy_atr_period` | 14 | `1+` | ATR period for the hard protective stop. |
| `strategy_atr_sl_mult` | 2.0 | `>0` | ATR multiplier for the hard protective stop. |
| `strategy_warmup_bars` | 120 | `>= strategy_aroon_lookback` | Minimum completed D1 history required before signals are allowed. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair with D1 OHLC history suitable for Aroon trend-regime flips.
- `GBPUSD.DWX` - liquid major FX pair with D1 OHLC history suitable for Aroon trend-regime flips.
- `USDJPY.DWX` - liquid major FX pair with D1 OHLC history suitable for Aroon trend-regime flips.
- `XAUUSD.DWX` - liquid metal CFD with D1 OHLC history suitable for trend-regime measurement.
- `GDAXI.DWX` - registered as the available DWX DAX equivalent for the card's `GER40.DWX` target.
- `NDX.DWX` - liquid US index CFD with D1 OHLC history suitable for trend-regime measurement.
- `WS30.DWX` - liquid US index CFD with D1 OHLC history suitable for trend-regime measurement.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; DAX exposure is represented by `GDAXI.DWX`.
- `SP500.DWX` - optional in the card only; not part of the primary P2 basket for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework `OnTick` path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `10` |
| Trade frequency | Daily Aroon(25) regime flips; conservative estimate 6-16 completed trades/year/symbol. |
| Typical hold time | Not specified in frontmatter; expected to be multi-day to multi-week for D1 trend-regime holds. |
| Expected drawdown profile | Main risk is late entry after mature breakouts and slow exit during range transitions. |
| Regime preference | Trend-following, breakout-proxy, signal-reversal-exit, ATR-hard-stop, long-only. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** GitHub repository source file
**Pointer:** https://github.com/Nikhil-Adithyan/Algorithmic-Trading-with-Python/blob/main/Trend/Aroon.py
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12363_nikh-aroon.md`

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
| v1 | 2026-06-11 | Initial build from card | b32604fb-c1ff-4d91-91ba-5a394a5492d3 |
