# QM5_12398_style-mom - Strategy Spec

**EA ID:** QM5_12398
**Slug:** style-mom
**Source:** b7832a20-938e-5f24-b9d7-e0b2ab63b623 (see `strategy-seeds/sources/b7832a20-938e-5f24-b9d7-e0b2ab63b623/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Once per calendar month on D1 bars, the EA ranks the registered DWX index proxy basket by 12-month close-to-close momentum. It opens or keeps one long position in the strongest ranked symbol and one short position in the weakest ranked symbol. At the next monthly rebalance, symbols that are no longer the strongest or weakest are closed, and reversed positions are closed before the new target side is opened. Each leg uses a 3.0 x ATR(20,D1) emergency stop, and the basket is closed if combined open PnL falls below -5R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_momentum_lookback_d1` | 252 | 126-252 | D1 bars used for the 12-month momentum ratio. |
| `strategy_min_ready_symbols` | 4 | 4-5 | Minimum symbols with valid momentum before a monthly rebalance is allowed. |
| `strategy_atr_period` | 20 | 10-50 | D1 ATR period for emergency stop placement. |
| `strategy_stop_atr_mult` | 3.0 | 2.0-4.0 | ATR multiple for each leg's stop loss. |
| `strategy_basket_stop_r_mult` | 5.0 | 1.0-10.0 | Basket open-PnL emergency stop in R units. |
| `strategy_spread_days` | 60 | 20-120 | D1 bars used for the MedianSpread filter snapshot. |
| `strategy_spread_median_mult` | 2.0 | 1.0-5.0 | Maximum current spread relative to median spread. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 proxy for US large-cap style exposure; backtest-only per matrix note.
- `NDX.DWX` - Nasdaq 100 proxy for US growth-heavy equity exposure.
- `WS30.DWX` - Dow 30 proxy for US large-cap value/cyclical exposure.
- `GDAXI.DWX` - DAX 40 proxy; canonical matrix name for the card's GER40 leg.
- `UK100.DWX` - FTSE 100 proxy for broad UK large-cap exposure.

**Explicitly NOT for:**
- `GER40.DWX` - card alias is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is used instead.
- `JP225.DWX` - not present in `dwx_symbol_matrix.csv`; no Japan index proxy was registered.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` with monthly rebalance state |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | About one month between rebalance checks |
| Expected drawdown profile | Sharp reversals possible during cross-sectional momentum crashes |
| Regime preference | Relative-strength trend / momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b7832a20-938e-5f24-b9d7-e0b2ab63b623
**Source type:** public GitHub implementation
**Pointer:** https://github.com/paperswithbacktest/awesome-systematic-trading/blob/main/static/strategies/momentum-factor-and-style-rotation-effect.py
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_12398_style-mom.md`

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
| v1 | 2026-06-18 | Initial build from card | dfff832c-56c2-40cd-8109-591a9c4e3e09 |
