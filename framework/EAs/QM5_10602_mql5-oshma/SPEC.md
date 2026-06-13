# QM5_10602_mql5-oshma - Strategy Spec

**EA ID:** QM5_10602
**Slug:** mql5-oshma
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades a closed-bar OsHMA histogram zero-cross. The histogram is implemented as fast HMA minus slow HMA using the source defaults FastHMA=13 and SlowHMA=26. It enters long when the completed-bar histogram crosses from non-positive to positive, and enters short when it crosses from non-negative to negative. It exits on the opposite zero-cross or after 16 completed H4 bars, with a catastrophic stop set at 2.5 times ATR(14).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_hma_period` | 13 | 4-200 | Fast HMA period used in the OsHMA histogram. |
| `strategy_slow_hma_period` | 26 | 5-400 | Slow HMA period used in the OsHMA histogram; must be greater than the fast period. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for the catastrophic stop. |
| `strategy_atr_sl_mult` | 2.5 | 0.1-10.0 | ATR multiple used to place the initial stop. |
| `strategy_time_stop_bars` | 16 | 1-200 | Maximum completed bars to hold before strategy exit. |

---

## 3. Symbol Universe

**Designed for:**
- `NZDUSD.DWX` - source test used NZDUSD H4 and the symbol is available in the DWX matrix.
- `EURUSD.DWX` - liquid DWX FX major suitable for portable oscillator momentum logic.
- `GBPUSD.DWX` - liquid DWX FX major suitable for portable oscillator momentum logic.
- `XAUUSD.DWX` - liquid DWX metal CFD listed by the approved card as a portable target.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - broker/custom-symbol data availability is not verified for them.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Up to 16 H4 bars unless an opposite zero-cross occurs first |
| Expected drawdown profile | Momentum-reversal oscillator with catastrophic ATR stop; drawdown expected during choppy zero-cross clusters |
| Regime preference | momentum-reversal |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/1335 and `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10602_mql5-oshma.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10602_mql5-oshma.md`

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
| v1 | 2026-06-13 | Initial build from card | a560c4bc-d30d-4df3-a469-241c9bddcf04 |
