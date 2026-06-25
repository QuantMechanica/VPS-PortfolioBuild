# QM5_9520_mql5-entropy - Strategy Spec

**EA ID:** QM5_9520
**Slug:** `mql5-entropy`
**Source:** `a120af9a-fb72-526c-bb80-d1d098a617b5` (see `artifacts/cards_approved/QM5_9520_mql5-entropy.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA classifies each closed M15 bar as up, down, or flat based on the close-to-close change exceeding `PriceStep` points. It computes normalized Shannon entropy over base, fast, and slow lookbacks, then derives smoothed entropy, entropy momentum, fast-minus-slow divergence, regime, and compression/decompression state. It buys when a bullish entropy crossover, compression breakout, or positive decompression-end event is confirmed by non-chaotic entropy, positive momentum, and acceptable divergence. It sells on the inverse bearish crossover, chaotic transition, strong negative divergence, or negative compression-end event, with fixed point SL/TP and optional close-on-opposite signal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entropy_period` | 50 | 5-500 | Base entropy lookback over up/down/flat states. |
| `strategy_smoothing_period` | 10 | 1-100 | SMA smoothing applied to base entropy. |
| `strategy_momentum_period` | 5 | 1-100 | Bars back for entropy momentum comparison. |
| `strategy_fast_entropy_period` | 20 | 2-300 | Fast entropy lookback used for cross/divergence. |
| `strategy_slow_entropy_period` | 100 | 5-500 | Slow entropy lookback used for cross/divergence. |
| `strategy_price_step_points` | 1 | 0-1000 | Minimum close-to-close movement in points to classify up/down. |
| `strategy_signal_threshold` | 0.15 | 0.00-1.00 | Divergence threshold for signal confirmation. |
| `strategy_compression_zone` | 0.30 | 0.00-1.00 | Entropy level considered compressed. |
| `strategy_decompression_zone` | 0.50 | 0.00-1.00 | Entropy level considered decompressed. |
| `strategy_compression_bars` | 5 | 1-100 | Compression/decompression confirmation context. |
| `strategy_min_signal_gap_bars` | 10 | 0-500 | Minimum bars between same-direction entries. |
| `strategy_stop_loss_points` | 100 | 0-100000 | Fixed stop loss in MT5 points. |
| `strategy_take_profit_points` | 200 | 0-100000 | Fixed take profit in MT5 points. |
| `strategy_reverse_on_opposite` | true | true/false | Close an existing position when the opposite signal is detected. |
| `strategy_max_spread_points` | 0 | 0-100000 | Optional wide-spread guard; zero disables it for DWX zero-spread tests. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - Card-listed gold market with DWX OHLC history.
- `EURUSD.DWX` - Card-listed major FX pair with DWX OHLC history.
- `GBPUSD.DWX` - Card-listed major FX pair with DWX OHLC history.
- `GDAXI.DWX` - Verified DWX DAX symbol used as the available matrix port for card-listed `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - Card-listed name is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is registered instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | intraday to multi-bar M15 holds until fixed SL/TP or opposite signal |
| Expected drawdown profile | medium, controlled by fixed point stop and V5 risk sizing |
| Regime preference | volatility-expansion / compression-breakout with momentum confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `a120af9a-fb72-526c-bb80-d1d098a617b5`
**Source type:** `MQL5 article`
**Pointer:** `https://www.mql5.com/en/articles/21742`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9520_mql5-entropy.md`

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
| v1 | 2026-06-25 | Initial build from card | d4fe2f0a-d6c4-4e2b-990a-4c9352718ac4 |
