# QM5_11091_stoch-mtf-state - Strategy Spec

**EA ID:** QM5_11091
**Slug:** `stoch-mtf-state`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (see `strategy-seeds/sources/0693c604-4f96-56ef-be79-15efe9f48b86/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed H1 bars. It opens long when the enabled H1, H4, and D1 stochastic main lines are all at or below 20 and the H1 stochastic main line is above its signal line. It opens short when the enabled H1, H4, and D1 stochastic main lines are all at or above 80 and the H1 stochastic main line is below its signal line. Open positions close when all enabled stochastic states return to the 20-80 range, when H1 reaches the opposite extreme, or when the position has been open for 10 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_stoch_k` | 5 | >=1 | Stochastic K period. |
| `strategy_stoch_d` | 3 | >=1 | Stochastic D period. |
| `strategy_stoch_slowing` | 3 | >=1 | Stochastic slowing period. |
| `strategy_stoch_low` | 20.0 | 0-100 | Oversold threshold. |
| `strategy_stoch_high` | 80.0 | 0-100 | Overbought threshold. |
| `strategy_atr_period` | 14 | >=1 | ATR period used for stop distance. |
| `strategy_atr_sl_mult` | 1.8 | >0 | Stop loss distance as ATR multiple. |
| `strategy_max_hold_h1_bars` | 10 | >=1 | Catastrophic time stop in H1 bars. |
| `strategy_enable_h1` | true | true/false | Include H1 stochastic state in the MTF state set. |
| `strategy_enable_h4` | true | true/false | Include H4 stochastic state in the MTF state set. |
| `strategy_enable_d1` | true | true/false | Include D1 stochastic state in the MTF state set. |
| `strategy_max_spread_points` | 0 | >=0 | Optional spread cap in points; 0 disables the cap. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - R3 primary FX symbol with DWX OHLC data for stochastic calculation.
- `GBPUSD.DWX` - R3 primary FX symbol with DWX OHLC data for stochastic calculation.
- `USDJPY.DWX` - R3 primary FX symbol with DWX OHLC data for stochastic calculation.
- `XAUUSD.DWX` - R3 primary metals symbol with DWX OHLC data for stochastic calculation.

**Explicitly NOT for:**
- Symbols outside the card R3 basket - not registered for this Q01 build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `H1`, `H4`, `D1` stochastic main and H1 stochastic signal |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `24` |
| Typical hold time | Up to 10 H1 bars, derived from the card's catastrophic time stop. |
| Expected drawdown profile | ATR-stopped oscillator reversions; losses bounded by 1.8 ATR stop. |
| Regime preference | Oscillator reversion with multi-timeframe stochastic confluence. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** `GitHub / MQL5 indicator`
**Pointer:** `https://github.com/EarnForex/Stochastic-Multi-Timeframe`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11091_stoch-mtf-state.md`

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
| v1 | 2026-06-07 | Initial build from card | 01e390e3-8ca8-40f1-959e-da1a10fc77bf |
