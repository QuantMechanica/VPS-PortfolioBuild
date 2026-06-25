# QM5_9239_mql5-dma-angle-band - Strategy Spec

**EA ID:** QM5_9239
**Slug:** `mql5-dma-angle-band`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

This EA calculates a decaying moving average over closed H1 bars, then converts the change over the configured lookback into an angle using the prior lookback range as the horizontal scale. It opens long when the angle is between 12 and 30 degrees and the closed price is above the decaying average. It opens short when the angle is between -12 and -30 degrees and the closed price is below the decaying average. It exits when the angle crosses through zero, becomes steeper than 35 degrees in the position direction, or the position has been held for 36 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_dma_period` | 34 | `2+` | Number of closed bars in the decaying moving average sample. |
| `strategy_angle_lookback` | 8 | `2+` | Bars between the current DMA value and the prior DMA value used for angle measurement. |
| `strategy_entry_angle_min` | 12.0 | `0+` | Minimum absolute DMA angle required for entry. |
| `strategy_entry_angle_max` | 30.0 | `> min` | Maximum absolute DMA angle allowed for entry. |
| `strategy_exit_steep_angle` | 35.0 | `> entry max` | Absolute angle beyond which an open trend trade exits as too steep. |
| `strategy_atr_period` | 14 | `1+` | ATR period for initial stop placement. |
| `strategy_atr_sl_mult` | 1.9 | `> 0` | ATR multiple for initial stop distance. |
| `strategy_take_rr` | 2.1 | `> 0` | Initial take-profit in R multiples. |
| `strategy_max_hold_bars` | 36 | `1+` | Failsafe maximum holding period in H1 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target; liquid major FX pair available in the DWX matrix.
- `GBPJPY.DWX` - card target; volatile FX cross available in the DWX matrix.
- `XAUUSD.DWX` - card target; liquid gold CFD available in the DWX matrix.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no DWX backtest data is available.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | Up to `36` H1 bars by failsafe time exit |
| Expected drawdown profile | ATR-defined single-position trend trades with fixed 2.1R target |
| Regime preference | Trend-following / slope-filter regimes |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** `MQL5 article`
**Pointer:** `https://www.mql5.com/en/articles/15241`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9239_mql5-dma-angle-band.md`

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
| v1 | 2026-06-26 | Initial build from card | d10bab6c-6e82-4a00-9cac-8abdb476608c |
