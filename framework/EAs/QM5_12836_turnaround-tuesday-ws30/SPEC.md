# QM5_12836_turnaround-tuesday-ws30 — Strategy Spec

**EA ID:** QM5_12836
**Slug:** `turnaround-tuesday-ws30`
**Source:** `balke-turnaround-tuesday-20260630` (see `docs/research/YOUTUBE_STRATEGY_SYNTHESIS_2026-06-30.md`)
**Author of this spec:** Claude
**Last revised:** 2026-07-02

---

## 1. Strategy Logic

Long-only weekly mean-reversion on WS30 (Dow Jones 30). The strategy exploits the Turnaround Tuesday calendar anomaly: when Monday's session is bearish relative to Friday's close (or bearish relative to its own open), institutional dip-buyers tend to reverse the selling on Tuesday. Entry is gated on a 200-day SMA bull-regime filter (price must be above the 200-day SMA) and an optional volume filter (Monday tick-volume must exceed a 25-day SMA). On a qualifying Tuesday, the EA enters long at market on the first H1 bar (immediate mode) or after the H1 bar whose high breaks above Monday's high (breakout mode). The trade is hard-exited at exit_hour on Tuesday (default 23:00 broker, 16:00 ET US cash close under the DXZ ET+7 convention) or via SL/TP. A max_hold_days safety guard closes any residual position by end of Wednesday.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `regime_sma_period` | 200 | 100–200 | D1 SMA period for bull-regime filter (sweep 100/150/200) |
| `weak_monday_mode` | WMM_BELOW_FRIDAY | enum | WMM_BELOW_FRIDAY=Monday close < Friday close (QS canonical); WMM_BAR_BEARISH=Monday close < Monday open |
| `use_volume_filter` | true | bool | Block entry if Monday D1 tick-volume does not exceed SMA(vol,N) |
| `volume_sma_period` | 25 | 10–50 | Lookback for Monday volume SMA (D1 bars) |
| `entry_mode` | EM_IMMEDIATE | enum | EM_IMMEDIATE=first eligible Tuesday H1 bar; EM_BREAKOUT=wait for last H1 bar to break Monday's high |
| `sl_mode` | SL_MONDAY_LOW | enum | SL_MONDAY_LOW=stop at Monday's D1 low; SL_FIXED_PCT=entry minus sl_fixed_pct% |
| `sl_fixed_pct` | 1.0 | 0.5–3.0 | SL distance from entry in % (used when sl_mode=SL_FIXED_PCT) |
| `tp_mode` | TP_FIXED_PCT | enum | TP_FIXED_PCT=entry plus tp_fixed_pct%; TP_MONDAY_HIGH=Monday D1 high; TP_NONE=time-exit only |
| `tp_fixed_pct` | 1.75 | 1.0–3.0 | TP distance from entry in % (used when tp_mode=TP_FIXED_PCT); sweep 1.5/1.75/2.0 |
| `exit_dow` | 2 | 0–6 | Day-of-week for hard time-exit (2=Tuesday, matching MqlDateTime.day_of_week) |
| `exit_hour` | 23 | 14–23 | Broker hour for hard time-exit (WS30 US cash close 16:00 ET = 23:00 broker under DXZ ET+7) |
| `max_hold_days` | 2 | 1–5 | Safety: force-close position after this many calendar days |

---

## 3. Symbol Universe

**Designed for (all registered in magic_numbers.csv — P2 will run Davey multi-market baseline across all four):**
- `WS30.DWX` — Dow Jones 30 index CFD; canonical Turnaround Tuesday instrument (US large-cap, ~$4.4 RT commission, live-tradable on DXZ); slot 0
- `SP500.DWX` — S&P 500 custom symbol (backtest-only on DXZ); broadens the Davey #4 multi-market baseline check; slot 1
- `NDX.DWX` — Nasdaq 100 (live-tradable on DXZ); further generalisation test of the US equity-index calendar effect; slot 2
- `GDAXI.DWX` — DAX 40 (live-tradable); European index for out-of-sample generalisation; calendar effect expected weaker outside US; slot 3

**Explicitly NOT for:**
- Forex pairs — anomaly is equity-index specific; weekly-frequency commission destroys edge on FX
- `XAUUSD.DWX` — different behavioural regime; not the target asset class

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `PERIOD_D1` (regime SMA, Monday OHLCV, Friday close, volume SMA) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` for H1 entry; D1 data cached once per week |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~25 (low-freq; swing/low-freq Q04/Q08 track DL-070/076 applies) |
| Typical hold time | ~1 day (entry Tuesday morning, exit Tuesday cash close ~23:00 broker) |
| Expected drawdown profile | ~5% max DD target; low-freq single weekly long per week |
| Regime preference | mean-reversion / calendar anomaly / structural long bias |
| Win rate target (qualitative) | medium (time-limited exit means wins capped; losses bounded by Monday's low SL) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `balke-turnaround-tuesday-20260630`
**Source type:** video (YouTube synthesis)
**Pointer:** `docs/research/YOUTUBE_STRATEGY_SYNTHESIS_2026-06-30.md`, candidate A1 (Balke/Davey synthesis, Claude 2026-06-30)
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12836_turnaround-tuesday-ws30.md`

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
| v1 | 2026-07-01 | Initial build from card | ceae2d90-54a4-49b8-a09c-26c2a6b8f272 |
| v2 | 2026-07-02 | Correct DXZ ET+7 cash-close mapping and latch semantics | exit_hour=23; setup latch uses QM_CalendarPeriodKey; entry latch burns after successful send |
| v3 | 2026-07-02 | Q01 margin rework for Q02 baseline | backtest setfiles use SL_FIXED_PCT at 0.5%; news gate moved below management/exit |
