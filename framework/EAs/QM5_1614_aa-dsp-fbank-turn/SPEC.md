# QM5_1614_aa-dsp-fbank-turn - Strategy Spec

**EA ID:** QM5_1614
**Slug:** `aa-dsp-fbank-turn`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7` (see `strategy-seeds/sources/ede348b4-0fa7-5be1-baa8-09e9089b67b7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA evaluates completed D1 closes through the six fixed second-order IIR bandpass filters described in the Alpha Architect filter-bank source, using center periods 15, 88, 513, 2990, 17427, and 101572 and synthesis gain 0.886. It opens long when the synthesized output forms a completed local trough below zero, and opens short when it forms a completed local crest above zero. Positions close on the opposite completed local turn or after 40 completed D1 bars, whichever comes first. Initial stop loss is 2.0 x ATR(20, D1).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 2-200 | D1 ATR period used for the initial stop. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-10.0 | Initial stop distance as a multiple of ATR. |
| `strategy_max_hold_bars` | 40 | 1-250 | Maximum completed D1 bars to hold a position. |
| `strategy_warmup_bars` | 300 | 300+ | Minimum completed D1 bars before signals are accepted. |
| `strategy_spread_lookback` | 20 | 2-100 | D1 bars used for the median spread gate. |
| `strategy_spread_mult` | 2.5 | 0.1-10.0 | Entry is skipped when current spread exceeds this multiple of median spread. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 index exposure listed in the registered portable basket.
- `SP500.DWX` - S&P 500 custom symbol exposure from the card; backtest-only per DWX discipline.
- `WS30.DWX` - Dow 30 index exposure listed in the registered portable basket.
- `GDAXI.DWX` - DAX index exposure listed in the registered portable basket.
- `XAUUSD.DWX` - Gold commodity exposure listed in the registered portable basket.
- `XTIUSD.DWX` - DWX oil CFD equivalent for the card's `USOIL.DWX` exposure.
- `EURUSD.DWX` - Major FX exposure listed in the registered portable basket.
- `GBPUSD.DWX` - Major FX exposure listed in the registered portable basket.
- `USDJPY.DWX` - Major FX exposure listed in the registered portable basket.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - no broker or custom-symbol test data is available.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` with one state advance per completed D1 bar |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Up to 40 D1 bars |
| Expected drawdown profile | Trend-turn system with ATR-defined per-trade loss and whipsaw risk around noisy reversals. |
| Regime preference | Trend-following and cycle-turn regimes |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Source type:** `blog`
**Pointer:** Henry Stern, "Trend-Following Filters - Part 3", Alpha Architect, 2021-04-08, https://alphaarchitect.com/trend-following-filters-part-3/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1614_aa-dsp-fbank-turn.md`

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
| v1 | 2026-06-18 | Initial build from card | 655e8f0a-b8eb-4b3f-8564-75191b3b5986 |
