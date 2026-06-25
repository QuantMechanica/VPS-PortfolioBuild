# QM5_11197_ft-inform-btc - Strategy Spec

**EA ID:** QM5_11197
**Slug:** ft-inform-btc
**Source:** 1580128f-e465-5454-bb97-a7572a6cfd6d (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA opens long positions on M5 closed bars when the traded symbol's EMA20 is above its EMA50 and the informative risk proxy `NDX.DWX` has its M15 close above its M15 SMA20. It exits when both conditions reverse: the traded symbol EMA20 is below EMA50 and `NDX.DWX` M15 close is below SMA20. The initial stop is ATR(14) times 2.0, and take-profit management follows the source ROI ladder: 5% immediately, 4% after 20 minutes, 3% after 30 minutes, and 1% after 60 minutes.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 20 | 10-30 | Fast EMA period on the traded M5 chart. |
| `strategy_ema_slow_period` | 50 | 40-80 | Slow EMA period on the traded M5 chart. |
| `strategy_informative_sma` | 20 | 10-40 | M15 SMA period for the `NDX.DWX` informative risk proxy. |
| `strategy_atr_period` | 14 | 14 baseline | ATR period used for the initial stop. |
| `strategy_atr_stop_mult` | 2.0 | 1.5-2.5 | ATR multiplier for the initial stop. |
| `strategy_spread_pct_of_stop` | 8.0 | 8.0 baseline | Blocks only when live spread exceeds this percent of planned stop distance. |
| `strategy_informative_symbol` | NDX.DWX | NDX.DWX baseline | Fixed DWX proxy for the source BTC/USDT informative leg. |
| `strategy_informative_tf` | PERIOD_M15 | PERIOD_M15 baseline | Timeframe for the informative proxy close and SMA reads. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 names this as a primary portable DWX symbol.
- `GBPUSD.DWX` - Card R3 names this as a primary portable DWX symbol.
- `XAUUSD.DWX` - Card R3 names this as a primary portable DWX symbol.
- `NDX.DWX` - Card R3 names this as a primary portable DWX symbol and the approved informative proxy.

**Explicitly NOT for:**
- Non-DWX BTC or crypto symbols - Not present in `framework/registry/dwx_symbol_matrix.csv`.
- Symbols outside the registered R3 basket - Not registered for this EA's magic slots.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | `NDX.DWX` M15 close and SMA20 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 140 |
| Typical hold time | Minutes to intraday; ROI ladder decays after 20, 30, and 60 minutes |
| Expected drawdown profile | Medium risk class with ATR-bounded stops |
| Regime preference | Trend with cross-market risk-on confirmation |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Source type:** GitHub strategy repository
**Pointer:** https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/InformativeSample.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11197_ft-inform-btc.md`

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
| v1 | 2026-06-25 | Initial build from card | 38d43134-6dfa-4e90-b661-01b0d2eee836 |
