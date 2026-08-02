# QM5_20091_pricebob-extreme-reversal-fade-gdaxi — Strategy Spec

**EA ID:** QM5_20091
**Slug:** `pricebob-extreme-reversal-fade-gdaxi`
**Source:** `68eff294-e3b2-5010-82d8-e9dd5f4130e6`
**Author of this spec:** Codex
**Last revised:** 2026-08-02

---

## 1. Strategy Logic

On each closed M5 bar, the EA tests the latest four bars for a tight range: every true range must be no more than 0.60 times M5 ATR(14), and the combined envelope may expand no more than 0.10 M5 ATR beyond the oldest bar. The box must be at least 0.15 times D1 ATR(14) wide and lie within 15% of the running DAX cash-session range from exactly one session extreme. A box near the session high places a sell-stop at the box low; a box near the session low places a buy-stop at the box high. The stop sits five scale-correct pips beyond the relevant session extreme, the take-profit distance is the smaller of half the session range and twice the box range, and any surviving position or order is closed or removed at session end.

---

## 2. Parameters

| Parameter | Default | Valid range | Meaning |
|---|---:|---:|---|
| `strategy_session_start_hhmm` | 1000 | 0000–2359 | DAX cash-session start in DXZ broker time. |
| `strategy_session_end_hhmm` | 1830 | 0000–2359 | DAX cash-session end and time-stop in DXZ broker time. |
| `strategy_atr_period` | 14 | 2–200 | ATR period used on M5 and D1. |
| `strategy_bar_tr_atr_max` | 0.60 | greater than 0 | Maximum true range of each box bar as a multiple of M5 ATR. |
| `strategy_envelope_atr_buffer` | 0.10 | 0 or greater | Maximum envelope expansion beyond the oldest member as a multiple of M5 ATR. |
| `strategy_extreme_proximity` | 0.15 | greater than 0 and less than 0.50 | Maximum distance from a session extreme as a fraction of session range. |
| `strategy_d1_box_floor_atr` | 0.15 | greater than 0 | Minimum total box range as a multiple of D1 ATR. |
| `strategy_spread_box_max` | 0.25 | greater than 0 | Maximum positive spread as a fraction of box range; zero modeled spread remains valid. |
| `strategy_tp_session_range_mult` | 0.50 | greater than 0 | Session-range retracement multiple used for the target. |
| `strategy_tp_box_range_cap` | 2.00 | greater than 0 | Maximum target distance in box-range multiples. |
| `strategy_extreme_buffer_pips` | 5 | 1 or greater | Scale-correct fixed buffer beyond the invalidating session extreme. |
| `strategy_max_signals_per_session` | 2 | 1 or greater | Maximum fade signals consumed per cash session. |

Framework-level risk, news, Friday-close, seed, and stress inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `GDAXI.DWX` — the card’s sole R3 PASS target; its liquid, session-defined DAX cash market supplies meaningful intraday extremes and M5 consolidation boxes.

**Explicitly NOT for:**

- Other `.DWX` symbols — the approved card’s R3 row names only `GDAXI.DWX`, so no broader basket is registered in this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `D1` ATR(14) for the minimum box-range filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the canonical skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 30 |
| Expected trade frequency | approximately 2.5 trades per month per symbol |
| Typical hold time | intraday, from the stop trigger until SL, TP, or 18:30 broker time |
| Expected drawdown profile | approximately 20% maximum drawdown per the card frontmatter |
| Regime preference | mean reversion after an exhaustion pattern at a DAX session extreme |
| Win rate target (qualitative) | not specified by the approved card |

---

## 6. Source Citation

**Source ID:** `68eff294-e3b2-5010-82d8-e9dd5f4130e6`
**Source type:** Forex Factory forum thread
**Pointer:** `https://www.forexfactory.com/thread/1331012-the-pricebob-strategy`
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_20091_pricebob-extreme-reversal-fade-gdaxi.md`.

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
| v1 | 2026-08-02 | Initial build from card | dc2331dc-d4a6-4ee4-8a85-016a1ff8168b |

