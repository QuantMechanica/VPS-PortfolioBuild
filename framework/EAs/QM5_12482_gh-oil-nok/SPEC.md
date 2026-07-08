# QM5_12482_gh-oil-nok - Strategy Spec

**EA ID:** QM5_12482
**Slug:** `gh-oil-nok`
**Source:** `af7930c8-6c65-52d1-9c01-040490b5ad39`
**Author of this spec:** Codex
**Last revised:** 2026-07-08

---

## 1. Strategy Logic

The EA fits a rolling D1 ordinary least-squares model of `USDJPY.DWX` against `XTIUSD.DWX` over the latest 50 closed bars. It trades `USDJPY.DWX` when the residual is more than 2.0 residual standard deviations from the fitted value: buy when USDJPY is cheap versus oil, sell when it is rich. It exits after 10 D1 bars or after a 0.50 price-unit move from entry, with an ATR(20) emergency stop cap.

This is the approved DWX port of the Oil/NOK source because `USDNOK.DWX` and `XBRUSD.DWX` are absent from the current DWX matrix; `USDJPY.DWX` is the traded oil-sensitive FX proxy and `XTIUSD.DWX` is the oil signal input.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_train_len_d1` | 50 | 30-100 | D1 bars used for the rolling OLS fit. |
| `strategy_r2_min` | 0.70 | 0.60-0.80 | Minimum regression R-squared required before entries. |
| `strategy_entry_sigma` | 2.0 | 1.5-2.5 | Residual standard-deviation threshold for entry. |
| `strategy_max_hold_days` | 10 | 5-15 | Maximum holding period in D1 bars/days. |
| `strategy_source_move_exit` | 0.50 | 0.25-0.75 | Symmetric price move exit on USDJPY. |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR period for emergency stop distance. |
| `strategy_atr_sl_mult` | 2.5 | 1.5-3.0 | ATR multiplier for the emergency stop cap. |
| `strategy_usdjpy_max_spread_pts` | 120 | 0-240 | Wide-spread guard; zero modeled spread remains allowed. |

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - traded oil-sensitive FX proxy leg available in the DWX matrix.
- `XTIUSD.DWX` - oil signal input available in the DWX matrix.

**Explicitly NOT for:**
- `USDNOK.DWX` - preferred source traded leg, but absent from the current DWX matrix.
- `XBRUSD.DWX` - preferred Brent signal, but absent from the current DWX matrix.
- `XNGUSD.DWX` - natural gas is not part of the source thesis and is already overrepresented in the current survivor set.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none; cross-symbol D1 read of `XTIUSD.DWX` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 10 |
| Typical hold time | 5-10 days |
| Expected drawdown profile | Medium; residual relationship can break during oil/FX regime shifts. |
| Regime preference | Mean-reverting petrocurrency residual regimes. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `af7930c8-6c65-52d1-9c01-040490b5ad39`
**Source type:** GitHub source
**Pointer:** `https://github.com/je-suis-tm/quant-trading/blob/master/Oil%20Money%20project/Oil%20Money%20Trading%20backtest.py`
**R1-R4 verdict (Q00):** all PASS per `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12482_gh-oil-nok.md`

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
| v1 | 2026-07-08 | Initial build from card | task 5e884ea8-3f0b-4f54-b101-1fb8a574b287 |
