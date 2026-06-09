# QM5_10042_ff-notable-numbers — Strategy Spec

**EA ID:** QM5_10042
**Slug:** `ff-notable-numbers`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

Enters reversal positions at psychologically significant price levels ("notable numbers") on FX pairs. Each symbol has a hard-coded grid of notable levels derived from specific decimal endings (e.g., GBPUSD levels ending in ".00", USDJPY in ".444"). Before firing an entry, the EA checks that all of the last N complete daily bars are positioned entirely above (for a long) or below (for a short) the nearest notable level, confirming the level has unbroken structural significance. On the M15 chart, when a bar opens on the correct side of the level and its extreme (low for long, high for short) touches or pierces the level, the EA enters a counter-trend market order with fixed-percentage TP and SL. Positions that reach neither TP nor SL are closed at the end of the symbol-specific session window.

---

## 2. Parameters

No user-tunable strategy parameters. All symbol-specific values (lookback days, TP/SL percentages, session hours, notable-level grid) are hard-coded from the card specification in `InitSymbolParams()`.

| Symbol | Lookback | TP | SL | Session (broker) | Level grid | Offset |
|---|---|---|---|---|---|---|
| GBPUSD.DWX | 22 days | 0.4% | 0.4% | 00:00–08:00 | 0.0100 | 0.0000 |
| EURGBP.DWX | 13 days | 0.35% | 0.9% | 02:00–08:00 | 0.0100 | 0.0066 |
| AUDUSD.DWX | 42 days | 0.85% | 0.55% | 02:00–18:00 | 0.0100 | 0.0033 |
| USDJPY.DWX | 20 days | 0.25% | 0.25% | any | 1.0000 | 0.4440 |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` — Source defines ".00" round-number levels for GBP/USD with 22-day lookback
- `EURGBP.DWX` — Source defines ".66" levels for EUR/GBP with 13-day lookback
- `AUDUSD.DWX` — Source defines ".33" levels for AUD/USD with 42-day lookback
- `USDJPY.DWX` — Source defines ".444" integer-unit levels for USD/JPY with 20-day lookback

**Explicitly NOT for:**
- All other DWX symbols — no card-defined level endings or lookbacks for other pairs

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `PERIOD_D1` for N-bar positional filter (structural lookback) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~12 |
| Typical hold time | Minutes to a session (< 8 hours) |
| Expected drawdown profile | Sparse entries; session-capped losses |
| Regime preference | Mean-reversion at structural psychological levels |
| Win rate target (qualitative) | medium (source reports ~45 trades/year portfolio-wide) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** joyny, "Notable numbers strategy", ForexFactory 2022-10-03, https://www.forexfactory.com/thread/1182304-notable-numbers-strategy
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10042_ff-notable-numbers.md`

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
| v1 | 2026-06-10 | Initial build from card | 6747e076-28ab-49ca-98d9-05218284feb8 |
