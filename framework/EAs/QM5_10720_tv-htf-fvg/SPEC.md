# QM5_10720_tv-htf-fvg - Strategy Spec

**EA ID:** QM5_10720
**Slug:** `tv-htf-fvg`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see TradingView source citation in approved card)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA watches M5 or M15 bars for a sweep through prior Daily, Weekly, or Monthly highs and lows. A sweep through an unswept low creates a long bias; a sweep through an unswept high creates a short bias; a bar that sweeps both sides is treated as manipulation and no entry is placed. After a valid sweep, the EA looks for a three-candle fair value gap and places one limit order at the nearest valid gap edge, using the recent sweep-window extreme plus an ATR buffer as the stop. The take-profit is the nearest HTF liquidity level in the trade direction, falling back to 2R when no valid level is available.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 1+ | ATR period used for FVG minimum size and stop buffer. |
| `strategy_limit_timeout_bars` | 20 | 1+ | Bars before a pending limit order expires and the sweep setup is no longer actionable. |
| `strategy_sweep_stop_window` | 5 | 1+ | Recent bars used to anchor the sweep-window structural stop. |
| `strategy_stop_atr_buffer_mult` | 0.20 | 0+ | ATR buffer beyond the sweep-window extreme. |
| `strategy_stop_max_atr_mult` | 4.00 | 0+ | Maximum allowed stop distance as a multiple of ATR. |
| `strategy_min_fvg_atr_mult` | 0.10 | 0+ | Minimum FVG size as a multiple of ATR. |
| `strategy_min_fvg_points` | 2.00 | 0+ | Minimum FVG size in symbol points. |
| `strategy_tp_fallback_rr` | 2.00 | 0+ | Fallback reward-to-risk target when no HTF target is available. |
| `strategy_ny_session_start_hour` | 2 | 0-23 | Start hour for the New York local session gate. |
| `strategy_ny_session_end_hour` | 15 | 0-23 | End hour for the New York local session gate. |
| `strategy_max_spread_points` | 0.0 | 0+ | Optional max spread in points; 0 disables the extra spread cap. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed liquid FX target with full DWX coverage.
- `GBPUSD.DWX` - Card-listed liquid FX target with full DWX coverage.
- `XAUUSD.DWX` - Card-listed metals target with full DWX coverage.
- `GDAXI.DWX` - DWX matrix DAX custom symbol used for the card's GER40.DWX exposure.
- `NDX.DWX` - Card-listed liquid index target with full DWX coverage.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX proxy.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - Not canonical DWX S&P 500 symbols for this card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` and `M15` |
| Multi-timeframe refs | Prior `D1`, `W1`, and `MN1` highs/lows |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` |
| Typical hold time | Intraday to multi-bar; pending entries expire after 20 bars. |
| Expected drawdown profile | Fixed-risk structural-stop reversal profile; losses cluster when sweeps continue through the FVG stop. |
| Regime preference | Liquidity-sweep reversal after displacement/FVG. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView strategy script
**Pointer:** TradingView script `Liquidity Sweep & FVG Strategy`, author handle `mehmettopbas_`, invite-only strategy with visible rules, updated Feb 23 2026.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10720_tv-htf-fvg.md`

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
| v1 | 2026-05-31 | Initial build from card | 5793a811-719a-4ccf-b084-a426d5451a0c |
