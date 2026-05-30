# QM5_10405_et-or-riskbrk - Strategy Spec

**EA ID:** QM5_10405
**Slug:** `et-or-riskbrk`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA builds an opening range from the first three M5 bars of the mapped trading session. Once the range is complete, it places a buy stop one tick above the range high and a sell stop one tick below the range low, with the stop on the opposite side of the range plus one tick. It skips ranges that are too small relative to spread or where the stop distance exceeds 2.5 times ATR(20), cancels the unfilled bracket side after a fill, and closes any open position at session end.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_opening_range_bars` | 3 | >=1 | Number of first-session M5 bars used to set the opening range. |
| `strategy_breakout_ticks` | 1 | >=1 | Tick offset beyond the opening range for buy/sell stop entries. |
| `strategy_stop_buffer_ticks` | 1 | >=0 | Tick buffer beyond the opposite range side for protective stops. |
| `strategy_target_rr` | 1.0 | >0 | Fixed profit target measured as R multiple of entry-to-stop risk. |
| `strategy_atr_period` | 20 | >=1 | ATR period used for the maximum range-stop distance filter. |
| `strategy_max_range_atr_mult` | 2.5 | >0 | Maximum entry-to-stop distance as ATR multiple. |
| `strategy_us_session_start_hhmm` | 1530 | 0000-2359 | Broker-time start for SP500, NDX, and WS30 sessions. |
| `strategy_us_session_end_hhmm` | 2200 | 0000-2400 | Broker-time end for SP500, NDX, and WS30 sessions. |
| `strategy_dax_session_start_hhmm` | 900 | 0000-2359 | Broker-time start for the DAX leg. |
| `strategy_dax_session_end_hhmm` | 1730 | 0000-2400 | Broker-time end for the DAX leg. |
| `strategy_gold_session_start_hhmm` | 800 | 0000-2359 | Broker-time start for XAUUSD. |
| `strategy_gold_session_end_hhmm` | 2100 | 0000-2400 | Broker-time end for XAUUSD. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 index proxy named by the card; backtest-only custom symbol.
- `NDX.DWX` - Nasdaq 100 index leg from the card's portable US basket.
- `WS30.DWX` - Dow 30 index leg from the card's portable US basket.
- `GDAXI.DWX` - available DAX custom symbol used for the card's `GER40.DWX` leg.
- `XAUUSD.DWX` - metal leg named by the card's target symbol list.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P aliases; `SP500.DWX` is the canonical custom symbol.

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
| Trades / year / symbol | `120` |
| Typical hold time | intraday, from post-opening-range breakout to session close or SL/TP |
| Expected drawdown profile | fixed-risk, single-position intraday breakout drawdowns from false range breaks |
| Regime preference | volatility-expansion / breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `https://www.elitetrader.com/et/threads/easylanguage-script-for-position-sizing.361086/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10405_et-or-riskbrk.md`

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
| v1 | 2026-05-25 | Initial build from card | f52ae2b6-119e-4560-a49f-9836e518d15b |
