# QM5_1044_vpmacd-us-indices - Strategy Spec

**EA ID:** QM5_1044
**Slug:** vpmacd-us-indices
**Source:** 189848dd-bc95-53ff-b379-eb617715d38d (see `strategy-seeds/sources/189848dd-bc95-53ff-b379-eb617715d38d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

This EA is a long-only daily VP-MACD crossover strategy for U.S. equity index CFDs. It replaces daily close with a volume-price composite built from prior-session M5 bars, then calculates EMA(12) minus EMA(26) and an EMA(9) signal line. It buys when VP-MACD crosses above `lambda * Signal`, using the card's asymmetric entry discount, and exits when VP-MACD crosses below the undiscounted signal line. A hard ATR(14) * 2.5 stop is attached at entry because the source paper has no stop loss and V5 requires one.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_D1` | MT5 timeframe enum | Closed-bar timeframe used for VP-MACD crossover decisions. |
| `strategy_intraday_tf` | `PERIOD_M5` | MT5 timeframe enum | Intraday bars used to aggregate the daily volume-price adjusted price. |
| `strategy_fast_ema` | `12` | `1+` and `< strategy_slow_ema` | Fast EMA period for VP-MACD. |
| `strategy_slow_ema` | `26` | `> strategy_fast_ema` | Slow EMA period for VP-MACD. |
| `strategy_signal_ema` | `9` | `1+` | EMA period for the VP-MACD signal line. |
| `strategy_lambda` | `0.88` | `(0.0, 1.0)` | Entry sensitivity discount applied only to the signal line. |
| `strategy_warmup_bars` | `80` | `strategy_slow_ema + strategy_signal_ema + 2` or higher | Initial closed-bar history used to seed VP-MACD state once. |
| `strategy_atr_period` | `14` | `1+` | ATR period for the framework hard stop. |
| `strategy_atr_sl_mult` | `2.5` | `> 0` | ATR multiplier for the hard stop. |
| `strategy_max_spread_points` | `250.0` | `0+` | Blocks entries when current spread exceeds this many points; zero disables the filter. |
| `strategy_cash_session_only` | `true` | `true/false` | Enables the cash-session filter on intraday charts. |
| `strategy_cash_start_hhmm` | `1630` | `0000-2359` | Broker-time session start for intraday charts. |
| `strategy_cash_end_hhmm` | `2300` | `0000-2359` | Broker-time session end for intraday charts. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - canonical DWX custom symbol for S&P 500 exposure, replacing the card's SPY/SPX500 wording.
- `NDX.DWX` - DWX Nasdaq 100 exposure, replacing the paper's QQQ ticker.
- `WS30.DWX` - DWX Dow 30 exposure, replacing the paper's DIA ticker.

**Explicitly NOT for:**
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - not canonical available DWX symbols for this build.
- Non-index forex and commodity symbols - the source edge is calibrated to U.S. equity index ETFs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `M5` bars are aggregated into each closed D1 session for P-star. |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default skeleton gate before `Strategy_EntrySignal`) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `50` |
| Typical hold time | Several days; exit waits for the opposite daily VP-MACD crossover. |
| Expected drawdown profile | Trend-following equity-index drawdowns during sideways or fast mean-reverting regimes. |
| Regime preference | Momentum / trend-following. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 189848dd-bc95-53ff-b379-eb617715d38d
**Source type:** paper
**Pointer:** https://arxiv.org/abs/2604.26063 and `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1044_vpmacd-us-indices.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1044_vpmacd-us-indices.md`

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
| v1 | 2026-06-13 | Initial build from card | ccebbe49-2845-4696-b603-10ff0f193908 |
