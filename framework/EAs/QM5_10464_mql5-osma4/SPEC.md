# QM5_10464_mql5-osma4 - Strategy Spec

**EA ID:** QM5_10464
**Slug:** `mql5-osma4`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA trades the closed-bar arrow signals from the MQL5 OsMA Four Colors Arrow logic. OsMA is calculated as MACD main minus MACD signal using the configured OsMA periods; a buy arrow is a transition from falling below zero to rising below zero, and a sell arrow is a transition from rising above zero to falling above zero. The EA enters at market on the next bar when there is no open same-symbol same-magic position, closes on the opposite arrow, and places a protective 1.5 x ATR(14) stop with a 2R target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_osma_fast_ema_period` | 12 | 1-100 | Fast EMA period for the OsMA calculation. |
| `strategy_osma_slow_ema_period` | 26 | 2-200 | Slow EMA period for the OsMA calculation; must be greater than fast period. |
| `strategy_osma_signal_period` | 9 | 1-100 | Signal smoothing period for the MACD/OsMA calculation. |
| `strategy_osma_applied_price` | `PRICE_CLOSE` | MT5 applied price enum | Price source for the OsMA calculation. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for the protective stop. |
| `strategy_atr_sl_mult` | 1.5 | 0.1-10.0 | Stop distance multiplier applied to ATR. |
| `strategy_tp_rr` | 2.0 | 0.1-10.0 | Take-profit multiple of initial risk. |
| `strategy_min_bars` | 80 | 10-1000 | Minimum bars required before evaluating signals. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - only strategy-specific
> inputs are listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid DWX FX major with OHLC history suitable for OsMA/MACD signals.
- `GBPUSD.DWX` - card-listed liquid DWX FX major with OHLC history suitable for OsMA/MACD signals.
- `USDJPY.DWX` - card-listed liquid DWX FX major with OHLC history suitable for OsMA/MACD signals.
- `GDAXI.DWX` - canonical DWX DAX symbol used as the matrix-verified port for card-listed `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - card-listed name is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX equivalent.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `55` |
| Typical hold time | `hours to days` |
| Expected drawdown profile | `Momentum oscillator strategy with bounded fixed-risk ATR stops and 2R targets.` |
| Regime preference | `momentum / indicator-signal` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/39688` and `artifacts/cards_approved/QM5_10464_mql5-osma4.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10464_mql5-osma4.md`

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
| v1 | 2026-05-28 | Initial build from card | 607f381d-f327-4c27-9015-00a5769fce7e |
