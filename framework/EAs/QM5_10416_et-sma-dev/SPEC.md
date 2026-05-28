# QM5_10416_et-sma-dev - Strategy Spec

**EA ID:** QM5_10416
**Slug:** et-sma-dev
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe (see `artifacts/cards_approved/QM5_10416_et-sma-dev.md`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

This EA trades M5 bars during the 08:30-11:30 session window. It calculates a 10-period SMA of close and enters long when the last closed bar closes at or above the SMA with absolute close-to-SMA deviation between 0.20 ATR(20) and 0.25 ATR(20). It enters short when the last closed bar closes at or below the SMA inside the same deviation band. Each trade uses a fixed 0.75 ATR(20) stop, a 1.0 ATR(20) target, and closes any still-open position 30 seconds before the session end.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_M5` | M1, M5, M15 in P3 | Signal timeframe for SMA, ATR, and closed-bar entries. |
| `strategy_sma_period` | 10 | 10, 20, 50 in P3 | SMA period applied to close. |
| `strategy_atr_period` | 20 | fixed baseline | ATR period used to normalize entry band, stop, and target. |
| `strategy_dev_atr_mult` | 0.20 | 0.10-0.35 | Lower bound of close-to-SMA deviation as ATR multiple. |
| `strategy_tolerance_atr` | 0.05 | 0.03-0.10 | Extra ATR band width above the deviation threshold. |
| `strategy_tp_atr_mult` | 1.00 | 0.75-1.50 | Profit target distance as ATR multiple. |
| `strategy_sl_atr_mult` | 0.75 | 0.75-1.00 | Stop distance as ATR multiple. |
| `strategy_session_start_h` | 8 | 0-23 | Session start hour in broker/exchange-local time. |
| `strategy_session_start_m` | 30 | 0-59 | Session start minute. |
| `strategy_session_end_h` | 11 | 0-23 | Session end hour in broker/exchange-local time. |
| `strategy_session_end_m` | 30 | 0-59 | Session end minute. |
| `strategy_exit_buffer_sec` | 30 | 0-3600 | Seconds before session end to close open positions. |
| `strategy_max_spread_sl_frac` | 0.20 | 0.00-1.00 | Reject new entries when spread exceeds this fraction of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol specified by the card for the US large-cap basket.
- `NDX.DWX` - Nasdaq 100 index exposure specified by the card.
- `WS30.DWX` - Dow 30 index exposure specified by the card.
- `GDAXI.DWX` - Verified DWX DAX symbol used as the matrix-valid port for card-stated `GER40.DWX`.
- `XAUUSD.DWX` - Gold symbol specified by the card.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P 500 variants; use `SP500.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | intraday, up to the 08:30-11:30 session window |
| Expected drawdown profile | clustered entries around noisy SMA crossings; spread sensitivity should be watched |
| Regime preference | volatility-expansion / breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** Elite Trader page 3 posted NinjaScript strategy, https://www.elitetrader.com/et/threads/market-regime-trend-or-trading-range.384335/page-3
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10416_et-sma-dev.md`

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
| v1 | 2026-05-25 | Initial build from card | a9df1abb-36d2-4f30-a9e2-59d5d4a8965f |
