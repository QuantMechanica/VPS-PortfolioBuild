# QM5_10566_mql5-ravi-hist — Strategy Spec

**EA ID:** QM5_10566
**Slug:** `mql5-ravi-hist`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `artifacts/source_notes/b8b5125a-c67f-5bbc-baff-33456e08f5b2.md`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA computes a RAVI histogram as `100 * (EMA(fast) - EMA(slow)) / EMA(slow)` on the selected signal timeframe. It opens long when the last closed RAVI value breaks upward through the overbought threshold from below, and opens short when it breaks downward through the oversold threshold from above. Long positions close when RAVI returns below the long breakout threshold or flips bearish; short positions close when RAVI returns above the short breakout threshold or flips bullish. Broker SL/TP use the P2 baseline ATR stop and fixed reward-to-risk target from the card.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | MT5 timeframe enum | Timeframe used for closed-bar RAVI signal evaluation. |
| `strategy_fast_ma_period` | `7` | `1+`, less than slow period | Fast EMA length used in the RAVI calculation. |
| `strategy_slow_ma_period` | `65` | `2+`, greater than fast period | Slow EMA length used in the RAVI calculation. |
| `strategy_high_level` | `0.1` | greater than low level | Overbought breakout threshold for long entries and long exits. |
| `strategy_low_level` | `-0.1` | less than high level | Oversold breakout threshold for short entries and short exits. |
| `strategy_atr_period` | `14` | `1+` | ATR lookback used for the hard stop distance. |
| `strategy_atr_sl_mult` | `2.0` | `> 0` | ATR multiple for the hard stop. |
| `strategy_rr_target` | `1.5` | `> 0` | Reward-to-risk multiple for the take-profit target. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` — source test symbol and card-listed DWX FX target.
- `GBPUSD.DWX` — card-listed DWX FX target for portable RAVI momentum breakout testing.
- `EURUSD.DWX` — card-listed major FX target with dense DWX history.
- `XAUUSD.DWX` — card-listed metals target for portable oscillator breakout testing.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` — not valid for DWX P2 registration.
- Non-FX/metals symbols not named by this card — not part of this approved build scope.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `40` |
| Typical hold time | hours to days on H4 threshold breakouts |
| Expected drawdown profile | ATR-defined losses with 1.5R targets; moderate trade frequency. |
| Regime preference | oscillator breakout / trend acceleration |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/16100`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10566_mql5-ravi-hist.md`

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
| v1 | 2026-05-29 | Initial build from card | d614ff14-9394-4b54-bfad-1434a30cd9e1 |
