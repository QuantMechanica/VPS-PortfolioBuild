# QM5_10841_tv-930-body - Strategy Spec

**EA ID:** QM5_10841
**Slug:** `tv-930-body`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA builds a five-minute New York opening range from the M1 bars between 09:30 and 09:35 New York time. After that range is complete, it enters long when a later closed candle closes above the range high, or short when a later closed candle closes below the range low. The stop is placed at the opposite side of the opening range, optionally buffered by ATR, and trades are skipped when the stop distance is below the card's minimum stop floor after spread. The default target is fixed at 2.0R, only one trade is allowed per New York day, and any open position is force-closed at 16:00 New York.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_range_start_hhmm_ny` | 930 | 0000-2359 | New York wall-clock start of the opening range. |
| `strategy_range_minutes` | 5 | 1-60 | Number of M1 bars used for the opening range. |
| `strategy_entry_cutoff_hhmm_ny` | 1030 | 0000-2359 | Last New York time at which a breakout entry may be evaluated. |
| `strategy_exit_cutoff_hhmm_ny` | 1600 | 0000-2359 | New York force-flat cutoff if SL/TP did not close the trade. |
| `strategy_rr_target` | 2.0 | 0.5-5.0 | Take-profit multiple of initial stop distance. |
| `strategy_min_stop_forex_pips` | 10 | 1-100 | Minimum stop floor for forex symbols. |
| `strategy_min_stop_nonfx_ticks` | 1500 | 1-10000 | Minimum stop floor for gold and index symbols, measured in trade ticks. |
| `strategy_atr_period` | 14 | 2-100 | ATR period used only when the optional stop buffer is enabled. |
| `strategy_stop_atr_buffer_mult` | 0.0 | 0.0-2.0 | Optional ATR buffer added beyond the range opposite side. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 index CFD from the card's primary P2 basket.
- `WS30.DWX` - Dow 30 index CFD from the card's primary P2 basket.
- `GDAXI.DWX` - available DWX DAX custom symbol used for the card's `GER40.DWX` DAX exposure.
- `XAUUSD.DWX` - gold CFD from the card's primary P2 basket.
- `EURUSD.DWX` - forex pair from the card's primary P2 basket.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; DAX exposure is registered as `GDAXI.DWX`.
- `SP500.DWX` - mentioned only as a later caveat in the card, not part of the primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` and `M5` |
| Multi-timeframe refs | M1 opening-range construction when running on M5 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | Intraday, minutes to the 16:00 New York cutoff |
| Expected drawdown profile | One-shot daily fixed-risk losses with opening-spread/slippage sensitivity |
| Regime preference | Breakout / volatility expansion from the New York open |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** TradingView script `Institucional Stretegy 930 NY`, author handle `MillonetaVe`, https://www.tradingview.com/script/fq3Es1YA-Institucional-Stretegy-930-NY/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10841_tv-930-body.md`

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
| v1 | 2026-06-06 | Initial build from card | 611b193c-c98f-4d74-9445-b86a38fe1aee |
