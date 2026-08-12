# QM5_20092_pricebob-refbar-breakout-correlated-metal-xagusd — Strategy Spec

**EA ID:** QM5_20092
**Slug:** pricebob-refbar-breakout-correlated-metal-xagusd
**Source:** 68eff294-e3b2-5010-82d8-e9dd5f4130e6
**Author of this spec:** Codex
**Last revised:** 2026-07-31

---

## 1. Strategy Logic

The EA records the XAGUSD M5 bar that opens at 08:20 Eastern and closes at
08:25 Eastern. After that bar closes, the first later M5 close above its high
opens a long at the next bar open, while the first close below its low opens a
short. The stop is the opposite edge of the reference bar, the target is one
reference-bar range from entry, and any remaining position closes at 21:00
broker time. Only one breakout signal may be consumed per Eastern session.

The reference day is skipped when its M5 range is below 0.30 or above 2.50
times the prior closed D1 ATR(14). New entries are also blocked when the
positive modeled spread exceeds 20% of the reference range or when the central
high-impact-news blackout gate is active.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_reference_hour_et` | 8 | 0–23 | Eastern hour when the reference M5 bar opens. |
| `strategy_reference_minute_et` | 20 | 0–59 | Eastern minute when the reference M5 bar opens. |
| `strategy_session_end_hour_broker` | 21 | 0–23 | Broker hour at which any remaining position is closed. |
| `strategy_daily_atr_period` | 14 | 2–100 | D1 ATR period used to validate the reference-bar range. |
| `strategy_ref_range_min_atr_ratio` | 0.30 | 0.00–2.50 | Minimum reference range as a fraction of D1 ATR. |
| `strategy_ref_range_max_atr_ratio` | 2.50 | > minimum | Maximum reference range as a fraction of D1 ATR. |
| `strategy_max_spread_ref_range_ratio` | 0.20 | 0.00–1.00 | Largest positive spread allowed as a fraction of the reference range. |
| `strategy_target_ref_range_mult` | 1.00 | > 0.00 | Reference-range multiples projected from entry for take-profit. |

Framework-level risk, news, RNG, stress and Friday-close inputs are documented
in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**

- `XAGUSD.DWX` — the approved R3 silver CFD is the card's
  COMEX-metals-analog deployment target.

**Explicitly NOT for:**

- All non-XAG symbols — this card approves a single-symbol silver baseline;
  correlated gold and other assets have separate Strategy Cards.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `D1` ATR(14), shift 1, only when the daily reference bar is captured |
| Bar gating | `QM_IsNewBar()` from the canonical skeleton |

The framework converts broker timestamps to UTC and then Eastern time with the
US DST rule. Under the Darwinex NY-close convention, 08:20 Eastern maps to
15:20 broker time throughout the year.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 110 |
| Expected trade frequency | Approximately 2.1 trades per week on XAGUSD.DWX |
| Typical hold time | Intraday: minutes to at most about 5 hours 35 minutes |
| Expected drawdown profile | Card expectation: approximately 18% |
| Regime preference | Session breakout / volatility expansion |
| Win rate target (qualitative) | Medium; baseline stop/target geometry is approximately 1:1 |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 68eff294-e3b2-5010-82d8-e9dd5f4130e6  
**Source type:** Forex Factory forum thread  
**Pointer:** https://www.forexfactory.com/thread/1331012-the-pricebob-strategy  
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per
`artifacts/cards_approved/QM5_20092_pricebob-refbar-breakout-correlated-metal-xagusd.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-31 | Initial build from card | 6cbee058-5f7b-4c18-9533-7bff4686b6b6 |
