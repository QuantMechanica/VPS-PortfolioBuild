# QM5_10372_et-1005-bracket — Strategy Spec

**EA ID:** QM5_10372
**Slug:** et-1005-bracket
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

The EA records the session high and low from the configured regular-session open until the configured 10:05 ET-equivalent bracket time. After the bracket is ready, it submits a buy stop one tick above the range high and a sell stop one tick below the range low, with the protective stop on the opposite side of the range. If a position is open, the opposite pending order is cancelled; the position exits at the configured 16:00 ET-equivalent time or when price breaks the opposite side of the bracket. The range filter skips unusually wide brackets using ATR(14) scaled by the number of M5 bars in the opening range, and the EA allows at most one long and one short entry per trading day.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_session_open_hour` | 16 | 0-23 | Broker-time hour corresponding to regular-session open. |
| `strategy_session_open_min` | 30 | 0-59 | Broker-time minute corresponding to regular-session open. |
| `strategy_bracket_hour` | 17 | 0-23 | Broker-time hour when the opening bracket is finalized. |
| `strategy_bracket_min` | 5 | 0-59 | Broker-time minute when the opening bracket is finalized. |
| `strategy_exit_hour` | 22 | 0-23 | Broker-time hour for the end-of-day time exit. |
| `strategy_exit_min` | 0 | 0-59 | Broker-time minute for the end-of-day time exit. |
| `strategy_entry_offset_ticks` | 1 | 0-10 | Ticks added beyond the bracket high or low for stop entry placement. |
| `strategy_stop_buffer_ticks` | 1 | 0-10 | Ticks added beyond the opposite bracket side for the protective stop. |
| `strategy_atr_period` | 14 | 2-100 | ATR period used by the maximum range-width filter. |
| `strategy_max_range_atr_mult` | 1.5 | 0.5-5.0 | Maximum bracket width as a multiple of ATR(14). |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — S&P 500 index port named in the card, backtest-only per DWX discipline.
- `NDX.DWX` — Nasdaq 100 live-tradable index CFD from the card basket.
- `WS30.DWX` — Dow 30 live-tradable index CFD from the card basket.
- `GDAXI.DWX` — canonical DAX Custom Symbol available in the matrix; used for the card's `GER40.DWX` basket member.

**Explicitly NOT for:**
- `GER40.DWX` — card-stated alias is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX equivalent.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` — unavailable S&P 500 variants; `SP500.DWX` is the only approved Custom Symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | Intraday, from bracket fill until opposite break or 16:00 ET-equivalent time exit |
| Expected drawdown profile | Whipsaw-sensitive opening-range breakout with fixed daily entry caps |
| Regime preference | Breakout / volatility-expansion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/another-very-simple-trading-strategy.12788/
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10372_et-1005-bracket.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-25 | Initial build from card | 87c62a88-f8d3-49f1-9478-cb2105712dc3 |
| v2 | 2026-06-17 | Rebuild in place from card | 80d22bf7-abe8-44d7-bf4b-b5cb7f921a54 |
