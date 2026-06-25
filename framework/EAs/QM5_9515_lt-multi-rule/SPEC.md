# QM5_9515_lt-multi-rule - Strategy Spec

**EA ID:** QM5_9515
**Slug:** lt-multi-rule
**Source:** 1a059d6d-84fa-5d0c-94c5-86dd0481637c (see `strategy-seeds/sources/1a059d6d-84fa-5d0c-94c5-86dd0481637c/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

This EA combines two deterministic daily forecast blocks from Robert Carver's Leveraged Trading: a multi-speed SMA momentum stack and a multi-horizon rolling close breakout stack. Each valid block is capped to [-20,+20], the valid block forecasts are averaged, and the EA opens long when the combined forecast is above +2 or short when it is below -2. The optional carry block is skipped when deterministic carry input is unavailable, which leaves momentum and breakout as the two required valid blocks. Positions close when the combined forecast crosses back through zero, with an emergency stop at 2.5 x ATR(20, D1).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_risk_atr_period | 25 | 2-200 | ATR period used as instrument risk units for the SMA momentum block. |
| strategy_sl_atr_period | 20 | 2-200 | ATR period for the emergency hard stop. |
| strategy_sl_atr_mult | 2.5 | 0.1-10.0 | Multiplier for the ATR hard stop. |
| strategy_entry_threshold | 2.0 | 0.0-20.0 | Absolute combined forecast threshold for long or short entry. |
| strategy_min_valid_blocks | 2 | 1-3 | Minimum valid forecast blocks required before entry or signal exit. |
| strategy_min_momentum_pairs | 3 | 1-6 | Minimum valid SMA speed forecasts required for the momentum block. |
| strategy_min_breakout_horizons | 3 | 1-6 | Minimum valid rolling-range horizons required for the breakout block. |
| strategy_spread_lookback | 20 | 5-20 | Daily observations held for the median spread cap. |
| strategy_spread_cap_mult | 2.0 | 0.1-10.0 | Blocks new entries when non-zero spread exceeds this multiple of median spread. |
| strategy_mom_scalar_2_8 | 180.8 | fixed source scalar | SMA 2/8 momentum forecast scalar. |
| strategy_mom_scalar_4_16 | 124.32 | fixed source scalar | SMA 4/16 momentum forecast scalar. |
| strategy_mom_scalar_8_32 | 83.84 | fixed source scalar | SMA 8/32 momentum forecast scalar. |
| strategy_mom_scalar_16_64 | 57.12 | fixed source scalar | SMA 16/64 momentum forecast scalar. |
| strategy_mom_scalar_32_128 | 38.24 | fixed source scalar | SMA 32/128 momentum forecast scalar. |
| strategy_mom_scalar_64_256 | 25.28 | fixed source scalar | SMA 64/256 momentum forecast scalar. |
| strategy_breakout_scalar_10 | 28.6 | fixed source scalar | 10-day rolling breakout forecast scalar. |
| strategy_breakout_scalar_20 | 31.6 | fixed source scalar | 20-day rolling breakout forecast scalar. |
| strategy_breakout_scalar_40 | 32.7 | fixed source scalar | 40-day rolling breakout forecast scalar. |
| strategy_breakout_scalar_80 | 33.5 | fixed source scalar | 80-day rolling breakout forecast scalar. |
| strategy_breakout_scalar_160 | 33.5 | fixed source scalar | 160-day rolling breakout forecast scalar. |
| strategy_breakout_scalar_320 | 33.5 | fixed source scalar | 320-day rolling breakout forecast scalar. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed liquid FX major with daily OHLC support.
- GBPUSD.DWX - Card-listed liquid FX major with daily OHLC support.
- USDJPY.DWX - Card-listed liquid FX major with daily OHLC support.
- AUDUSD.DWX - Card-listed liquid FX major with daily OHLC support.
- NZDUSD.DWX - Card-listed liquid FX major with daily OHLC support.
- NDX.DWX - Card-listed liquid US equity index CFD.
- WS30.DWX - Card-listed liquid US equity index CFD.
- XAUUSD.DWX - Card-listed liquid gold CFD with daily OHLC support.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available for DWX backtesting.
- Carry-only markets without daily OHLC history - this EA needs at least the momentum and breakout blocks.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` for flat entries; `QM_IsNewBar(_Symbol, PERIOD_D1)` for open-position rebalance state |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 |
| Typical hold time | days to weeks |
| Expected drawdown profile | Trend-following style drawdowns during sideways or choppy regimes. |
| Regime preference | trend / breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1a059d6d-84fa-5d0c-94c5-86dd0481637c
**Source type:** book
**Pointer:** Robert Carver, Leveraged Trading, Harriman House, 2019; publisher and official resource links in the approved card.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_9515_lt-multi-rule.md`

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
| v1 | 2026-06-25 | Initial build from card | e7ecd838-3d17-455f-a4e5-6b0d336e1fec |
