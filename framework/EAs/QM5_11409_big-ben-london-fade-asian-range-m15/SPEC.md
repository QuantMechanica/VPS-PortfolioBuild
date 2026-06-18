# QM5_11409_big-ben-london-fade-asian-range-m15 — Strategy Spec

**EA ID:** QM5_11409
**Slug:** `big-ben-london-fade-asian-range-m15`
**Source:** `b771d955-5033-500a-bb6b-98bd284b5b79` (see `strategy-seeds/sources/b771d955-5033-500a-bb6b-98bd284b5b79/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Big Ben "London fade" of the Asian-range false breakout, on M15. All session
windows are read from the bar timestamp in BROKER time (DXZ NY-close, GMT+2
winter / GMT+3 summer; the broker clock shifts with US DST itself, so the
broker-hour constants are constant year-round). During the Asian session
(01:00–09:00 broker) the EA builds a BODY-based range from prior CLOSED bars:
`asian_high = max(open,close)` and `asian_low = min(open,close)` over the Asian
bars. In the pre-London window (09:00–10:00 broker) it watches for a single
sweep EVENT: a bar whose Low pierces `asian_low` (false breakdown → fade LONG
bias) or whose High pierces `asian_high` (false breakout → fade SHORT bias). At
the London open (10:00 broker) the fade trigger is the first M15 bar that CLOSES
back through the swept boundary — `close > asian_low` for a LONG, `close <
asian_high` for a SHORT — and the EA enters at that bar. Stop loss is the
reversal-bar extreme (Low for long / High for short) capped at 40 pips; take
profit projects the Asian-range height from entry. Any open position is
flat-closed at the time stop (11:00 broker). No sweep → no trade. One position
per magic, one fade attempt per day.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_asian_start_hour` | 1 | 0-23 | Asian session start, broker hour (inclusive) |
| `strategy_asian_end_hour` | 9 | 0-23 | Asian session end, broker hour (exclusive) |
| `strategy_london_open_hour` | 10 | 0-23 | London open / fade-window start, broker hour |
| `strategy_time_stop_hour` | 11 | 0-23 | Force-close hour, broker (>= ⇒ time-stop exit) |
| `strategy_tp_range_mult` | 1.0 | 0.5-1.5 | TP = entry ± Asian-range × this multiple |
| `strategy_sl_cap_pips` | 40 | 10-80 | SL distance cap in pips (M15 bars are small) |
| `strategy_spread_pct_of_stop` | 25.0 | 5-50 | Skip only if spread > this % of stop distance (fail-open) |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` — GBP cross, most sensitive to the London open liquidity sweep (card-preferred)
- `GBPJPY.DWX` — high-volatility GBP cross, exaggerated London-open fades (card-preferred)
- `EURUSD.DWX` — deepest FX pair, clean Asian-range definition and London reversion
- `USDJPY.DWX` — Asian-session-active JPY pair with a well-formed overnight range

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — the edge is the FX London-open liquidity sweep; index cash sessions and gold do not share the Asian-range / London-fade microstructure.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~100` |
| Typical hold time | `minutes to ~1 hour (intraday, time-stopped at 11:00 broker)` |
| Expected drawdown profile | `frequent small intraday losses; bounded per-trade by the 40-pip SL cap` |
| Regime preference | `mean-revert (session false-breakout reversion)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b771d955-5033-500a-bb6b-98bd284b5b79`
**Source type:** `forum` (anonymous website team — TradingStrategyGuides.com)
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\450251566-Big-Ben-Breakout-Strategy-pdf.pdf`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11409_big-ben-london-fade-asian-range-m15.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor worktree |
