# QM5_10855_tv-inside2-bo - Strategy Spec

**EA ID:** QM5_10855
**Slug:** `tv-inside2-bo`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (TradingView open-source strategy)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA waits for a mother candle followed by two consecutive inside candles. After the second inside candle closes, it places a buy stop one point above the mother candle high and a sell stop one point below the mother candle low. The long stop is the mother candle low minus 0.10 ATR(14), the short stop is the mother candle high plus 0.10 ATR(14), and each target is 1.5R. If one side fills, the remaining opposite stop is cancelled; if neither side fills, the pending stops expire after 8 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | 1+ | ATR period used for mother-candle width and stop buffer. |
| `strategy_mother_min_atr_mult` | 0.25 | >0 | Skip mother candles narrower than this ATR multiple. |
| `strategy_mother_max_atr_mult` | 2.50 | > min | Skip mother candles wider than this ATR multiple. |
| `strategy_stop_buffer_atr_mult` | 0.10 | >0 | ATR multiple added beyond the mother candle for stop placement. |
| `strategy_rr_target` | 1.50 | >0 | Fixed reward-to-risk take-profit multiple. |
| `strategy_entry_offset_points` | 1 | 1+ | Stop-entry offset beyond the mother high or low, in raw points. |
| `strategy_order_expiry_bars` | 8 | 1+ | Pending stop order lifetime after the second inside candle closes. |
| `strategy_spread_stop_max_ratio` | 0.15 | >0 | Skip setup if spread exceeds this fraction of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - Card states XAUUSD M5 as the best-fit baseline.
- `EURUSD.DWX` - Card R3 names this liquid FX symbol for P2 portability.
- `GBPUSD.DWX` - Card R3 names this liquid FX symbol for P2 portability.
- `NDX.DWX` - Card R3 names this index CFD for P2 portability.
- `GDAXI.DWX` - DAX equivalent used because the card names `GER40.DWX`, while the DWX matrix canonical DAX symbol is `GDAXI.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | Minutes to several M5 or M15 bars, bounded by SL/TP or pending-order expiry. |
| Expected drawdown profile | High-cadence breakout whipsaw risk during low-liquidity ranges. |
| Regime preference | Volatility-expansion breakout after short-term compression. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** `https://www.tradingview.com/script/POwPhe4N-True-2-Inside-Candle-Breakout/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10855_tv-inside2-bo.md`

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
| v1 | 2026-06-06 | Initial build from card | 7999a85b-8cd3-44a1-b499-3f55b783932c |
