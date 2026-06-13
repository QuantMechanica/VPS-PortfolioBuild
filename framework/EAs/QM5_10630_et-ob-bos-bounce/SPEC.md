# QM5_10630_et-ob-bos-bounce - Strategy Spec

**EA ID:** QM5_10630
**Slug:** `et-ob-bos-bounce`
**Source:** `cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64` (see `strategy-seeds/sources/cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA evaluates completed M30 bars for a break of structure after confirmed 3-left/3-right swing points. A long setup requires rising swing lows, a higher swing high, a close above the latest swing high by at least 0.10 ATR, a close in the top quarter of the candle, and a bullish imbalance. It then places a buy limit at the midpoint of the last bearish order-block candle before the break; shorts mirror the same rules below structure. Stops sit beyond the order block by 0.15 ATR, targets are 1.8R, pending orders expire after 8 bars, and open trades time-exit after 32 M30 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_swing_width` | 3 | 1-10 | Fractal width on each side for confirmed swing highs/lows. |
| `strategy_atr_period` | 14 | 1-100 | ATR period used for BOS threshold, OB height, and stop buffer. |
| `strategy_bos_atr_mult` | 0.10 | 0.00-1.00 | Minimum close-through distance beyond structure as ATR multiple. |
| `strategy_close_extreme_pct` | 0.25 | 0.00-0.50 | Maximum distance from the candle extreme for BOS close validation. |
| `strategy_ob_min_atr_mult` | 0.20 | 0.00-5.00 | Minimum order-block height as ATR multiple. |
| `strategy_ob_max_atr_mult` | 1.25 | 0.00-5.00 | Maximum order-block height as ATR multiple. |
| `strategy_ob_entry_pct` | 0.50 | 0.00-1.00 | Entry location inside the order block; 0.50 is midpoint. |
| `strategy_sl_atr_mult` | 0.15 | 0.00-2.00 | Stop buffer beyond the order-block edge as ATR multiple. |
| `strategy_target_rr` | 1.80 | 0.10-10.00 | Take-profit reward multiple versus initial risk. |
| `strategy_expiry_bars` | 8 | 1-100 | Pending limit order expiry in M30 bars. |
| `strategy_time_exit_bars` | 32 | 1-500 | Maximum hold time in M30 bars. |
| `strategy_structure_lookback` | 80 | 20-500 | Maximum closed-bar window for swing and order-block search. |
| `strategy_max_spread_points` | 80 | 0-10000 | No-trade filter spread ceiling in broker points; 0 disables. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX major with DWX coverage.
- `GBPUSD.DWX` - card-listed liquid FX major with DWX coverage.
- `XAUUSD.DWX` - card-listed gold market with DWX coverage.
- `SP500.DWX` - card-listed S&P 500 custom symbol, valid for backtest with T6 live caveat.
- `GDAXI.DWX` - matrix-valid DAX equivalent for card-listed `GER40.DWX`, which is not present in the DWX matrix.

**Explicitly NOT for:**
- `GER40.DWX` - card name is not available in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P 500 variants; use `SP500.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `55` |
| Typical hold time | Up to 32 M30 bars, roughly 16 hours. |
| Expected drawdown profile | Bounded single-position order-block continuation trades with fixed 1R initial risk. |
| Regime preference | Trend-continuation after structure break and imbalance. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64`
**Source type:** forum
**Pointer:** `https://www.elitetrader.com/et/threads/a-way-to-track-the-moves-of-big-players.380018/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10630_et-ob-bos-bounce.md`

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
| v1 | 2026-06-13 | Initial build from card | 7d23016f-2ebc-4135-9710-577ab1d5eb53 |
