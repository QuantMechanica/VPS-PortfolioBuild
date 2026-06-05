# QM5_10375_et-open-atrbrk - Strategy Spec

**EA ID:** QM5_10375
**Slug:** et-open-atrbrk
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA trades M5 session-open breakouts. On the first M5 bar of the mapped
primary session it stores the session open and reads daily ATR(20) from
completed D1 bars, then brackets the open with two symmetric pending stop
orders: a buy stop at `session_open + 0.30 * ATR` and a sell stop at
`session_open - 0.30 * ATR`. Whichever leg fills sets the trade direction; the
opposite unfilled leg is cancelled. The filled side uses the opposite ATR band
as its protective stop and a `0.60 * ATR` profit target from entry. Any open
position is closed at the mapped session close (time exit), with Friday close
enforced by the framework. One trade per symbol per session; no new orders in
the final 30 minutes of the session; the session is skipped when the band
distance is below four spreads.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | `20` | `10-30` | Daily ATR lookback from completed D1 bars. |
| `strategy_entry_atr_mult` | `0.30` | `0.2-0.5` | ATR distance from session open for stop entries / protective bands. |
| `strategy_target_atr_mult` | `0.60` | `0.4-1.0` | ATR distance from entry to profit target. |
| `strategy_final_order_minutes` | `30` | `0-120` | Minutes before session close when new orders are blocked and pending stops are cancelled. |
| `strategy_min_band_spreads` | `4.0` | `1-10` | Skip the session when band distance < N × current spread. |
| `strategy_us_session_start_hhmm` | `1630` | `0000-2359` | Broker-time session start for SP500.DWX, NDX.DWX, WS30.DWX. |
| `strategy_us_session_end_hhmm` | `2300` | `0000-2359` | Broker-time session close for SP500.DWX, NDX.DWX, WS30.DWX. |
| `strategy_dax_session_start_hhmm` | `1000` | `0000-2359` | Broker-time session start for GDAXI.DWX (P3-tunable). |
| `strategy_dax_session_end_hhmm` | `1830` | `0000-2359` | Broker-time session close for GDAXI.DWX (P3-tunable). |
| `strategy_gold_session_start_hhmm` | `800` | `0000-2359` | Broker-time active-window start for XAUUSD.DWX (P3-tunable). |
| `strategy_gold_session_end_hhmm` | `2100` | `0000-2359` | Broker-time active-window close for XAUUSD.DWX (P3-tunable). |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - card-listed S&P 500 custom symbol; clean liquid RTH opening range (backtest-only).
- `NDX.DWX` - card-listed Nasdaq 100; high-beta US index, strong opening-range breakouts.
- `WS30.DWX` - card-listed Dow 30; liquid US index, same NY cash session mapping.
- `GDAXI.DWX` - canonical DWX DAX symbol replacing card text `GER40.DWX` (not in the DWX matrix).
- `XAUUSD.DWX` - card-listed gold; volatility-driven intraday breakouts on its own window.

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
| Typical hold time | `Intraday, from session-open breakout to target, stop, or session close` |
| Expected drawdown profile | `Opening whipsaw and session spread/slippage sensitivity` |
| Regime preference | `Volatility-expansion breakout` |
| Win rate target (qualitative) | `Medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** Elite Trader thread (Jock / TrueStory / risktaker), 2007-03-26 - TS code placing a stop at session open plus 0.3x daily ATR.
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
| v1 | 2026-06-05 | Rebuild in place from card (DL-069) | a32d3a60-6647-42ea-8b11-a27bc413fa8e |
