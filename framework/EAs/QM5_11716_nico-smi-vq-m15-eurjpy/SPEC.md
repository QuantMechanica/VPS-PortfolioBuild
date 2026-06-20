# QM5_11716_nico-smi-vq-m15-eurjpy — Strategy Spec

**EA ID:** QM5_11716
**Slug:** `nico-smi-vq-m15-eurjpy`
**Source:** `5071d002-b640-5386-a182-9c7dd3551d60` (see `strategy-seeds/sources/5071d002-b640-5386-a182-9c7dd3551d60/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

Multi-indicator confluence on M15 EURJPY. Long entries require SMI curling up
from below `-40` or up from the zero-line zone, EMA(5) crossing above EMA(6), a
white Heiken Ashi candle, rising VQ, and Stochastic %K crossing above 20 within
the prior three closed bars. Short entries are the mirror: SMI curling down from
above `+40`, EMA(5) crossing below EMA(6), a red Heiken Ashi candle, falling VQ,
and Stochastic %K crossing below 80.

The EA only considers entries from 07:00 GMT onward. It opens at market on the
next bar, uses a 2xATR(14) stop, and uses the card's factory fixed 35-pip
take-profit. SMI is implemented as a bounded Blau-style double-smoothed
high/low-range oscillator; VQ is implemented as the card-authorized simplified
ATR/range-normalized directional proxy.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `smi_hl_period` | 14 | 5-30 | SMI N-bar high/low lookback (%K length) |
| `smi_smooth1` | 10 | 3-30 | SMI first EMA smoothing period |
| `smi_smooth2` | 14 | 3-30 | SMI second EMA smoothing period |
| `smi_extreme` | 40.0 | 20-60 | SMI extreme zone threshold (±) |
| `ema_fast_period` | 5 | 2-20 | MA-crossover fast EMA |
| `ema_slow_period` | 6 | 3-30 | MA-crossover slow EMA |
| `stoch_k_period` | 10 | 5-30 | Stochastic %K period |
| `stoch_d_period` | 1 | 1-10 | Stochastic %D period |
| `stoch_slowing` | 7 | 1-20 | Stochastic slowing |
| `vq_length` | 5 | 2-20 | VQ range-normalization period |
| `vq_smoothing` | 3 | 1-20 | VQ smoothing period |
| `vq_filter_threshold` | 0.0 | 0-5 | Minimum absolute VQ proxy value |
| `atr_period` | 14 | 5-30 | ATR period (stop sizing + VQ scaling) |
| `sl_atr_mult` | 2.0 | 0.5-5 | Stop distance = mult × ATR |
| `take_profit_pips` | 35 | 10-80 | Factory fixed take-profit in pips |
| `session_start_gmt_hour` | 7 | 0-23 | Earliest GMT hour to take entries |
| `max_spread_pips` | 8 | 1-50 | Skip only if modeled spread is wider than this |

---

## 3. Symbol Universe

**Designed for:**
- `EURJPY.DWX` — the card's sole target symbol; SMI/VQ M15 confluence tuned to EURJPY volatility (JPY-cross, ~35-pip swings). Verified present in `dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- Index CFDs (`NDX.DWX`, `WS30.DWX`, `SP500.DWX`) — card is a JPY-cross M15 forex system; pip scaling and session logic do not transfer.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~120` |
| Typical hold time | `hours (intraday M15)` |
| Expected drawdown profile | `moderate; tight 2×ATR stop, RR-capped target` |
| Regime preference | `momentum / volatility-expansion out of extremes` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `5071d002-b640-5386-a182-9c7dd3551d60`
**Source type:** `forum`
**Pointer:** `forexstrategiesresources.com #301 "Easy 15min Trading System" (Nico, ~2012), local PDF 353827940`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11716_nico-smi-vq-m15-eurjpy.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-20 | Initial build from card | b60df2bd-3168-4a22-a72a-87bad8c389ca |
