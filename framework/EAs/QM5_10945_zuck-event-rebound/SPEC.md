# QM5_10945_zuck-event-rebound - Strategy Spec

**EA ID:** QM5_10945
**Slug:** `zuck-event-rebound`
**Source:** `21ef3dfd-fac6-5d5d-b9a0-5ba447992f94` (see `strategy-seeds/sources/21ef3dfd-fac6-5d5d-b9a0-5ba447992f94/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades scheduled high-impact macro event rebounds on M5. Before the event, it measures the most recent 45-minute close-to-close move; if price has fallen by at least 0.35 x ATR(14,M5), it buys at market 10 minutes before the event. The initial stop is 1.2 x ATR(14,M5), there is no take profit, and the position is closed by time stop 15 minutes after the event. A symmetric short variant exists as an input but is disabled by default because the card states it is P3-only.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_pre_event_minutes` | 45 | 30-60 | Minutes of pre-event price movement to measure. |
| `strategy_entry_minutes_before` | 10 | 5-15 | Minutes before the scheduled event when the entry decision is made. |
| `strategy_exit_minutes_after` | 15 | 5-30 | Minutes after the scheduled event when the time-stop closes the trade. |
| `strategy_atr_trigger_mult` | 0.35 | 0.25-0.50 | ATR multiple required for the adverse pre-event move. |
| `strategy_atr_stop_mult` | 1.2 | 0.8-1.6 | ATR multiple used for the emergency stop distance. |
| `strategy_atr_period` | 14 | fixed by card | ATR period on M5. |
| `strategy_spread_atr_frac` | 0.20 | fixed by card | Maximum spread as a fraction of ATR(14,M5). |
| `strategy_allow_short` | false | false/true | Enables the optional symmetric short variant reserved for P3. |
| `strategy_event_lookahead_min` | 60 | operational bound | Maximum forward event scan window from the current M5 bar. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` — card-listed liquid macro-sensitive gold instrument.
- `XTIUSD.DWX` — canonical DWX crude-oil instrument used for the card's `OIL.DWX` exposure.
- `EURUSD.DWX` — card-listed major FX pair affected by macro releases.
- `USDJPY.DWX` — card-listed major FX pair affected by macro releases.
- `SP500.DWX` — card-listed S&P 500 custom symbol; backtest-only per DWX discipline.

**Explicitly NOT for:**
- `OIL.DWX` — not present in `dwx_symbol_matrix.csv`; ported to `XTIUSD.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` — not canonical DWX S&P 500 names.

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
| Trades / year / symbol | 36 |
| Typical hold time | About 25 minutes from entry to time-stop |
| Expected drawdown profile | Event-risk drawdowns bounded by ATR emergency stops |
| Regime preference | news-driven short-term mean reversion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `21ef3dfd-fac6-5d5d-b9a0-5ba447992f94`
**Source type:** book
**Pointer:** Gregory Zuckerman, "The Man Who Solved the Market: How Jim Simons Launched the Quant Revolution", Portfolio/Penguin, 2019, ISBN 9780735217980.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10945_zuck-event-rebound.md`

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
| v1 | 2026-06-18 | Initial build from card | 89137230-2cd0-46cf-bb16-21bc443f6995 |
