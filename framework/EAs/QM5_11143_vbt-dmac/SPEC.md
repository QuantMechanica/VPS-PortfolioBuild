# QM5_11143_vbt-dmac - Strategy Spec

**EA ID:** QM5_11143
**Slug:** vbt-dmac
**Source:** 3f3833d9-8676-52e4-a822-2c5fc87bbe20 (see strategy-seeds/sources/3f3833d9-8676-52e4-a822-2c5fc87bbe20/)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates a dual simple moving average crossover on each completed D1 bar. It computes a fast SMA and slow SMA on Open price; a long signal occurs when the fast SMA crosses above the slow SMA, and a short signal occurs when the fast SMA crosses below the slow SMA. Entries are market orders on the first tick of the next bar, and exits occur on the opposite crossover. The strategy uses a fixed 3.0 * ATR(14) safety stop from entry for sizing and catastrophic protection.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_signal_tf | PERIOD_D1 | D1 primary | Timeframe used for SMA and ATR signal reads. |
| strategy_fast_window | 30 | 1 to slow_window - 1 | Fast SMA period from the source baseline. |
| strategy_slow_window | 80 | fast_window + 1 and higher | Slow SMA period from the source baseline. |
| strategy_atr_period | 14 | 1 and higher | ATR period for the V5 safety stop. |
| strategy_atr_sl_mult | 3.0 | greater than 0 | ATR multiplier for the safety stop. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed FX major; available in the DWX matrix.
- GBPUSD.DWX - card-listed FX major; available in the DWX matrix.
- USDJPY.DWX - card-listed FX major; available in the DWX matrix.
- XAUUSD.DWX - card-listed metal; available in the DWX matrix.
- GDAXI.DWX - DAX proxy used because the card lists GER40.DWX but the matrix canonical DAX symbol is GDAXI.DWX.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; registered DAX exposure uses GDAXI.DWX instead.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker/custom-symbol tick-data guarantee.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 6 |
| Typical hold time | Card does not give an explicit hold-time field; signal-reversal D1 crossover positions are expected to hold for days to weeks. |
| Expected drawdown profile | Trend-following crossover risk: late entries, whipsaw losses in ranges, low sample size on D1, and poor fit on symbols without sustained trends. |
| Regime preference | trend-following, symmetric long-short, signal-reversal exit |
| Win rate target (qualitative) | medium |

Expected trade frequency: D1 dual moving-average crossovers with 30/80 baseline are low cadence; conservative estimate 4-10 trades/year/symbol.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3f3833d9-8676-52e4-a822-2c5fc87bbe20
**Source type:** GitHub notebook example
**Pointer:** Oleg Polakow / vectorbt, BitcoinDMAC example notebook, https://github.com/polakowo/vectorbt/blob/master/examples/BitcoinDMAC.ipynb
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11143_vbt-dmac.md`

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
| v1 | 2026-06-07 | Initial build from card | 14486a11-4826-4d7e-a361-85c8fe01c535 |
