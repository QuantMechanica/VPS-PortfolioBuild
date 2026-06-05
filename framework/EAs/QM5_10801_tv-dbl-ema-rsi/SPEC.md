# QM5_10801_tv-dbl-ema-rsi - Strategy Spec

**EA ID:** QM5_10801
**Slug:** `tv-dbl-ema-rsi`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `sources/tradingview-mechanical-strategy-scripts`)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA trades the TradingView Double EMA RSI breakout mechanically on the chart timeframe. A long entry is opened after a confirmed closed bar when the close is above EMA(20) of high prices and RSI(20) is above 50. The baseline is long-only; the optional symmetric short ablation is exposed as an input and defaults off. Open positions exit through the ATR bracket or by signal exit when the closed bar moves back through the opposite EMA channel boundary or RSI crosses back through 50.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 20 | 10-34 test range from card | EMA high/low channel period. |
| `strategy_rsi_period` | 20 | 14-20 test range from card | RSI period used for momentum confirmation and signal exit. |
| `strategy_rsi_threshold` | 50.0 | 50-55 test range from card | RSI midpoint threshold for entry and signal exit. |
| `strategy_atr_period` | 14 | fixed by card | ATR period used for stop and target distance. |
| `strategy_atr_stop_mult` | 1.5 | 1.0-2.0 test range from card | Stop distance in ATR multiples. |
| `strategy_atr_target_mult` | 3.0 | 2.0-4.0 test range from card | Take-profit distance in ATR multiples. |
| `strategy_enable_shorts` | false | false or true | Enables the card's optional symmetric short ablation. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card R3 forex basket and DWX matrix entry.
- `GBPUSD.DWX` - card R3 forex basket and DWX matrix entry.
- `USDJPY.DWX` - card R3 forex basket and DWX matrix entry.
- `XAUUSD.DWX` - card R3 metal basket item normalized to DWX suffix present in matrix.
- `GDAXI.DWX` - DAX custom symbol present in matrix; used for the card's `GER40.DWX` DAX leg.
- `NDX.DWX` - card R3 US index basket and DWX matrix entry.
- `WS30.DWX` - card R3 US index basket and DWX matrix entry.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; DAX exposure is registered as `GDAXI.DWX`.
- `SP500.DWX` - mentioned only as a later possible test path, not part of this card's primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` for generated Q01/P2 setfiles because the card does not specify a primary timeframe |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | Not specified in card; ATR bracket and signal exit imply hours to days depending on timeframe |
| Expected drawdown profile | Trend-dependent with whipsaw risk in low-volatility ranges |
| Regime preference | Trend-following EMA channel breakout with RSI momentum confirmation |
| Win rate target (qualitative) | Not specified in card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** TradingView script `The Blessed Trader Ph. | Double EMA + RSI (20) Strategy v1.0`, author `TheBlessedTraderPh`, https://www.tradingview.com/script/qfI90ACQ-The-Blessed-Trader-Ph-Double-EMA-RSI-20-Strategy-v1-0/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10801_tv-dbl-ema-rsi.md`

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
| v1 | 2026-06-05 | Initial build from card | 07a0c91f-6406-413c-ac32-664c6dc6e5f5 |
