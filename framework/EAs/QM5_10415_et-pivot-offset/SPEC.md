# QM5_10415_et-pivot-offset - Strategy Spec

**EA ID:** QM5_10415
**Slug:** `et-pivot-offset`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

On each completed M15 bar, the EA computes typical price as `(Close + Low + High) / 3` and an offset as the EMA of recent high-low ranges. It places a next-bar buy limit below typical price and a sell limit above typical price, each scaled by the multiplier. Unfilled limits expire after one bar; once either side fills, the opposite pending order is cancelled. Open trades are closed after the fill bar completes, with an emergency stop at `1.25 * Offset` from entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_length` | 3 | 1-50 | EMA length for completed-bar high-low range offset. |
| `strategy_multiplier` | 0.5 | 0.1-5.0 | Multiplier applied to the offset around typical price. |
| `strategy_emergency_stop_mult` | 1.25 | 0.1-10.0 | Emergency stop distance as a multiple of the offset. |
| `strategy_place_long_limit` | true | true/false | Enables the lower buy-limit side of the bracket. |
| `strategy_place_short_limit` | true | true/false | Enables the upper sell-limit side of the bracket. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair with M15 OHLC data suitable for range-offset mean reversion.
- `GBPUSD.DWX` - liquid major FX pair with M15 OHLC data suitable for range-offset mean reversion.
- `XAUUSD.DWX` - liquid metal CFD with intraday range behavior and DWX M15 data.
- `SP500.DWX` - S&P 500 custom symbol available for backtest-only index exposure.
- `NDX.DWX` - Nasdaq 100 index CFD with intraday range behavior and DWX data.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no approved DWX tick source for P2.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `150` |
| Typical hold time | One M15 bar after fill |
| Expected drawdown profile | Intraday mean-reversion drawdowns bounded by offset-based emergency stops. |
| Regime preference | Mean-revert |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `https://www.elitetrader.com/et/threads/example-that-works.26440/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10415_et-pivot-offset.md`

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
| v1 | 2026-05-25 | Initial build from card | 435cba46-a20b-4da2-9ee8-6117a0150a7d |
