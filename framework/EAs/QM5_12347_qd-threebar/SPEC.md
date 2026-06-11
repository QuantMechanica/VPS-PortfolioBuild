# QM5_12347_qd-threebar - Strategy Spec

**EA ID:** QM5_12347
**Slug:** qd-threebar
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab (see `constverum/Quantdom`, `examples/simple_strategies.py`, `ThreeBarStrategy`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA evaluates completed bars on the chart timeframe. If the last `strategy_high_bars` closed bars all closed above their opens, it opens or reverses to long on the next bar. If the last `strategy_low_bars` closed bars all closed at or below their opens, it opens or reverses to short on the next bar. Every entry uses a hard stop at `strategy_atr_sl_mult * ATR(strategy_atr_period)` and no take-profit; framework Friday close remains active.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_high_bars` | 3 | 2-4 in P3 | Consecutive bullish closed bars required for a long signal. |
| `strategy_low_bars` | 3 | 2-4 in P3 | Consecutive bearish closed bars required for a short signal. |
| `strategy_min_warmup_bars` | 80 | >= max streak | Minimum completed bars before new entries are allowed. |
| `strategy_atr_period` | 14 | >= 1 | ATR lookback used for the hard stop. |
| `strategy_atr_sl_mult` | 2.0 | 1.5-2.5 in P3 | ATR multiplier for the hard stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX pair with portable OHLC bars.
- `GBPUSD.DWX` - card-listed liquid FX pair with portable OHLC bars.
- `USDJPY.DWX` - card-listed liquid FX pair with portable OHLC bars.
- `XAUUSD.DWX` - card-listed metal with portable OHLC bars.
- `GDAXI.DWX` - canonical local DAX symbol used for card-stated `GER40.DWX`.
- `NDX.DWX` - card-listed US index CFD with portable OHLC bars.
- `WS30.DWX` - card-listed US index CFD with portable OHLC bars.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.
- `SP500.DWX` - card marks it optional backtest-only, not part of the primary P2 basket.

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
| Trades / year / symbol | 120 |
| Typical hold time | Hours to days, until an opposite three-bar streak, ATR stop, or Friday close. |
| Expected drawdown profile | Whipsaw-prone in alternating candle regimes. |
| Regime preference | Candle-streak reversal / stop-and-reverse. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** GitHub source file
**Pointer:** https://github.com/constverum/Quantdom/blob/master/examples/simple_strategies.py, `ThreeBarStrategy`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12347_qd-threebar.md`

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
| v1 | 2026-06-11 | Initial build from card | f0118107-7f60-4cb1-af1d-f01bad4bf3bc |
