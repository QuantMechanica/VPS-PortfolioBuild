# QM5_11433_ibr-mean-reversion-d1 - Strategy Spec

**EA ID:** QM5_11433
**Slug:** `ibr-mean-reversion-d1`
**Source:** `16b3c87b-0cff-55ae-802d-2a7680ec6af8`
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

This EA trades daily Internal Bar Range mean reversion. IBR is calculated from the last closed D1 bar as `(Close[1] - Low[1]) / (High[1] - Low[1])`; a value below 0.20 triggers a long setup when the close is above SMA(200), and a value above 0.80 triggers a short setup when the close is below SMA(200). Entries are market orders on the next D1 bar. Stop loss is 1.5 x ATR(14), capped at 100 pips for P2, take profit is 2.0 x ATR(14), and positions also close if IBR normalizes into the 0.30 to 0.70 band.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ibr_long_threshold` | 0.20 | 0.0-1.0 | Long signal threshold for weak closes. |
| `strategy_ibr_short_threshold` | 0.80 | 0.0-1.0 | Short signal threshold for strong closes. |
| `strategy_sma_period` | 200 | 1+ | D1 SMA regime filter period. |
| `strategy_atr_period` | 14 | 1+ | D1 ATR period for stop and target distances. |
| `strategy_sl_atr_mult` | 1.5 | >0 | ATR multiple for the stop loss. |
| `strategy_tp_atr_mult` | 2.0 | >0 | ATR multiple for the take profit. |
| `strategy_sl_cap_pips` | 100 | 1+ | P2 maximum stop distance in pips. |
| `strategy_spread_cap_pips` | 25 | 1+ | Maximum spread in pips; zero modeled spread is allowed. |
| `strategy_exit_ibr_low` | 0.30 | 0.0-1.0 | Lower bound of the IBR normalization exit band. |
| `strategy_exit_ibr_high` | 0.70 | 0.0-1.0 | Upper bound of the IBR normalization exit band. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed D1 DWX FX major with native OHLC, SMA, and ATR support.
- `GBPUSD.DWX` - card-listed D1 DWX FX major with native OHLC, SMA, and ATR support.
- `USDJPY.DWX` - card-listed D1 DWX FX major with native OHLC, SMA, and ATR support.
- `AUDUSD.DWX` - card-listed D1 DWX FX major with native OHLC, SMA, and ATR support.
- `USDCAD.DWX` - card-listed D1 DWX FX major with native OHLC, SMA, and ATR support.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - the approved card scopes this strategy to D1 DWX FX majors.
- FX symbols not in `dwx_symbol_matrix.csv` - the framework cannot validate unavailable broker history.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework entry path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | Days; exits on ATR target, ATR stop, or next D1 IBR normalization |
| Expected drawdown profile | Exploratory D1 mean-reversion profile from R1 CONDITIONAL source |
| Regime preference | Mean reversion with SMA(200) trend regime filter |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `16b3c87b-0cff-55ae-802d-2a7680ec6af8`
**Source type:** book / local PDF citation record
**Pointer:** Joe Marwood (Decoding Markets), "Mean Reversion Trading Strategy Guide", local PDF in strategy archive
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11433_ibr-mean-reversion-d1.md`

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
| v1 | 2026-06-25 | Initial build from card | 22223b7e-8fdd-4c34-a14a-37988e20133b |
