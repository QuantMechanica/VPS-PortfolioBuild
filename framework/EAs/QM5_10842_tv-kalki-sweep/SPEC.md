# QM5_10842_tv-kalki-sweep - Strategy Spec

**EA ID:** QM5_10842
**Slug:** `tv-kalki-sweep`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades a liquidity sweep and reclaim on the close of an M5 or M15 bar. It finds the nearest recent internal swing high or low using a fixed left/right lookback, then buys when price pierces below a swing low and closes back above it while close is above EMA(200). It sells when price pierces above a swing high and closes back below it while close is below EMA(200). The stop is placed beyond the sweep wick by 0.25 * ATR(14), and the target is fixed at 3.0R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_swing_lookback` | 5 | 3-8 tested by card | Bars left/right used to confirm internal swing highs and lows. |
| `strategy_ema_period` | 200 | off, 100, 200 tested by card | EMA trend guard period; baseline uses EMA(200). |
| `strategy_atr_period` | 14 | fixed by card | ATR period used for sweep-wick stop buffer. |
| `strategy_atr_buffer_mult` | 0.25 | 0.10-0.50 tested by card | ATR multiple added beyond the sweep wick for stop placement. |
| `strategy_target_r` | 3.0 | 2.0-3.0 tested by card | Fixed reward-to-risk target multiple. |
| `strategy_allow_next_reclaim` | true | false/true | Allows the reclaim to occur on the candle after the sweep. |
| `strategy_max_swing_scan` | 80 | 20-200 practical bound | Maximum closed bars scanned for the most recent internal swing. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - card names gold as a primary source market.
- `XAGUSD.DWX` - card names silver as a primary source market.
- `XTIUSD.DWX` - card names crude oil as a primary source market.
- `GDAXI.DWX` - matrix-backed DAX equivalent for the card's `GER40.DWX`.
- `EURUSD.DWX` - FX control symbol explicitly listed in the card's P2 basket.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; registered as `GDAXI.DWX` instead.
- `SP500.DWX` - mentioned only as a possible later test path, not part of the card's primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `M15` is a P3 timeframe axis; no cross-timeframe reads in the EA. |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `140` |
| Typical hold time | Intraday; exact hold time is not specified in the card frontmatter. |
| Expected drawdown profile | Wide fixed-RR reversal system with false-reclaim risk in strong trends. |
| Regime preference | Intraday liquidity-sweep reversal aligned with EMA trend. |
| Win rate target (qualitative) | Low-to-medium win rate acceptable because baseline target is 3.0R. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** `https://www.tradingview.com/script/gFMT7BUb-KALKI-TFXBOT/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10842_tv-kalki-sweep.md`

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
| v1 | 2026-06-06 | Initial build from card | 77f7ed87-eefc-4c46-a1fe-053b6b3b5de8 |
