# QM5_11442_burke-frd-fgd-daily-pump-m5 — Strategy Spec

**EA ID:** QM5_11442
**Slug:** `burke-frd-fgd-daily-pump-m5`
**Source:** `04305b6c-b4ce-522b-87b5-71708b6b8327` (see `strategy-seeds/sources/04305b6c-b4ce-522b-87b5-71708b6b8327/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

A three-day daily pattern fades an exhausted "pump", executed on M5. The EA reads
prior CLOSED daily bars: Day 1 (D1 shift 2) is a pump that closes beyond the
reference day's range, and Day 2 (D1 shift 1) is a reversal bar that closes back
through Day 1's close. The FRD (Fakeout Reversal Day) configures a SHORT; the FGD
(Fakeout Gap Day, mirror) configures a LONG. On the trade day, inside the London
(07:00-12:00 UTC) or NY (13:00-17:00 UTC) session, the first M5 bar that closes
back across the M5 EMA(20) is the entry: close below EMA for the short, close above
EMA for the long. Exactly one entry fires per broker day per symbol. Stop is a
fixed pip distance (default 20, capped at 25); target is a fixed pip distance
(default 50, Burke's stated objective). A time stop closes any open position once
both session windows have ended for the day.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 20 | 13-34 | M5 EMA period used as the execution trigger |
| `strategy_session_london` | true | true/false | Allow London-session entries |
| `strategy_session_ny` | true | true/false | Allow NY-session entries |
| `strategy_london_start_utc` | 7 | 0-23 | London window start hour (UTC) |
| `strategy_london_end_utc` | 12 | 0-23 | London window end hour (UTC, exclusive) |
| `strategy_ny_start_utc` | 13 | 0-23 | NY window start hour (UTC) |
| `strategy_ny_end_utc` | 17 | 0-23 | NY window end hour (UTC, exclusive) |
| `strategy_tp_pips` | 50.0 | 30-75 | Take-profit distance in pips |
| `strategy_sl_pips` | 20.0 | 15-25 | Stop-loss distance in pips |
| `strategy_sl_cap_pips` | 25.0 | 0-50 | Hard P2 cap on the stop distance (pips) |
| `strategy_spread_pct_of_stop` | 15.0 | 0-100 | Skip if spread exceeds this % of the stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep-liquidity major; clean London/NY session structure for the fade.
- `GBPUSD.DWX` — high-range major; pump/fade days well represented in London.
- `USDJPY.DWX` — major with strong NY-session participation; JPY pip-scaling handled by QM_StopRules.
- `AUDUSD.DWX` — liquid commodity major; mean-reverting after daily excess.
- `USDCAD.DWX` — liquid commodity major; NY-session driven, complements the basket.

**Explicitly NOT for:**
- Index/metal `.DWX` symbols (NDX, WS30, XAUUSD, etc.) — the card defines the
  pattern and the 50-pip target on FX pip-scaling; index point-scaling would
  mis-size the fixed-pip stop/target.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `PERIOD_D1` (FRD/FGD pattern detection on prior closed daily bars) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~45` |
| Typical hold time | `intraday — minutes to hours, closed by session-end time stop` |
| Expected drawdown profile | `bounded per-trade (fixed 20-25 pip stop); session-scoped exposure` |
| Regime preference | `mean-revert / pump-and-fade after daily excess` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `04305b6c-b4ce-522b-87b5-71708b6b8327`
**Source type:** `book`
**Pointer:** `Stacey Burke, "The Stacey Burke Trading Playbook" (self-published, 2022); strategy-seeds/sources/04305b6c-b4ce-522b-87b5-71708b6b8327/`
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11442_burke-frd-fgd-daily-pump-m5.md` (R1 CONDITIONAL — named self-published author).

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

> When this EA cycles back to Q01 from a Q02 zero-trade event, add a row:
> `| v2 | YYYY-MM-DD | Q02 all-symbol zero-trades; widened entry filter X | <commit> |`
