# QM5_11210_ft-binhv27 — Strategy Spec

**EA ID:** QM5_11210
**Slug:** `ft-binhv27`
**Source:** `1580128f-e465-5454-bb97-a7572a6cfd6d` (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades long-only M5 closed-bar reversals. It requires price below EMA(60) and EMA(120), MinusDI above its EMA(25), RSI(5) not falling versus the prior bar, and one of the card's ADX plus SMA trend-state branches to be true. The trend state uses SMA(120), SMA(240), the SMA spread, and consecutive SMA(240) rises to classify bigup, bigdown, and continueup conditions. Exits follow the source branch logic using EMA(60), EMA(120), SMA(240), EMA-RSI, ADX, DI flip, confirmed trend-change, and slowing SMA(120) delta; the protective stop is ATR(14) times 2.0.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rsi_period` | 5 | fixed from card | RSI lookback used by the reversal condition. |
| `strategy_emarsi_period` | 5 | fixed from card | EMA period applied to RSI values. |
| `strategy_adx_period` | 14 | fixed source default | ADX and DI lookback. |
| `strategy_di_ema_period` | 25 | fixed from card | EMA period applied to MinusDI. |
| `strategy_plusdi_ema_period` | 5 | fixed from card | Source PlusDI EMA period retained as a visible strategy parameter. |
| `strategy_lowsma_ema_period` | 60 | fixed from card | Source `lowsma`, implemented as EMA(60). |
| `strategy_highsma_ema_period` | 120 | fixed from card | Source `highsma`, implemented as EMA(120). |
| `strategy_fast_sma_period` | 120 | fixed from card | Fast SMA used for bigup and trend delta. |
| `strategy_slow_sma_period` | 240 | 180-300 | Slow SMA used for warmup, bigup, continueup, and exit checks. |
| `strategy_emarsi_entry_low` | 20.0 | 15-25 | Oversold EMA-RSI threshold for the first three entry branches. |
| `strategy_emarsi_entry_continue` | 25.0 | fixed from card | EMA-RSI threshold for the continueup and bigup entry branch. |
| `strategy_adx_branch_low` | 25.0 | 20-30 | ADX threshold for the low branch. |
| `strategy_adx_branch_mid` | 30.0 | fixed from card | ADX threshold for continueup and one exit branch. |
| `strategy_adx_branch_high` | 35.0 | 30-40 | ADX threshold for the high branch. |
| `strategy_exit_emarsi_high` | 75.0 | fixed from card | EMA-RSI threshold for normal branch exits. |
| `strategy_exit_emarsi_extreme` | 80.0 | fixed from card | EMA-RSI threshold for the bigup ADX exit. |
| `strategy_atr_period` | 14 | fixed MT5 baseline | ATR period for protective stop. |
| `strategy_atr_stop_mult` | 2.0 | 1.5-2.5 | ATR multiplier for protective stop. |
| `strategy_max_spread_stop_pct` | 0.06 | fixed from card | Maximum spread as a fraction of planned stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card-listed primary forex symbol with DWX OHLC data available.
- `GBPUSD.DWX` — card-listed forex symbol with DWX OHLC data available.
- `USDJPY.DWX` — card-listed forex symbol with DWX OHLC data available.
- `XAUUSD.DWX` — card-listed metal symbol with DWX OHLC data available.

**Explicitly NOT for:**
- Non-DWX symbols — the build and P2 setfiles use the DWX symbol universe only.
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` — no tick data is available for framework backtests.

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
| Trades / year / symbol | `120` |
| Typical hold time | Card does not specify; expected M5 scalping holds from minutes to intraday. |
| Expected drawdown profile | High risk class from initial profile; ATR stop limits MT5 baseline loss. |
| Regime preference | M5 oversold EMA-RSI entries gated by ADX and long SMA trend states. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** GitHub strategy source
**Pointer:** `https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/berlinguyinca/BinHV27.py`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11210_ft-binhv27.md`

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
| v1 | 2026-06-08 | Initial build from card | 487d4419-1b4c-47ca-8ec3-45bbfabfc273 |
