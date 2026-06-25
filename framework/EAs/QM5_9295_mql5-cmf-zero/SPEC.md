# QM5_9295_mql5-cmf-zero - Strategy Spec

**EA ID:** QM5_9295
**Slug:** `mql5-cmf-zero`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA calculates Chaikin Money Flow over the last 20 closed bars using high, low, close, and MT5 tick volume. It opens long when the previous closed-bar CMF is below zero and the latest closed-bar CMF is above zero. It opens short when the previous closed-bar CMF is above zero and the latest closed-bar CMF is below zero. Positions use a fixed 300-point stop loss, a fixed 900-point take profit, and close on the opposite zero-line crossover before reversing.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_cmf_period` | `20` | `1+` | Closed-bar Chaikin Money Flow lookback. |
| `strategy_stop_loss_points` | `300` | `1+` | Fixed stop distance in MT5 points from the entry price. |
| `strategy_take_profit_points` | `900` | `1+` | Fixed take-profit distance in MT5 points from the entry price. |
| `strategy_spread_cap_points` | `1000` | `0+` | Optional no-trade cap for genuinely wide spread; zero modeled spread remains tradeable. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX major with OHLC and tick volume in the DWX matrix.
- `GBPUSD.DWX` - card-listed FX major with OHLC and tick volume in the DWX matrix.
- `XAUUSD.DWX` - card-listed gold symbol with OHLC and tick volume in the DWX matrix.
- `GDAXI.DWX` - registered as the available DAX custom symbol because `GER40.DWX` is not present in `dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - broker/custom-symbol data is not available for V5 backtests.

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
| Trades / year / symbol | `120` |
| Typical hold time | not specified in card frontmatter; exits at fixed SL/TP or opposite CMF zero-cross |
| Expected drawdown profile | not specified in card frontmatter; fixed 300-point stop bounds per-trade loss through V5 risk sizing |
| Regime preference | volume-momentum / trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** `MQL5 article`
**Pointer:** `https://www.mql5.com/en/articles/16469`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9295_mql5-cmf-zero.md`

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
| v1 | 2026-06-25 | Initial build from card | 45eabf13-2b53-4e49-898e-e0c64af7be22 |
