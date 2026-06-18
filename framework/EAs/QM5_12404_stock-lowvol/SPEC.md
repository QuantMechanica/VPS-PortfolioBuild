# QM5_12404_stock-lowvol - Strategy Spec

**EA ID:** QM5_12404
**Slug:** `stock-lowvol`
**Source:** `b7832a20-938e-5f24-b9d7-e0b2ab63b623` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA rebalances once per calendar month on D1 data. It computes weekly returns by sampling 5-bar blocks over the configured D1 lookback, calculates the standard deviation of those weekly returns for every registered basket symbol, then ranks the symbols from lowest volatility to highest volatility. The EA goes long only when the chart symbol is inside the lowest-volatility bucket and closes the position after a monthly rebalance when the symbol leaves that bucket. Entries use an emergency ATR stop; there is no profit target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_vol_lookback_d1` | 252 | 126-378 | D1 bars used for weekly-return volatility ranking. |
| `strategy_bucket_size` | 1 | 1-3 | Number of lowest-volatility symbols eligible for long entries. |
| `strategy_min_valid_symbols` | 6 | 1-7 | Minimum symbols with usable history before the basket can hold risk. |
| `strategy_min_warmup_d1` | 270 | 270+ | Minimum D1 warmup requested from the tester. |
| `strategy_atr_period_d1` | 20 | 5-60 | D1 ATR period for the emergency stop. |
| `strategy_atr_sl_mult` | 2.5 | 0.5-10.0 | ATR multiplier for each leg's emergency stop. |
| `strategy_spread_median_days` | 60 | 10-120 | D1 spread lookback for the spread safety baseline. |
| `strategy_spread_median_mult` | 2.0 | 1.0-5.0 | Blocks only genuinely wide spread relative to the median baseline. |
| `strategy_use_sma200_filter` | false | true/false | Optional P3 ablation: require close above SMA(200). |
| `strategy_sma_period_d1` | 200 | 100-300 | SMA period used when the optional trend safety filter is enabled. |
| `strategy_basket_stop_r` | 5.0 | 1.0-10.0 | Basket emergency stop in R units of active risk. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol, matching the card's US large-cap basket.
- `NDX.DWX` - Nasdaq 100 exposure from the card's large-cap CFD port.
- `WS30.DWX` - Dow 30 exposure from the card's large-cap CFD port.
- `GDAXI.DWX` - DAX port for card-stated `GER40.DWX`, which is not in the matrix.
- `UK100.DWX` - FTSE 100 exposure from the card's global index basket.
- `XAUUSD.DWX` - gold CFD exposure from the card's reduced CFD basket.
- `XTIUSD.DWX` - oil CFD exposure from the card's reduced CFD basket.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is registered instead.
- `JP225.DWX` - not present in `dwx_symbol_matrix.csv`; no Japan symbol was registered.
- Non-DWX symbols - backtest and research artifacts must keep the `.DWX` suffix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | about one month |
| Expected drawdown profile | concentrated long-only factor drawdown during high-volatility rotations or risk-on rebounds |
| Regime preference | low-volatility, long-only, monthly rebalance |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b7832a20-938e-5f24-b9d7-e0b2ab63b623`
**Source type:** public implementation / catalog
**Pointer:** Papers With Backtest / Quantpedia implementation, Low Volatility Factor Effect in Stocks.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_12404_stock-lowvol.md`.

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
| v1 | 2026-06-18 | Initial build from card | cc9eeed9-f92d-43cc-89aa-48de646373b0 |
