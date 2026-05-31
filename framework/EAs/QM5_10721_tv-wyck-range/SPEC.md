# QM5_10721_tv-wyck-range - Strategy Spec

**EA ID:** QM5_10721
**Slug:** `tv-wyck-range`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (TradingView script `Wyckoff Range Strategy`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

This EA trades the TradingView Wyckoff Range Strategy as a closed-bar SMA cross system. A long entry occurs when the last closed bar's close crosses above `SMA(close, crossOverLength)` and the same bar's low crosses above `SMA(low, 20)`. A short entry occurs when close crosses below `SMA(close, crossOverLength)` and high crosses below `SMA(high, 20)`. Long exits trigger on a close cross below the close SMA or high cross below the high SMA; short exits trigger on a close cross above the close SMA or low cross above the low SMA.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_cross_over_length` | 20 | 2-200 | SMA period for close cross entry and exit signals. |
| `strategy_range_ma_length` | 20 | 2-200 | SMA period for low/high range cross confirmation. |
| `strategy_atr_period` | 14 | 2-100 | ATR period used only to reject stops outside card bounds. |
| `strategy_stop_pct_index` | 1.0 | 0.1-10.0 | Stop distance as percent of close for indices and metals. |
| `strategy_stop_pct_fx` | 0.5 | 0.1-10.0 | Stop distance as percent of close for FX symbols. |
| `strategy_min_stop_atr` | 0.50 | 0.1-5.0 | Minimum stop distance in ATR multiples. |
| `strategy_max_stop_atr` | 4.00 | 0.5-20.0 | Maximum stop distance in ATR multiples. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX major with DWX OHLC/SMA coverage.
- `GBPUSD.DWX` - card-listed FX major with DWX OHLC/SMA coverage.
- `XAUUSD.DWX` - card-listed metal; uses index/metal stop baseline.
- `GDAXI.DWX` - canonical DWX DAX symbol used for the card's `GER40.DWX` target.
- `NDX.DWX` - card-listed large-cap index CFD.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; DAX exposure is registered as `GDAXI.DWX`.
- Symbols outside `dwx_symbol_matrix.csv` - no validated DWX test data.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | Until opposite SMA range cross or stop; exact hold time not specified in card frontmatter. |
| Expected drawdown profile | Fixed-risk trend/range-breakout losses bounded by percentage stop and ATR sanity bounds. |
| Regime preference | Accumulation breakout and distribution breakdown transitions. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy script
**Pointer:** https://www.tradingview.com/script/vQSBf9rh-Wyckoff-Range-Strategy/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10721_tv-wyck-range.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-31 | Initial build from card | 86ee22cf-0114-4081-9e81-6add08c761a2 |
