# QM5_10132_tv-mtf-body-bos - Strategy Spec

**EA ID:** QM5_10132
**Slug:** tv-mtf-body-bos
**Source:** 30591366-874b-5bee-b47c-da2fca20b728 (TradingView public script citation in approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA trades a closed-bar body breakout with a break-of-structure filter. A long signal requires the last closed candle to close above the prior candle body high, above the highest high of the prior 20 bars, and with the 4x higher-timeframe close above its SMA(50). A short signal is the symmetric close below prior body low, below the lowest low of the prior 20 bars, and with the 4x higher-timeframe close below its SMA(50). Positions close at the 2R target, stop loss, framework Friday close, or when price closes back through the prior candle body in the opposite direction.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_structure_lookback` | 20 | `>=1` | Prior-bar high/low lookback for BOS confirmation. |
| `strategy_atr_period` | 14 | `>=1` | ATR period for stop placement. |
| `strategy_htf_sma_period` | 50 | `>=1` | SMA period on the 4x higher timeframe. |
| `strategy_atr_stop_mult` | 1.5 | `>0` | ATR distance used for the entry-relative stop candidate. |
| `strategy_signal_atr_buffer` | 0.25 | `>=0` | ATR buffer beyond the signal candle high/low. |
| `strategy_take_profit_rr` | 2.0 | `>0` | Fixed reward/risk target. |
| `strategy_max_spread_stop_fraction` | 0.10 | `>=0` | Reject entry if spread exceeds this fraction of stop distance. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-approved FX target with liquid M15 OHLC structure.
- `GBPUSD.DWX` - card-approved FX target with liquid M15 OHLC structure.
- `XAUUSD.DWX` - card-approved gold CFD target with body/BOS portability.
- `NDX.DWX` - card-approved index CFD target with body/BOS portability.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no approved DWX data target.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | 4x chart timeframe: `M15 -> H1`, `H1 -> H4` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | Intraday to multi-session, depending on 2R or body-reversal close |
| Expected drawdown profile | Breakout losses cluster in sideways regimes; fixed 1R stop per entry |
| Regime preference | Breakout / volatility expansion with higher-timeframe trend alignment |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 30591366-874b-5bee-b47c-da2fca20b728
**Source type:** TradingView public script page
**Pointer:** https://www.tradingview.com/script/OcVKeqc2-Body-Close-Outside-Prior-Body-BOS-Filtered-MTF-by-JK/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10132_tv-mtf-body-bos.md`

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
| v1 | 2026-06-09 | Initial build from card | 4b181377-64ea-4515-bbb1-097bbe536a19 |
