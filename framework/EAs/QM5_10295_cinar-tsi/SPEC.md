# QM5_10295_cinar-tsi - Strategy Spec

**EA ID:** QM5_10295
**Slug:** cinar-tsi
**Source:** 1b906e79-c619-5a61-90db-ee19ac95a19f (see `strategy-seeds/sources/1b906e79-c619-5a61-90db-ee19ac95a19f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades the True Strength Index on D1 closed bars. It computes price change from close to prior close, applies EMA(25) and then EMA(13) to both price change and absolute price change, and sets TSI to `100 * PCDS / APCDS`. The signal line is EMA(12) of TSI. It opens long when TSI is above zero and above its signal line, opens short when TSI is below zero and below its signal line, and reverses an existing opposite position on the same closed-bar signal. Mixed TSI and signal states are held.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_tsi_first_period` | 25 | >= 2 | First EMA smoothing period for close-to-close price change. |
| `strategy_tsi_second_period` | 13 | >= 2 | Second EMA smoothing period applied to the first smoothed series. |
| `strategy_signal_period` | 12 | >= 2 | EMA period for the TSI signal line. |
| `strategy_tsi_warmup_bars` | 260 | >= 53 | D1 closed-bar history used to warm up the custom TSI calculation. |
| `strategy_atr_period` | 14 | >= 1 | ATR period used for the catastrophic V5 stop. |
| `strategy_atr_sl_mult` | 2.0 | > 0 | ATR multiple for the catastrophic stop loss. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `AUDCAD.DWX` - matrix-verified FX cross suitable for D1 close-derived momentum.
- `AUDCHF.DWX` - matrix-verified FX cross suitable for D1 close-derived momentum.
- `AUDJPY.DWX` - matrix-verified FX cross suitable for D1 close-derived momentum.
- `AUDNZD.DWX` - matrix-verified FX cross suitable for D1 close-derived momentum.
- `AUDUSD.DWX` - matrix-verified major FX pair suitable for D1 close-derived momentum.
- `CADCHF.DWX` - matrix-verified FX cross suitable for D1 close-derived momentum.
- `CADJPY.DWX` - matrix-verified FX cross suitable for D1 close-derived momentum.
- `CHFJPY.DWX` - matrix-verified FX cross suitable for D1 close-derived momentum.
- `EURAUD.DWX` - matrix-verified FX cross suitable for D1 close-derived momentum.
- `EURCAD.DWX` - matrix-verified FX cross suitable for D1 close-derived momentum.
- `EURCHF.DWX` - matrix-verified FX cross suitable for D1 close-derived momentum.
- `EURGBP.DWX` - matrix-verified FX cross suitable for D1 close-derived momentum.
- `EURJPY.DWX` - matrix-verified FX cross suitable for D1 close-derived momentum.
- `EURNZD.DWX` - matrix-verified FX cross suitable for D1 close-derived momentum.
- `EURUSD.DWX` - matrix-verified major FX pair suitable for D1 close-derived momentum.
- `GBPAUD.DWX` - matrix-verified FX cross suitable for D1 close-derived momentum.
- `GBPCAD.DWX` - matrix-verified FX cross suitable for D1 close-derived momentum.
- `GBPCHF.DWX` - matrix-verified FX cross suitable for D1 close-derived momentum.
- `GBPJPY.DWX` - explicitly named by the card and matrix-verified.
- `GBPNZD.DWX` - matrix-verified FX cross suitable for D1 close-derived momentum.
- `GBPUSD.DWX` - matrix-verified major FX pair suitable for D1 close-derived momentum.
- `GDAXI.DWX` - matrix canonical DAX symbol for the card's DAX reference.
- `NDX.DWX` - explicitly named by the card as an index trend instrument.
- `NZDCAD.DWX` - matrix-verified FX cross suitable for D1 close-derived momentum.
- `NZDCHF.DWX` - matrix-verified FX cross suitable for D1 close-derived momentum.
- `NZDJPY.DWX` - matrix-verified FX cross suitable for D1 close-derived momentum.
- `NZDUSD.DWX` - matrix-verified major FX pair suitable for D1 close-derived momentum.
- `SP500.DWX` - matrix-verified S&P 500 custom symbol, backtest-only per DWX discipline.
- `UK100.DWX` - matrix-verified index CFD suitable for D1 close-derived momentum.
- `USDCAD.DWX` - matrix-verified major FX pair suitable for D1 close-derived momentum.
- `USDCHF.DWX` - matrix-verified major FX pair suitable for D1 close-derived momentum.
- `USDJPY.DWX` - matrix-verified major FX pair suitable for D1 close-derived momentum.
- `WS30.DWX` - explicitly named by the card as an index trend instrument.
- `XAGUSD.DWX` - matrix-verified metal suitable for D1 close-derived momentum.
- `XAUUSD.DWX` - explicitly named by the card and matrix-verified.

**Explicitly NOT for:**
- `DAX.DWX` - not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - not canonical DWX S&P 500 symbols; use `SP500.DWX`.
- `XNGUSD.DWX`, `XTIUSD.DWX` - energy commodities, not metals, so they are outside this card's stated FX/metals/index basket.

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
| Trades / year / symbol | 18 |
| Expected trade frequency | Not specified in frontmatter; card implies intermittent daily stop-and-reverse signals. |
| Typical hold time | Not specified in frontmatter; D1 stop-and-reverse trend positions may hold days to weeks. |
| Expected drawdown profile | Not specified in frontmatter; catastrophic 2.0 * ATR(14) stop bounds single-trade loss. |
| Regime preference | Trend-following momentum. |
| Win rate target (qualitative) | Not specified in frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1b906e79-c619-5a61-90db-ee19ac95a19f
**Source type:** GitHub repository
**Pointer:** https://github.com/cinar/indicator/blob/master/strategy/trend/tsi_strategy.go and https://github.com/cinar/indicator/blob/master/trend/tsi.go
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10295_cinar-tsi.md`

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
| v1 | 2026-06-12 | Initial build from card | c0dc9020-268d-4421-9ee3-9dae6aa99ca1 |
