# QM5_10233_tv-macd-rsi-day - Strategy Spec

**EA ID:** QM5_10233
**Slug:** `tv-macd-rsi-day`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades a New York morning day-trading momentum setup on M5 bars. A long entry requires EMA9 above EMA21, the last closed M5 close above EMA9, M15 EMA9 above M15 EMA21, MACD main line above signal line, RSI between 40 and 70, tick volume above 1.2 times its 20-bar SMA, and ATR above the configured movement floor. A short entry mirrors those conditions. Positions use a 2.0 ATR initial stop, a 1.5 ATR trailing stop, close by 16:00 New York, and may close earlier on the opposite signal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_tf` | `PERIOD_M5` | MT5 timeframe enum | Execution timeframe from the card. |
| `strategy_confirm_tf` | `PERIOD_M15` | MT5 timeframe enum | Higher-timeframe trend confirmation. |
| `strategy_ema_fast` | `9` | `1+` | Fast EMA period. |
| `strategy_ema_slow` | `21` | `> strategy_ema_fast` | Slow EMA period. |
| `strategy_macd_fast` | `12` | `1+` | MACD fast EMA period. |
| `strategy_macd_slow` | `26` | `> strategy_macd_fast` | MACD slow EMA period. |
| `strategy_macd_signal` | `9` | `1+` | MACD signal period. |
| `strategy_rsi_period` | `14` | `1+` | RSI period. |
| `strategy_long_rsi_min` | `40.0` | `0-100` | Lower RSI bound for long entries. |
| `strategy_long_rsi_max` | `70.0` | `0-100` | Upper RSI bound for long entries. |
| `strategy_short_rsi_min` | `30.0` | `0-100` | Lower RSI bound for short entries. |
| `strategy_short_rsi_max` | `60.0` | `0-100` | Upper RSI bound for short entries. |
| `strategy_volume_sma_period` | `20` | `1+` | Tick-volume SMA period. |
| `strategy_volume_mult` | `1.2` | `>0` | Required multiple over the tick-volume SMA. |
| `strategy_atr_period` | `14` | `1+` | ATR period for movement, stop, and trail. |
| `strategy_initial_atr_mult` | `2.0` | `>0` | Initial stop distance in ATR. |
| `strategy_trail_atr_mult` | `1.5` | `>0` | ATR trailing-stop multiple. |
| `strategy_min_atr_points` | `1` | `0+` | Minimum ATR movement floor in symbol points. |
| `strategy_entry_start_hhmm_ny` | `930` | `0000-2359` | New York entry-session start. |
| `strategy_entry_end_hhmm_ny` | `1130` | `0000-2359` | New York entry-session end. |
| `strategy_eod_flat_hhmm_ny` | `1600` | `0000-2359` | New York forced-flat time. |
| `strategy_max_spread_points` | `0` | `0+` | Optional entry spread cap; `0` disables the cap. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 index proxy listed by the card as a best DWX port.
- `GDAXI.DWX` - DAX index matrix symbol used in place of the card's `GER40.DWX` wording.
- `WS30.DWX` - Dow 30 index proxy listed by the card as a best DWX port.
- `XAUUSD.DWX` - Gold CFD listed by the card as a best DWX port.
- `SP500.DWX` - S&P 500 custom symbol listed by the card for analog tests; backtest-only per company discipline.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is the available DAX port.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P variants; use `SP500.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `M15` EMA9/EMA21 trend confirmation |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default framework gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | Intraday; flat by 16:00 New York |
| Expected drawdown profile | Momentum day-trade drawdowns bounded by ATR stop and no overnight exposure |
| Regime preference | Momentum-continuation during active New York morning liquidity |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script page
**Pointer:** `https://www.tradingview.com/script/2Q5tFJUc-MACD-RSI-EMA-BB-ATR-Day-Trading-Strategy/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10233_tv-macd-rsi-day.md`

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
| v1 | 2026-06-09 | Initial build from card | 36ec9d20-4e0f-4b64-a36e-3ef576528650 |
