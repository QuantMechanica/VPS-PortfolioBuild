# QM5_10248_tv-macd-sma200 - Strategy Spec

**EA ID:** QM5_10248
**Slug:** tv-macd-sma200
**Source:** 30591366-874b-5bee-b47c-da2fca20b728
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

This EA trades a MACD momentum signal filtered by the 200-period simple moving average on the signal timeframe. It enters long when the MACD histogram is positive, the MACD main line is positive, the main line is above the signal line, and the last closed price is above SMA(200). It enters short on the exact inverse condition and exits an open position when the opposite entry condition becomes true. The source does not define a per-trade stop, so the build uses the card's P1 default emergency stop of 2.0 ATR.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_signal_tf | PERIOD_H4 | MT5 timeframe enum | Timeframe used for MACD, SMA200, and ATR stop reads. |
| strategy_macd_fast | 12 | integer > 0 | Fast MACD moving average period. |
| strategy_macd_slow | 26 | integer > strategy_macd_fast | Slow MACD moving average period. |
| strategy_macd_signal | 9 | integer > 0 | MACD signal moving average period. |
| strategy_sma_period | 200 | integer > 0 | Close-price SMA trend filter period. |
| strategy_atr_period | 14 | integer > 0 | ATR period for the emergency stop. |
| strategy_atr_sl_mult | 2.0 | double > 0 | ATR multiplier for the emergency stop distance. |
| strategy_max_spread_points | 0 | integer >= 0 | Optional spread block in points; 0 disables the strategy-level spread gate. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 index port named by the approved card; valid backtest-only custom symbol.
- NDX.DWX - Nasdaq 100 index port named by the approved card.
- WS30.DWX - Dow 30 index port named by the approved card.
- GDAXI.DWX - DAX custom-symbol port; used because the card names GER40.DWX but the DWX matrix canonical DAX symbol is GDAXI.DWX.
- EURUSD.DWX - Forex major port named by the approved card.

**Explicitly NOT for:**
- GER40.DWX - Card-stated DAX alias is not present in `dwx_symbol_matrix.csv`; this build uses GDAXI.DWX.
- Any unregistered `.DWX` symbol - magic resolution is registered only for the five symbols above.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none beyond the configurable signal timeframe input |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Expected trade frequency | Not specified in card frontmatter; H4 cadence implies multi-day to weekly opportunities. |
| Typical hold time | Not specified in card frontmatter; positions hold until opposite MACD/SMA condition, ATR stop, or framework Friday close. |
| Expected drawdown profile | Fixed-risk P2 baseline with ATR emergency stop and V5 kill-switch controls. |
| Regime preference | Trend-following and momentum-filtered regimes. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 30591366-874b-5bee-b47c-da2fca20b728
**Source type:** TradingView script page
**Pointer:** https://www.tradingview.com/script/yMCa3XZD-MACD-SMA-200-Strategy-by-ChartArt/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10248_tv-macd-sma200.md`

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
| v1 | 2026-06-10 | Initial build from card | ddf90b9c-78e6-442a-b3df-9320d4e1e862 |
