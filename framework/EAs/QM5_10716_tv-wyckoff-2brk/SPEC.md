# QM5_10716_tv-wyckoff-2brk - Strategy Spec

**EA ID:** QM5_10716
**Slug:** tv-wyckoff-2brk
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (TradingView script `MGC Wyckoff Second Breakout V3 Candle RR`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades M15 second breakouts after a confirmed pivot. A long setup starts when a closed bar first breaks above the latest confirmed pivot high; the EA then tracks the highest high after that first break, waits for a pullback close below it, and enters long if price closes back above that tracked high within 20 bars. Shorts mirror the same state machine below a confirmed pivot low. Exits are fixed SL and TP only: the stop is built from the structure extreme between first and second breakout plus a 0.2 ATR buffer, and the target is 1R, 2R, or 3R from deterministic liquidity and expansion rules.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_left_bars | 4 | 1+ | Bars to the left of a candidate pivot. |
| strategy_right_bars | 2 | 1+ | Bars to the right required to confirm a pivot. |
| strategy_max_bars_after_breakout | 20 | 1+ | Maximum bars allowed between first and second breakout. |
| strategy_atr_period | 14 | 2+ | ATR period used for stop buffer and stop-distance validation. |
| strategy_stop_atr_buffer | 0.20 | 0.0+ | ATR multiple added beyond the structure stop. |
| strategy_min_stop_atr | 0.50 | 0.0+ | Minimum stop distance in ATR units. |
| strategy_max_stop_atr | 4.00 | 0.0+ | Maximum stop distance in ATR units. |
| strategy_body_short_period | 10 | 1+ | Short body average period for low-liquidity detection. |
| strategy_body_long_period | 50 | 1+ | Long body average period for liquidity and expansion detection. |
| strategy_range_long_period | 100 | 1+ | Long range average period for low-liquidity detection. |
| strategy_low_liquidity_ratio | 0.75 | 0.0-1.0 | Low-liquidity threshold applied to short body and range averages. |
| strategy_expansion_body_mult | 1.50 | 0.0+ | Breakout candle body multiple for the 3R trend-expansion target. |
| strategy_expansion_range_atr_mult | 1.00 | 0.0+ | Breakout candle range versus ATR for the 3R target. |
| strategy_expansion_close_pct | 0.30 | 0.0-1.0 | Required close location in the top or bottom candle fraction for expansion. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- XAUUSD.DWX - Direct gold/metal port from the source's MGC/gold context.
- GDAXI.DWX - Canonical DWX DAX symbol used as the available port for the card's GER40.DWX target.
- NDX.DWX - Liquid index CFD target named by the card.
- EURUSD.DWX - Major FX pair named by the card.
- GBPUSD.DWX - Major FX pair named by the card.

**Explicitly NOT for:**
- GER40.DWX - Not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is the registered canonical DAX equivalent.
- Symbols outside `dwx_symbol_matrix.csv` - The build registry is restricted to verified DWX symbols only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 90 |
| Typical hold time | Intraday to multi-session; positions exit by fixed SL/TP or Friday close. |
| Expected drawdown profile | Breakout structure stops should create clustered losses during failed-breakout ranges. |
| Regime preference | Breakout and volatility expansion after a pullback/pause. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy script
**Pointer:** TradingView script `MGC Wyckoff Second Breakout V3 Candle RR`, author handle `zhangwenjian810`, page shows May 13
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10716_tv-wyckoff-2brk.md`

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
| v1 | 2026-05-31 | Initial build from card | 9be6847e-3bfd-4fa6-acb8-7b349e7ad27d |
