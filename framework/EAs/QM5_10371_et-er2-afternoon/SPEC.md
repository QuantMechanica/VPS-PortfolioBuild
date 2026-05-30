# QM5_10371_et-er2-afternoon - Strategy Spec

**EA ID:** QM5_10371
**Slug:** et-er2-afternoon
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA reads the regular-session open price and, at 13:00 Chicago-equivalent broker time, creates a two-sided breakout bracket. The long trigger is session open multiplied by 1.0033 and the short trigger is session open multiplied by 0.9967. If price has already crossed one trigger at bracket time, it enters that side at market; otherwise it places both stop orders. The opposite trigger is the protective stop, capped to 1.5 ATR(14) if that stop would be wider, and any open trade is closed at 15:00 Chicago-equivalent broker time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_us_session_open_hhmm` | 1530 | 0000-2359 | Broker-time regular-session open used for SP500, NDX, and WS30. |
| `strategy_eu_session_open_hhmm` | 900 | 0000-2359 | Broker-time regular-session open used for GDAXI. |
| `strategy_entry_hhmm_broker` | 2100 | 0000-2359 | Broker-time equivalent of 13:00 Chicago bracket arming time. |
| `strategy_exit_hhmm_broker` | 2300 | 0000-2359 | Broker-time equivalent of 15:00 Chicago time exit. |
| `strategy_trigger_pct` | 0.0033 | >0 | Distance from session open for long and short triggers. |
| `strategy_atr_period` | 14 | >0 | ATR period for the optional catastrophic stop cap. |
| `strategy_atr_cap_mult` | 1.5 | >=0 | Maximum stop distance as a multiple of ATR; 0 disables the cap. |
| `strategy_min_spread_multiple` | 4.0 | >=0 | Skip bracket if trigger distance is less than this multiple of spread. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol, valid for backtest-only US large-cap index exposure.
- `NDX.DWX` - Nasdaq 100 index CFD, live-tradable US large-cap growth exposure.
- `WS30.DWX` - Dow 30 index CFD, live-tradable US large-cap blue-chip exposure.
- `GDAXI.DWX` - DAX custom symbol available in the DWX matrix; used as the GER40/DAX equivalent.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - not canonical DWX S&P 500 symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M1 |
| Multi-timeframe refs | ATR(14) on M1 only |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 150 |
| Typical hold time | Intraday, from afternoon breakout until 15:00 Chicago-equivalent time or stop. |
| Expected drawdown profile | Simple daily index breakout with bounded session exposure and chop risk. |
| Regime preference | Breakout / afternoon trend attempt. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/simple-system-for-beginners.37520/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10371_et-er2-afternoon.md`

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
| v1 | 2026-05-25 | Initial build from card | 0be1fd60-9450-46f7-9d2e-583608bcad26 |
