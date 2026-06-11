# QM5_10113_tv-ob-matrix - Strategy Spec

**EA ID:** QM5_10113
**Slug:** tv-ob-matrix
**Source:** 30591366-874b-5bee-b47c-da2fca20b728 (see TradingView citation in approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

This EA trades M15 rejection entries from qualified order blocks. A bullish block is the latest non-invalidated bearish candle whose next closed candle displaced above the block high; a bearish block is the mirror case with a bullish candle and a close below the block low. The candidate block must have volume at least 1.25 times its 20-bar volume average and a height between 0.5 and 3.0 ATR(14). Long entries require the closed bar to trade through the bullish block and close back above its midpoint; shorts require a touch of the bearish block and a close back below its midpoint. Stops sit beyond the block edge by 0.25 ATR(14), take profit is 2.0R, and an opposite closed-bar rejection signal closes an existing position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_ob_lookback | 24 | >= 2 bars | Closed-bar window searched for the latest qualified order block. |
| strategy_atr_period | 14 | >= 1 | ATR period used for block-height qualification and stop buffer. |
| strategy_volume_sma_period | 20 | >= 1 | Volume average period for the block volume ratio. |
| strategy_volume_ratio_min | 1.25 | > 0 | Minimum block volume divided by average volume. |
| strategy_block_min_atr | 0.50 | >= 0 | Minimum block height as a multiple of ATR(14). |
| strategy_block_max_atr | 3.00 | > min | Maximum block height as a multiple of ATR(14). |
| strategy_stop_atr_buffer | 0.25 | >= 0 | ATR buffer beyond the order-block edge for SL placement. |
| strategy_trade_rr | 2.00 | > 0 | Risk-reward multiple for take profit. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed major FX symbol with DWX matrix support.
- GBPUSD.DWX - Card-listed major FX symbol with DWX matrix support.
- XAUUSD.DWX - Card-listed gold CFD with DWX matrix support.
- GDAXI.DWX - DWX matrix DAX symbol used as the available equivalent for card-listed GER40.DWX.

**Explicitly NOT for:**
- GER40.DWX - Not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX equivalent.
- Symbols outside the registered basket - Not validated for this card's P2 baseline.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 64 |
| Typical hold time | Not specified in frontmatter; intraday M15 entries exit by SL, 2R TP, Friday close, or opposite rejection. |
| Expected drawdown profile | Fixed-risk intraday order-block rejection trades with full loss capped by block-edge stop. |
| Regime preference | Rejection from volume-qualified order blocks after displacement. |
| Win rate target (qualitative) | Medium; card expects active but filtered 40-90 trades/year/symbol. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 30591366-874b-5bee-b47c-da2fca20b728
**Source type:** TradingView script description
**Pointer:** AlphaExtract, "Order Block Matrix Trade Engine [Alpha Extract]", TradingView, 2026-05-17, https://www.tradingview.com/script/EUqp6aVS-Order-Block-Matrix-Trade-Engine-Alpha-Extract/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10113_tv-ob-matrix.md`

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
| v1 | 2026-06-12 | Initial build from card | 0228baa6-00d0-4814-b597-0061445b8198 |
