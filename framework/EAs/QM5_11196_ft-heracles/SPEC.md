# QM5_11196_ft-heracles - Strategy Spec

**EA ID:** QM5_11196
**Slug:** `ft-heracles`
**Source:** `1580128f-e465-5454-bb97-a7572a6cfd6d` (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades long on H4 closed bars when a shifted Donchian channel percent-band divided by a shifted Keltner channel width is between 0.16 and 0.75. The Donchian percent-band uses a 10-bar high/low window shifted 15 bars back, and the Keltner width uses a 20-bar typical-price middle with ATR(10), shifted 9 bars back. The card does not state a Keltner multiplier, so the implementation uses the standard 2x ATR channel width. Entries use an ATR(14) stop at 2.5x ATR, with no fixed take-profit. Positions close through the source ROI ladder: 59.8% immediately, 16.6% after 644 minutes, 11.5% after 3269 minutes, and breakeven-or-better after 7289 minutes, plus framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_H4` | H4 baseline | Base timeframe for channel and ATR reads |
| `strategy_buy_div_min` | `0.16` | 0.10-0.25 | Lower bound for Donchian/Keltner ratio |
| `strategy_buy_div_max` | `0.75` | 0.50-0.90 | Upper bound for Donchian/Keltner ratio |
| `strategy_donchian_window` | `10` | fixed | Donchian percent-band rolling window |
| `strategy_keltner_window` | `20` | fixed | Keltner original-version rolling window |
| `strategy_keltner_atr_period` | `10` | fixed | ATR period for Keltner channel width |
| `strategy_donchian_shift` | `15` | 9-20 | Closed-bar shift for Donchian percent-band |
| `strategy_keltner_shift` | `9` | 5-15 | Closed-bar shift for Keltner width |
| `strategy_min_warmup_bars` | `40` | >=40 | Minimum bars before evaluating the ratio |
| `strategy_atr_stop_period` | `14` | fixed | ATR period for protective stop |
| `strategy_atr_stop_mult` | `2.5` | 2.0-3.0 | ATR stop multiplier |
| `strategy_max_spread_stop_frac` | `0.08` | fixed | Maximum spread as fraction of planned stop distance |
| `strategy_roi_0_min` | `0.598` | fixed | ROI target before 644 minutes |
| `strategy_roi_1_after_min` | `644` | fixed | First ROI ladder threshold in minutes |
| `strategy_roi_1_min` | `0.166` | fixed | ROI target after first threshold |
| `strategy_roi_2_after_min` | `3269` | fixed | Second ROI ladder threshold in minutes |
| `strategy_roi_2_min` | `0.115` | fixed | ROI target after second threshold |
| `strategy_roi_3_after_min` | `7289` | fixed | Final ROI ladder threshold in minutes |
| `strategy_roi_3_min` | `0.0` | fixed | ROI target after final threshold |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major with deep DWX history and channel/volatility portability.
- `GBPUSD.DWX` - FX major with deep DWX history and channel/volatility portability.
- `XAUUSD.DWX` - liquid metal symbol suited to volatility compression state tests.
- `GDAXI.DWX` - canonical DWX DAX symbol; used as the matrix-available port for card `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; registered as `GDAXI.DWX` instead.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no validated DWX data source.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Typical hold time | `4 days, 6:24:00` from source comments |
| Expected drawdown profile | Medium risk due 2.5x ATR stop and multi-day holds |
| Regime preference | Volatility-compression channel state |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** GitHub strategy source
**Pointer:** `https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/Heracles.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11196_ft-heracles.md`

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
| v1 | 2026-06-08 | Initial build from card | 6bfb1d40-3f80-413b-ab50-8ec83892ee0f |
