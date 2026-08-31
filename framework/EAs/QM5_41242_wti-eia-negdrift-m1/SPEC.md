# QM5_41242_wti-eia-negdrift-m1 — Strategy Spec

**EA ID:** QM5_41242
**Slug:** `wti-eia-negdrift-m1`
**Source:** `ARMSTRONG-EIA-WTI-NEGDRIFT-M1-2026`
**Author of this spec:** Codex
**Last revised:** 2026-08-31

---

## 1. Strategy Logic

On an ordinary Wednesday, the EA observes the completed 10:30 New York WTI
M1 bar. If that bar has a strictly negative return (`close < open`), it treats
the price move as a price-only proxy for negative EIA inventory news and sends
one market SELL during seconds 0–29 of the 10:31 minute. It freezes a hard stop
at `3.0 × ATR(20, M1)` from the entry price, sets no profit target, and closes
on the first tick at or after 10:35 New York.

The New York date is consumed before any fallible signal, quote, spread, ATR,
risk, or order check, so the EA cannot retry that date. A date change or ten
elapsed minutes repairs a surviving position; malformed, duplicate-magic,
wrong-symbol, non-SELL, or stopless owned exposure is closed immediately.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_release_hhmm_ny` | 1030 | locked | New York label of the completed EIA proxy bar. |
| `strategy_decision_hhmm_ny` | 1031 | locked | New York minute in which the short may be submitted. |
| `strategy_flat_hhmm_ny` | 1035 | locked | New York time at which the drift window ends. |
| `strategy_entry_grace_seconds` | 30 | locked | Permit entry only during seconds 0–29 of 10:31. |
| `strategy_atr_period_m1` | 20 | locked | Completed-M1 ATR lookback used for the frozen stop. |
| `strategy_atr_stop_multiple` | 3.0 | locked | ATR multiple applied to the hard stop. |
| `strategy_max_hold_minutes` | 10 | locked | Survivor-repair hold ceiling, not the planned exit. |
| `strategy_max_spread_points` | 1500 | locked | Reject only genuinely positive spreads above this cap. |

Framework-level risk, news, Friday-close, RNG, and stress inputs are documented
in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` — the approved card binds the EIA WPSR price proxy to governed
  WTI M1 history and registry slot 0.

**Explicitly NOT for:**

- All other `.DWX` symbols — the source event, timestamp, and first-minute
  response are WTI-specific; cross-instrument expansion is not authorized.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_M1)`; the completed 10:30 bar is read once at the 10:31 bar edge |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 22; plausible range 15–30 |
| Typical hold time | about 4 minutes; 10 minutes is repair-only |
| Expected drawdown profile | sparse and event-concentrated; card prior is 30% and Q02 must determine the governed result |
| Regime preference | news-driven negative WTI first-minute response |
| Win rate target (qualitative) | not assumed; positive governed economics and yearly frequency are required |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ARMSTRONG-EIA-WTI-NEGDRIFT-M1-2026`
**Source type:** peer-reviewed paper plus official EIA release schedule
**Pointer:** `strategy-seeds/sources/ARMSTRONG-EIA-WTI-NEGDRIFT-M1-2026/source.md`
**R1–R4 verdict (Q00):** all PASS; lineage is recorded in
`strategy-seeds/cards/approved/QM5_41242_wti-eia-negdrift-m1_card.md`

The source is Armstrong, Cardella, and Sabah (2021), “Information shocks,
disagreement, and drift,” *Journal of Financial Economics* 140(3), 916–940,
DOI `10.1016/j.jfineco.2021.02.002`. The paper classifies inventory news from
surprises rather than bar direction; the negative M1 bar is the approved QM
price-proxy translation and remains a declared falsification risk.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). The only preset produced by this build is the
backtest preset with `RISK_FIXED=1000` and `RISK_PERCENT=0`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-31 | Initial build from approved card | build task `de47b55a-6801-4eb1-be77-f74ddd5fd405` |
