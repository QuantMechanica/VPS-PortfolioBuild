# QM5_10427_et-3bar-xma - Strategy Spec

**EA ID:** QM5_10427
**Slug:** et-3bar-xma
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe (see Elite Trader source pointer in approved card)
**Author of this spec:** Codex
**Last revised:** 2026-05-27

---

## 1. Strategy Logic

The EA watches completed M15 bars for three consecutive same-direction candles inside a compact range. Long setups require the last completed close above the 200-period exponential average, three bullish completed bars, the last close not exactly on the high, a three-bar range below the ATR cap, and a prior-bar body/range ratio above the threshold; the EA places a buy stop at the three-bar high. Short setups mirror the long side below the 200-period exponential average and place a sell stop at the three-bar low. Stops use the greater of the setup range and 0.75 * ATR(20), targets use 0.5 * setup range, pending orders expire at the configured window close, and open positions are closed at session close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_xma_period | 200 | 1+ | Period for the XAverage trend filter, implemented as EMA(close). |
| strategy_atr_period | 20 | 1+ | ATR period for range cap and minimum stop floor. |
| strategy_max_range_atr_mult | 0.75 | >0 | Maximum allowed three-bar range as a multiple of ATR. |
| strategy_min_stop_atr_mult | 0.75 | >0 | Minimum stop distance as a multiple of ATR. |
| strategy_body_range_min | 0.65 | >0 | Required prior-bar body divided by prior-bar range. |
| strategy_target_range_mult | 0.50 | >0 | Profit target distance as a multiple of setup range. |
| strategy_entry_buffer_points | 0 | 0+ | Optional stop-entry buffer in symbol points. |
| strategy_window1_start_hhmm | 0 | 0000-2359 | First allowed entry window start in broker HHMM. |
| strategy_window1_end_hhmm | 2359 | 0000-2359 | First allowed entry window end in broker HHMM. |
| strategy_window2_start_hhmm | -1 | -1 or 0000-2359 | Second allowed entry window start; -1 disables it. |
| strategy_window2_end_hhmm | -1 | -1 or 0000-2359 | Second allowed entry window end; -1 disables it. |
| strategy_window3_start_hhmm | -1 | -1 or 0000-2359 | Third allowed entry window start; -1 disables it. |
| strategy_window3_end_hhmm | -1 | -1 or 0000-2359 | Third allowed entry window end; -1 disables it. |
| strategy_session_close_hhmm | 2359 | 0000-2359 | Broker HHMM at or after which open positions close. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - Card-listed S&P 500 exposure; backtest-only custom symbol is available in the DWX matrix.
- NDX.DWX - Card-listed Nasdaq 100 exposure and available in the DWX matrix.
- WS30.DWX - Card-listed Dow 30 exposure and available in the DWX matrix.
- GDAXI.DWX - DAX exposure mapped from card-listed GER40.DWX because GDAXI.DWX is the DWX matrix symbol.
- XAUUSD.DWX - Card-listed gold exposure and available in the DWX matrix.

**Explicitly NOT for:**
- GER40.DWX - Card-listed name is not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is registered instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 160 |
| Typical hold time | Intraday flat-to-flat within the configured session window |
| Expected drawdown profile | Asymmetric intraday breakout profile with 0.5 setup-range target versus one setup-range stop floor |
| Regime preference | Intraday breakout after range compression with trend filter |
| Win rate target (qualitative) | High enough to compensate for half-range target versus full-range stop |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/working-system-needs-improvement.14001/page-4
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10427_et-3bar-xma.md`

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
| v1 | 2026-05-27 | Initial build from card | 23038f17-4192-43cc-963b-320da90e8062 |
