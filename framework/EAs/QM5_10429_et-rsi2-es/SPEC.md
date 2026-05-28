# QM5_10429_et-rsi2-es - Strategy Spec

**EA ID:** QM5_10429
**Slug:** `et-rsi2-es`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-27

---

## 1. Strategy Logic

The EA trades M5 RSI(2) exhaustion on completed bars. It enters long on the next bar when RSI(2) is below 2, and enters short on the next bar when RSI(2) is above 98. Each trade uses a stop distance equal to the greater of 6 index points or 1.5 times ATR(20), with a profit target at 2.0 times the stop distance. An opposite RSI extreme closes the current position, then the EA waits for the next completed bar before allowing a new opposite entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rsi_period` | 2 | 2-4 | RSI lookback used for completed-bar extreme signals. |
| `strategy_long_threshold` | 2.0 | 2-10 | Long entry and short-exit threshold. |
| `strategy_short_threshold` | 98.0 | 90-98 | Short entry and long-exit threshold. |
| `strategy_atr_period` | 20 | 20 | ATR lookback used for CFD-normalized stop sizing. |
| `strategy_atr_stop_mult` | 1.5 | 1.0-2.0 | ATR multiplier in the stop-distance floor. |
| `strategy_fixed_stop_points` | 6.0 | 6.0 | Source ES fixed stop, expressed as index price points. |
| `strategy_target_stop_ratio` | 2.0 | 1.0-2.0 | Profit target as a multiple of stop distance. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - direct S&P 500 custom-symbol port of the ES/SPX exposure in the card; backtest-only per symbol discipline.
- `NDX.DWX` - live-tradable US large-cap index CFD used for portable US equity-index exposure.
- `WS30.DWX` - live-tradable US large-cap index CFD used for portable US equity-index exposure.
- `GDAXI.DWX` - matrix-valid DAX CFD used for the card's `GER40.DWX` DAX basket item.

**Explicitly NOT for:**
- `ES.DWX` - not present in the DWX symbol matrix.
- `SPX500.DWX` - unavailable; `SP500.DWX` is the canonical S&P 500 custom symbol.
- `GER40.DWX` - card-stated name is not present in the DWX symbol matrix; this build registers `GDAXI.DWX`.

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
| Typical hold time | minutes to hours, bounded by fixed stop/target or opposite RSI extreme |
| Expected drawdown profile | whipsaw-sensitive short-term mean reversion with slippage sensitivity |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `https://www.elitetrader.com/et/threads/strategy-test-request.26230/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10429_et-rsi2-es.md`

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
| v1 | 2026-05-27 | Initial build from card | 21099914-fe1f-4300-b24d-6ffe3a4afcbb |
