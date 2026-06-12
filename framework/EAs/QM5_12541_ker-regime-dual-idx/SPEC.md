# QM5_12541_ker-regime-dual-idx - Strategy Spec

**EA ID:** QM5_12541
**Slug:** ker-regime-dual-idx
**Source:** kaufman-ker-regime-2026-06-12 (see `sources/kaufman-trading-systems-and-methods`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

This EA calculates Kaufman's Efficiency Ratio over 20 closed D1 bars and uses it as a regime switch. When KER is at or above 0.35 the EA trades a trend subsystem: buy on a D1 close above the prior Donchian(20) upper channel, or sell on a close below the prior Donchian(20) lower channel. When KER is at or below 0.20 the EA trades a mean-reversion subsystem: buy when RSI(2) closes below 10. Between the two KER thresholds the prior regime persists; trend trades exit on the opposite Donchian(10) break, while mean-reversion trades exit on a close above the prior day's high or after five days.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_D1` | D1 expected | Closed-bar signal timeframe from the card. |
| `strategy_ker_period` | `20` | 1+ | Bars used for Kaufman's Efficiency Ratio. |
| `strategy_ker_trend_level` | `0.35` | 0-1 | KER threshold that switches the EA into trend mode. |
| `strategy_ker_mr_level` | `0.20` | 0-1 | KER threshold that switches the EA into mean-reversion mode. |
| `strategy_trend_entry_dc` | `20` | 1+ | Prior-bar Donchian channel length for trend entries. |
| `strategy_trend_exit_dc` | `10` | 1+ | Prior-bar Donchian channel length for trend exits. |
| `strategy_rsi_period` | `2` | 1+ | RSI period for the mean-reversion entry. |
| `strategy_rsi_mr_level` | `10.0` | 0-100 | RSI level below which mean-reversion buys are allowed. |
| `strategy_atr_period` | `14` | 1+ | ATR period for initial stop placement. |
| `strategy_trend_atr_mult` | `2.0` | 0+ | Initial ATR stop multiple for trend trades. |
| `strategy_mr_atr_mult` | `3.0` | 0+ | Initial ATR disaster-stop multiple for mean-reversion trades. |
| `strategy_mr_time_exit_days` | `5` | 1+ | Maximum calendar-day hold for mean-reversion trades. |
| `strategy_max_spread_points` | `0.0` | 0+ | Optional spread cap; zero disables the extra strategy cap. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Card R3 PASS target index with liquid D1 history.
- `WS30.DWX` - Card R3 PASS target index with liquid D1 history.
- `XAUUSD.DWX` - Card R3 PASS target gold symbol with D1 history.

**Explicitly NOT for:**
- Symbols outside `dwx_symbol_matrix.csv` - not available to the DWX backtest terminals.
- Non-D1 setfile periods - the card specifies D1 closed-bar signals only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` with D1 setfiles |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `40` |
| Typical hold time | Mean-reversion exits within five days; trend trades hold until the opposite Donchian(10) break or framework Friday close |
| Expected drawdown profile | About `12%` expected max drawdown from card frontmatter |
| Regime preference | Hybrid trend-following and mean-reversion selected by KER hysteresis |
| Win rate target (qualitative) | Medium; MR frequency offsets lower-frequency trend tails |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `kaufman-ker-regime-2026-06-12`
**Source type:** book / public codebase / research article
**Pointer:** `artifacts/cards_approved/QM5_12541_ker-regime-dual-idx.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12541_ker-regime-dual-idx.md`

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
| v1 | 2026-06-12 | Initial build from card | 61f2d7ba-418b-47df-9dc7-0212d7f847a6 |
