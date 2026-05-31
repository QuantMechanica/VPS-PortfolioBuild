# QM5_10507_mql5-ao-lightning - Strategy Spec

**EA ID:** QM5_10507
**Slug:** `mql5-ao-lightning`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see approved card citation)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA computes Awesome Oscillator as SMA(5, median price) minus SMA(34, median price) on completed H1 bars. It buys when the latest completed AO column moves down and turns red after a non-red prior column, matching the source's two-column buy condition. It sells when the latest completed AO column moves up and turns green after a non-green prior column. Open positions close when the opposite AO Lightning signal appears, while the framework enforces one active position per symbol and magic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_work_tf` | `PERIOD_H1` | H1 baseline | Timeframe used for AO and ATR reads |
| `strategy_ao_fast_period` | `5` | `1+` and less than slow | Fast SMA period for AO median-price leg |
| `strategy_ao_slow_period` | `34` | greater than fast | Slow SMA period for AO median-price leg |
| `strategy_atr_period` | `14` | `1+` | ATR period for the hard stop distance |
| `strategy_atr_sl_mult` | `1.5` | `>0` | Stop loss multiplier applied to ATR(14) |
| `strategy_target_rr` | `1.5` | `>0` | Take-profit reward/risk multiple |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major FX pair in the card's portable P2 AO basket.
- `GBPUSD.DWX` - major FX pair in the card's portable P2 AO basket.
- `USDJPY.DWX` - major FX pair in the card's portable P2 AO basket.
- `XAUUSD.DWX` - liquid metal symbol in the card's portable P2 AO basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not eligible for DWX backtest registration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `170` |
| Typical hold time | H1 opposite-signal exit or ATR/TP hard exit |
| Expected drawdown profile | ATR-normalized bounded loss per trade |
| Regime preference | AO momentum histogram reversal |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** Evgeniy Kravchenko, "AO Lightning", MQL5 CodeBase, published 2018-06-16, https://www.mql5.com/en/code/20672
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10507_mql5-ao-lightning.md`

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
| v1 | 2026-05-28 | Initial build from card | bc300de6-56d9-4d9f-aab2-b7d47a9e7ad6 |
