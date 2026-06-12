# QM5_10279_whc-roc-ma - Strategy Spec

**EA ID:** QM5_10279
**Slug:** whc-roc-ma
**Source:** 1b906e79-c619-5a61-90db-ee19ac95a19f (see `strategy-seeds/sources/1b906e79-c619-5a61-90db-ee19ac95a19f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

This EA trades long-only daily momentum. It opens a long position when ROC(12) on the close is above zero and SMA(10) crosses above SMA(30) on the last closed D1 bar. It exits the position when ROC(12) falls below zero or SMA(10) crosses below SMA(30). The source has no explicit stop, so the V5 build uses a catastrophic stop at 2.0 times ATR(14).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_D1` | MT5 timeframe enum | Timeframe used for ROC, SMA, and ATR reads. |
| `strategy_roc_period` | `12` | `1+` | Momentum lookback used to derive ROC as `Momentum - 100`. |
| `strategy_fast_sma_period` | `10` | `1+` and below slow SMA | Fast SMA period for the crossover confirmation. |
| `strategy_slow_sma_period` | `30` | `1+` and above fast SMA | Slow SMA period for the crossover confirmation. |
| `strategy_entry_roc_level` | `0.0` | any decimal | Minimum ROC threshold for long entry. |
| `strategy_exit_roc_level` | `0.0` | any decimal | ROC threshold below which the EA exits. |
| `strategy_atr_period` | `14` | `1+` | ATR period used for the catastrophic stop. |
| `strategy_atr_sl_mult` | `2.0` | `> 0` | ATR multiple for the catastrophic stop. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - liquid US large-cap index exposure suitable for daily trend and momentum.
- `WS30.DWX` - liquid US large-cap index exposure suitable for daily trend and momentum.
- `SP500.DWX` - S&P 500 custom symbol matching the card's index target, backtest-only per DWX discipline.
- `XAUUSD.DWX` - trend-capable metal symbol listed by the card.
- `EURUSD.DWX` - major FX pair with daily OHLC coverage.
- `GBPUSD.DWX` - major FX pair with daily OHLC coverage.
- `USDJPY.DWX` - major FX pair with daily OHLC coverage.
- `AUDUSD.DWX` - major FX pair with daily OHLC coverage.
- `USDCAD.DWX` - major FX pair with daily OHLC coverage.
- `USDCHF.DWX` - major FX pair with daily OHLC coverage.
- `NZDUSD.DWX` - major FX pair with daily OHLC coverage.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - DWX tick data is not available.
- `SPX500.DWX`, `SPY.DWX`, and `ES.DWX` - unavailable S&P 500 variants; `SP500.DWX` is the canonical custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `8` |
| Typical hold time | days to weeks |
| Expected drawdown profile | Trend-following losses cluster during sideways markets and false crossovers. |
| Regime preference | trend / momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1b906e79-c619-5a61-90db-ee19ac95a19f
**Source type:** GitHub repository
**Pointer:** https://github.com/whchien/ai-trader/blob/main/ai_trader/backtesting/strategies/classic/roc.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10279_whc-roc-ma.md`

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
| v1 | 2026-06-12 | Initial build from card | c608396c-fab0-409b-9ff0-b88bb70f96ca |
