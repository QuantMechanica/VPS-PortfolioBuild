# QM5_13210_mulham-asian-sweep-london — Strategy Spec

**EA ID:** QM5_13210
**Slug:** `mulham-asian-sweep-london`
**Source:** `YT-MULHAM-2026-07`
**Author of this spec:** Codex
**Last revised:** 2026-07-20

---

## 1. Strategy Logic

The EA records exactly 48 contiguous closed M5 bars from 03:00–07:00 broker
time and proceeds only when the Asian net move is no more than half of that
range and the range is at least 0.3 times H1 ATR(14). Any missing or displaced
Asian bar fails the day closed. It re-anchors a one-way extension before 08:30,
then looks from 08:30–10:00 for a wick through one range extreme whose candle
body closes inside. On a strictly subsequent closed bar, a close through the
last opposing two-left/two-right M5 swing plus a three-candle fair-value gap
confirms the reversal; the EA places a limit at the gap midpoint and cancels it
no later than 12:00.

The setup is invalidated if the opposite range side is swept, if the selected
target has already traded, or if a cached limit's stop geometry becomes stale.
The stop is beyond the sweep extreme by 0.1 M5 ATR. The default target is the
opposite Asian body extreme; the declared variant uses a fixed three-times-risk
target. Positions that remain open are closed at 20:00 broker time, and the
framework also enforces Friday close and the central high-impact news blackout.
State advances on every closed bar even during a blackout; only order submission
is gated. A pending limit expires at the first authoritative future blackout
boundary (or 12:00, whichever comes first) and is also removed fail-closed when
a fresh per-tick news check blocks or loses calendar authority.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_asia_start_hour` | 3 | 0–23 | Broker hour when Asian range recording begins. |
| `strategy_asia_start_minute` | 0 | 0–59 | Minute component of Asian range start. |
| `strategy_asia_end_hour` | 7 | 0–23 | Broker hour when the Asian range freezes. |
| `strategy_asia_end_minute` | 0 | 0–59 | Minute component of Asian range end. |
| `strategy_sweep_start_hour` | 8 | 0–23 | Broker hour of the wick-sweep window start. |
| `strategy_sweep_start_minute` | 30 | 0–59 | Minute component of sweep-window start. |
| `strategy_sweep_end_hour` | 10 | 0–23 | Broker hour of the wick-sweep window end. |
| `strategy_sweep_end_minute` | 0 | 0–59 | Minute component of sweep-window end. |
| `strategy_entry_cancel_hour` | 12 | 0–23 | Broker hour when an unfilled limit is cancelled. |
| `strategy_entry_cancel_minute` | 0 | 0–59 | Minute component of entry cancellation. |
| `strategy_flatten_hour` | 20 | 0–23 | Broker hour for the time flatten. |
| `strategy_flatten_minute` | 0 | 0–59 | Minute component of the time flatten. |
| `strategy_atr_period` | 14 | 2–100 | ATR period used by the regime floor and stop buffer. |
| `strategy_asia_trend_max_frac` | 0.50 | 0.1–1.0 | Maximum Asian net move as a fraction of its high-low range. |
| `strategy_asia_range_min_atr` | 0.30 | 0.1–2.0 | Minimum Asian range relative to closed H1 ATR. |
| `strategy_sl_buffer_atr` | 0.10 | 0.01–1.0 | M5 ATR fraction placed beyond the sweep extreme. |
| `strategy_spread_max_atr_frac` | 0.10 | 0.01–0.5 | Entry spread cap as a fraction of M5 ATR; zero modeled spread passes. |
| `strategy_tp_mode` | opposite body | opposite body / fixed R | Selects the card's default or declared target variant. |
| `strategy_fixed_rr` | 3.0 | 1.0–10.0 | Reward multiple used by the fixed-R variant. |

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — primary liquid FX venue used by the source's London-session mechanic.
- `XAUUSD.DWX` — card-mandated liquid metal venue with the same session liquidity cycle.

**Explicitly NOT for:**

- Non-`.DWX` symbols — they are outside the canonical Darwinex test universe.
- Symbols other than the two card targets — no source-backed portability claim was approved.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | Closed `H1` ATR(14) for the Asian-range floor; the card lists M15 but supplies no executable M15 rule. |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)`; state advances once per closed M5 bar before the entry-news gate. |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | About 60; no more than one setup per broker day. |
| Typical hold time | Intraday, from the London window until target/stop or the 20:00 flatten. |
| Expected drawdown profile | Medium risk class; card expectation is approximately 12% drawdown. |
| Regime preference | Mean reversion after a ranging Asian session and a London liquidity sweep. |
| Win rate target (qualitative) | Medium; the card declares an expected PF of 1.15 and Q02 PF floor of 1.20. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `YT-MULHAM-2026-07`
**Source type:** Video extraction approved under the source-agnostic reputation criteria
**Pointer:** `docs/ops/evidence/mulham_channel_mechanization_dossier_2026-07-13.md`
**R1–R4 verdict (Q00):** all PASS; see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_13210_mulham-asian-sweep-london.md`

The source does not define a numeric swing pivot, exact extension test, or FVG
formula. This build uses a two-left/two-right confirmed pivot, treats an
extension-bar close beyond the Asian boundary as the card's "without
reversing" condition, and uses the standard three-candle non-overlap FVG. It
does not add an M15 filter because the approved card contains no mechanical
M15 condition.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

The backtest setfiles bind `RISK_FIXED=1000` and `RISK_PERCENT=0` explicitly.
`QM_FrameworkInit` rejects mutually inconsistent risk inputs, while the pipeline
— not the EA — owns validation of the declared setfile environment.

---

## 8. News API boundary

`QM_NewsNextBlockStart` is the authoritative public API for the first
symbol-affecting blackout boundary through the pending-order deadline. The
approved source also states a narrower day veto for a high-impact **USD** event
in the later New-York window. The public framework API does not expose a
currency-and-session predicate for that rule; the EA therefore does not invent
an internal calendar traversal or broaden it to a different UTC-day rule. That
source-specific veto remains an explicit API blocker; the framework's approved
high-impact blackout and the pending-fill protections above are enforced.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-19 | Initial build from card | Build task `3bba09a5-e8e6-4e56-99c0-dad71c678a4e` |
| v2 | 2026-07-20 | Outcome-blind mechanical repair | News-independent state advancement; 48-bar continuity; subsequent-bar confirmation; target/opposite-sweep invalidation; checked order-state transition; authoritative pending-news deadline/cancellation. No backtest or Q02 outcome inspected. |
