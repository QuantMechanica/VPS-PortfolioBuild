# QM5_10744_tv-ict-ote — Strategy Spec

**EA ID:** QM5_10744
**Slug:** tv-ict-ote
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see approved Strategy Card)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA confirms swing highs and lows using the card's left/right pivot strength. After a completed bullish leg from pivot low to pivot high, it places a buy limit at the 0.705 retracement, with take profit at the pivot high and stop below the pivot low by 0.1 ATR(14). After a completed bearish leg from pivot high to pivot low, it places a sell limit at the 0.705 retracement, with take profit at the pivot low and stop above the pivot high by 0.1 ATR(14). Pending orders are removed if price invalidates the leg before entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_left_strength` | 5 | >=1 | Number of older bars required to confirm a swing pivot. |
| `strategy_right_strength` | 5 | >=1 | Number of newer closed bars required to confirm a swing pivot. |
| `strategy_pivot_scan_bars` | 240 | >= left + right + 2 | Closed-bar window scanned for the latest completed pivot leg. |
| `strategy_ote_level` | 0.705 | 0.0-1.0 | Fibonacci retracement level used for the OTE limit entry. |
| `strategy_atr_period` | 14 | >=1 | ATR period for the stop buffer. |
| `strategy_sl_atr_buffer_mult` | 0.10 | >=0.0 | ATR multiplier added beyond the source swing for the stop loss. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` — Card R3 includes gold; OHLC swing and Fibonacci retracement logic is directly portable.
- `EURUSD.DWX` — Card R3 includes EURUSD; liquid FX pair suitable for M15 pivot/retracement mechanics.
- `GBPUSD.DWX` — Card R3 includes GBPUSD; liquid FX pair suitable for M15 pivot/retracement mechanics.
- `NDX.DWX` — Card R3 includes NDX; index CFD suitable for the same OHLC pivot/retracement mechanics.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` — no DWX tick data is registered for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | Not specified in card frontmatter; implied swing-leg M15 retracement hold. |
| Expected drawdown profile | Not specified in card frontmatter. |
| Regime preference | Swing-leg Fibonacci retracement after confirmed pivots. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView protected-source strategy
**Pointer:** TradingView script `ICT OTE Strategy`, author handle `DropkingICT`, published 2025-07-31, https://www.tradingview.com/script/f1NI6nhP-ICT-OTE-Strategy/
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10744_tv-ict-ote.md`

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
| v1 | 2026-06-14 | Initial build from card | 6a1ed707-ed28-4479-9fc9-e5ddf7e13698 |
