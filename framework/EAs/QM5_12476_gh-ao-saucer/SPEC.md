# QM5_12476_gh-ao-saucer - Strategy Spec

**EA ID:** QM5_12476
**Slug:** gh-ao-saucer
**Source:** af7930c8-6c65-52d1-9c01-040490b5ad39
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA computes Awesome Oscillator as SMA(5) of median price minus SMA(34) of median price on closed H1 bars. In trend mode it goes long when the fast median SMA is above the slow median SMA and short when it is below. In saucer mode it uses the source's AO saucer pattern: bullish below zero after two rising AO bars followed by a down AO bar, and bearish above zero after two falling AO bars followed by an up AO bar. The default combined mode lets saucer signals override same-bar trend direction, exits on the opposite trend or saucer signal, and uses a 2.0 ATR(14) protective stop from entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ao_fast_period | 5 | >= 1 | Fast SMA period applied to median price. |
| strategy_ao_slow_period | 34 | > fast period | Slow SMA period applied to median price. |
| strategy_signal_mode | 2 | 0-2 | 0 trend-only, 1 saucer-only, 2 combined. |
| strategy_atr_period | 14 | >= 1 | ATR period for the protective stop. |
| strategy_atr_sl_mult | 2.0 | > 0 | ATR multiple used for the protective stop. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - R3 portable FX major using OHLC median-price rules.
- GBPUSD.DWX - R3 portable FX major using OHLC median-price rules.
- XAUUSD.DWX - R3 portable metal market using OHLC median-price rules.
- NDX.DWX - R3 portable liquid index using OHLC median-price rules.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - no broker/test data source.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | hours to days |
| Expected drawdown profile | Momentum reversals with ATR-defined per-trade downside. |
| Regime preference | momentum |
| Win rate target (qualitative) | medium |

Expected trade frequency: AO zero-line/crossover plus saucer signals are conditional but recurring; conservative estimate 25-70 trades/year/symbol.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** af7930c8-6c65-52d1-9c01-040490b5ad39
**Source type:** GitHub script
**Pointer:** https://github.com/je-suis-tm/quant-trading/blob/master/Awesome%20Oscillator%20backtest.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12476_gh-ao-saucer.md`

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
| v1 | 2026-06-11 | Initial build from card | b6a12b97-89d9-454d-a438-dfb641e2aa75 |
