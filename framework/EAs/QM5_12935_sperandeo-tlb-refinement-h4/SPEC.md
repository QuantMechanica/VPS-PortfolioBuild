# QM5_12935_sperandeo-tlb-refinement-h4 - Strategy Spec

**EA ID:** QM5_12935
**Slug:** sperandeo-tlb-refinement-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

The EA trades H4 Three-Line-Break flips only when the flip is confirmed by a prior 2B pivot and agrees with the D1 trend filter. A long entry requires the latest H4 close to break above the prior three-line range, a prior local swing low followed by a lower false break, and D1 close above SMA(200). A short entry mirrors the rule with a down flip, prior swing high false break, and D1 close below SMA(200). Stops are anchored at the 2B pivot and capped to 3 ATR(14); exits occur on the opposite TLB flip, a 40-H4-bar time stop, or the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_tlb_lines` | 3 | 2-4 | Number of prior TLB lines used for flip detection. |
| `strategy_2b_lookback` | 50 | 30-120 | H4 bars searched for the confirming 2B pivot. |
| `strategy_regime_sma_period` | 200 | 100-300 | D1 SMA period for the trend regime gate. |
| `strategy_atr_period` | 14 | 5-50 | ATR period used for stop cap, spread cap, and break-even trigger. |
| `strategy_stop_atr_cap_mult` | 3.0 | 1.0-6.0 | Maximum stop distance in ATR multiples. |
| `strategy_be_trigger_atr_mult` | 1.5 | 0.5-4.0 | Profit threshold before SL moves to break-even plus spread. |
| `strategy_be_buffer_pips` | 1 | 0-10 | Fallback break-even buffer when modeled spread is zero. |
| `strategy_spread_atr_mult` | 0.5 | 0.1-2.0 | Entry is blocked only when positive spread exceeds this ATR fraction. |
| `strategy_time_stop_bars` | 40 | 10-120 | Maximum hold time in H4 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - US index CFD exposure listed in the card's portable R3 basket.
- `WS30.DWX` - US index CFD exposure listed in the card's portable R3 basket.
- `GDAXI.DWX` - European index CFD exposure listed in the card's portable R3 basket.
- `UK100.DWX` - European index CFD exposure listed in the card's portable R3 basket.
- `SP500.DWX` - S&P 500 custom symbol, valid for backtest-only registration per DWX discipline.
- `XAUUSD.DWX` - Gold CFD exposure listed in the card's portable R3 basket.
- `XTIUSD.DWX` - Oil CFD exposure listed in the card's portable R3 basket.
- `EURUSD.DWX` - FX major listed in the card's portable R3 basket.
- `GBPUSD.DWX` - FX major listed in the card's portable R3 basket.
- `USDJPY.DWX` - FX major listed in the card's portable R3 basket.

**Explicitly NOT for:**
- `FCHI.DWX` - named in the card but absent from `framework/registry/dwx_symbol_matrix.csv`; EU index exposure is represented by `GDAXI.DWX` and `UK100.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 close and D1 SMA(200) regime filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Up to 40 H4 bars; the card does not provide a separate median hold estimate. |
| Expected drawdown profile | Structural pivot stop capped to 3 ATR(14), with break-even at +1.5 ATR. |
| Regime preference | Trend-with-pivot-confirmation swing continuation. |
| Win rate target (qualitative) | Medium; the card specifies fewer but more precise TLB flips. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** book/forum
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_12935_sperandeo-tlb-refinement-h4.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12935_sperandeo-tlb-refinement-h4.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3%-0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-07 | Initial build from card | 0b61ac01-b516-4ca1-8970-ab8627ac5d41 |
