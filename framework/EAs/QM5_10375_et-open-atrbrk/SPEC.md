# QM5_10375_et-open-atrbrk - Strategy Spec

**EA ID:** QM5_10375
**Slug:** et-open-atrbrk
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA trades M5 session-open breakouts. On the first completed M5 bar of the mapped primary session, it reads the bar open and daily ATR(20) from completed D1 bars, then places a buy stop at session open plus 0.30 ATR and a sell stop at session open minus 0.30 ATR. The filled side uses the opposite ATR band as the stop and a 0.60 ATR profit target, while the unfilled opposite stop is cancelled after one side fills or when the session reaches the final-order window. Any open position is closed at the mapped session close, with Friday close enforced by the framework.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_trade_tf` | `PERIOD_M5` | MT5 timeframe enum | Base timeframe used for the session-open bar. |
| `strategy_atr_period` | `20` | `1+` | Daily ATR lookback from completed D1 bars. |
| `strategy_entry_atr_mult` | `0.30` | `>0` | ATR distance from session open for stop entries and protective stop bands. |
| `strategy_target_atr_mult` | `0.60` | `>0` | ATR distance from entry to profit target. |
| `strategy_final_order_minutes` | `30` | `0+` | Minutes before session close when unfilled orders are cancelled and new orders are blocked. |
| `strategy_us_session_start_hhmm` | `1530` | `0000-2359` | Broker-time session start for SP500.DWX, NDX.DWX, and WS30.DWX. |
| `strategy_us_session_end_hhmm` | `2200` | `0000-2359` | Broker-time session close for SP500.DWX, NDX.DWX, and WS30.DWX. |
| `strategy_dax_session_start_hhmm` | `900` | `0000-2359` | Broker-time session start for GDAXI.DWX. |
| `strategy_dax_session_end_hhmm` | `1730` | `0000-2359` | Broker-time session close for GDAXI.DWX. |
| `strategy_gold_session_start_hhmm` | `800` | `0000-2359` | Broker-time primary-session start for XAUUSD.DWX. |
| `strategy_gold_session_end_hhmm` | `2100` | `0000-2359` | Broker-time primary-session close for XAUUSD.DWX. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - card-listed S&P 500 CFD/custom-symbol target for session-open ATR breakout testing.
- `NDX.DWX` - card-listed Nasdaq 100 index target for liquid US index exposure.
- `WS30.DWX` - card-listed Dow 30 index target for liquid US index exposure.
- `GDAXI.DWX` - canonical DWX DAX symbol replacing card text `GER40.DWX`, which is not in the DWX matrix.
- `XAUUSD.DWX` - card-listed gold target with liquid primary-session behaviour.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is the verified DWX equivalent.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P variants; `SP500.DWX` is the canonical custom-symbol target.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `D1 ATR(20)` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | `Intraday, from session-open breakout to target, stop, final-order cleanup, or session close` |
| Expected drawdown profile | `Opening whipsaw and session spread/slippage sensitivity` |
| Regime preference | `Volatility-expansion breakout` |
| Win rate target (qualitative) | `Medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/ts-code-using-a-date-of-next-bara-command-with-two-data-sources.90531/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10375_et-open-atrbrk.md`

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
| v1 | 2026-05-25 | Initial build from card | a32d3a60-6647-42ea-8b11-a27bc413fa8e |
